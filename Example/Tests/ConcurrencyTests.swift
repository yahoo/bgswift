//
//  Copyright © 2021 Yahoo
//    

import XCTest
@testable import BGSwift

class ConcurrencyTests: XCTestCase {
    
    let SYNC_EXPECTATION_TIMEOUT = TimeInterval(0)
    let ASYNC_EXPECTATION_TIMEOUT = TimeInterval(0.1)

    func runSyncOnMain(_ code: () throws -> Void) rethrows {
        if Thread.isMainThread {
            try code()
        } else {
            try DispatchQueue.main.sync(execute: code)
        }
    }
    
    func testSyncActionRunInSideEffectRunsSynchronously() {
        let exp = XCTestExpectation()
        
        let g = BGGraph()
        
        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            
            g.action(syncStrategy: .sync) {
                g.sideEffect {
                    var actionRan = false
                    g.action(syncStrategy: .sync) {
                        actionRan = true
                    }
                    if actionRan {
                        exp.fulfill()
                    }
                }
            }
        }
        
        wait(for: [exp], timeout: ASYNC_EXPECTATION_TIMEOUT)
    }
    
    func testSyncStrategyUnspecifiedActionRunInSideEffectRunsSynchronously() {
        let exp = XCTestExpectation()
        
        let g = BGGraph()
        
        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            
            g.action(syncStrategy: .sync) {
                g.sideEffect {
                    var actionRan = false
                    g.action(syncStrategy: nil) {
                        actionRan = true
                    }
                    if actionRan {
                        exp.fulfill()
                    }
                }
            }
        }
        
        wait(for: [exp], timeout: ASYNC_EXPECTATION_TIMEOUT)
    }
    
    func testSyncActionRunWhenOtherActionInProgressWaitsAndRunsSynchronously() {
        //@SAL 9/6/2023 -- I'm having a hard time figuring out what scenario this test is trying to cover
        let innerActionRan = XCTestExpectation()
        
        let g = BGGraph()
        
        let sleepInterval = TimeInterval(0.1)
        
        var waitedForInnerAction: Bool? = nil
        
        // Begin execution onto a background thread so that both actions' threads are equal priortity
        DispatchQueue.global().async {
            g.action(syncStrategy: .sync) {
                // Begin second action on another thread
                DispatchQueue.global().async {
                    var actionRan = false
                    
                    // Note that it is possible that the outer action completes before the inner
                    // action attempts to run. In that case, the test will succeed even
                    // if there was never any contention for the graph's mutex. Hopefully this
                    // won't be the case if we choose a sufficient sleep interval.
                    g.action(syncStrategy: .sync) {
                        actionRan = true
                    }
                    waitedForInnerAction = actionRan
                    // @SAL 9/6/2023 -- Moved this here because the action was running syncrhronously(as expected)
                    // but as soon as innerActionRan was fulfilled, the test would end and the assertion
                    // this may be because there are now always side effects (because deferred release clearing is a side effect)
                    // So it now always synchronizes onto the main thread which gives it a chance for the wait below to be satisfied
                    innerActionRan.fulfill()
                }
            }
        }
        
        wait(for: [innerActionRan], timeout: ASYNC_EXPECTATION_TIMEOUT + sleepInterval)
        XCTAssertEqual(waitedForInnerAction, true)
    }
    
    func testSyncStrategyUnspecifiedActionRunWhenOtherActionInProgressReturnsSynchronouslyAndSchedulesAsyncAction() {
        let innerActionRan = XCTestExpectation()
        
        let g = BGGraph()
        
        var waitedForInnerAction: Bool? = nil
        
        // Begin execution onto a background thread so that both actions' threads are equal priortity
        DispatchQueue.global().async {
            g.action(syncStrategy: .sync) {
                let semaphore = DispatchSemaphore(value: 0)
                
                // Begin second action on another thread
                DispatchQueue.global().async {
                    var actionRan = false
                    g.action(syncStrategy: nil) {
                        actionRan = true
                        innerActionRan.fulfill()
                    }
                    waitedForInnerAction = actionRan
                    
                    semaphore.signal()
                }
                
                // Wait until other action is scheduled
                semaphore.wait()
            }
        }
        
        wait(for: [innerActionRan], timeout: ASYNC_EXPECTATION_TIMEOUT)
        XCTAssertEqual(waitedForInnerAction, false)
    }
    
    func testSyncStrategyUnspecifiedActionCalledInAnotherActionIsRunAsyncOnSameDispatchQueueLoop() {
        let g = BGGraph()
        
        var actionOrder = [String]()
        g.action(impulse: "outer", syncStrategy: .sync) {
            g.action(impulse: "inner", syncStrategy: nil) {
                actionOrder.append(g.currentEvent!.impulse!)
            }
            actionOrder.append(g.currentEvent!.impulse!)
        }
        XCTAssertEqual(actionOrder, ["outer", "inner"])
    }
    
    func testSyncStrategyUnspecifiedActionCalledInBehaviorIsRunAsyncOnSameDispatchQueueLoop() {
        let g = BGGraph()
        
        var execOrder = [String]()
        
        let b = BGExtentBuilder(graph: g)
        b.behavior().demands([b.added]).runs { extent in
            g.action(impulse: "inner") {
                execOrder.append(g.currentEvent!.impulse!)
            }
            execOrder.append(g.currentEvent!.impulse!)
        }
        
        let e = BGExtent(builder: b)
        g.action(impulse: "outer") {
            e.addToGraph()
        }
        XCTAssertEqual(execOrder, ["outer", "inner"])
    }
    
    func testUpdatingResourceOfDeallocedExtentIsANoOp() {
        let g = BGGraph()
        
        let asyncActionFinished = XCTestExpectation()
        
        autoreleasepool {
            let b = BGExtentBuilder(graph: g)
            let r = b.state(false)
            let e = BGExtent(builder: b)
            
            g.action {
                e.addToGraph()
            }
            
            g.action(syncStrategy: .async(queue: DispatchQueue.global(qos: .background))) { [weak e] in
                r.update(true)
                
                XCTAssertNil(e)
                XCTAssertFalse(r.value)
                asyncActionFinished.fulfill()
            }
            
            // e deallocs before the async action is executed
        }
        
        wait(for: [asyncActionFinished], timeout: ASYNC_EXPECTATION_TIMEOUT)
    }
    
    func testSyncActionOnMainThreadWhileBackgroundActionWithSideEffectIsRunningCompletesSynchronously() {
        let g = BGGraph()
        
        var execOrder = [String]()
        
        let mutex = Mutex(recursive: false)
        func appendExecOrder(_ str: String) {
            mutex.balancedUnlock {
                execOrder.append(str)
            }
        }
        
        let workTime: TimeInterval = 1
        
        let backgroundActionRunning = XCTestExpectation()
        let backgroundActionCompleted = XCTestExpectation()
        
        g.action(syncStrategy: .async(queue: DispatchQueue.global(qos: .background))) {
            appendExecOrder("background-action-start")
            backgroundActionRunning.fulfill()
            
            // do work
            Thread.sleep(forTimeInterval: workTime)
            appendExecOrder("background-work-complete")
            
            g.sideEffect {
                appendExecOrder("se-background")
            }
            
            backgroundActionCompleted.fulfill()
        }
        
        wait(for: [backgroundActionRunning], timeout: ASYNC_EXPECTATION_TIMEOUT)
        appendExecOrder("creating-main-action")
        g.action(syncStrategy: .sync) {
            appendExecOrder("main-action-start")
            g.sideEffect {
                appendExecOrder("se-main")
            }
        }
        XCTAssertEqual(execOrder, ["background-action-start", "creating-main-action", "background-work-complete", "se-background", "main-action-start", "se-main"])
    }
    
    func testSyncNestedActionsDisallowed() {
        let g = BGGraph()
        TestAssertionHit {
            g.action {
                g.action(syncStrategy:.sync) {
                }
            }
        }
    }
    
    func testSyncActionsInBehaviorsDisallowed() {
        // NOTE: an action inside a behavior can essentially be considered a side effect by default
        // as long as we can delay that action until after the current event which is impossible
        // with a sync actions
        
        // |> Given a behavior in the graph that creates an action outside of a side effect
        let g = BGGraph()
        let b = BGExtentBuilder(graph: g)
        let r1 = b.moment()
        b.behavior().demands([r1]).runs { extent in
            g.action(syncStrategy:.sync) {
                // do something
            }
            // cant run because I may have code here that expected it to run
        }
        let e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When that behavior runs
        // |> Then it should throw an error
        TestAssertionHit {
            r1.updateWithAction()
        }
    }

    func testSyncActionsInSideEffectsAreAllowed() {
        // NOTE: This is currently allowed because its where one would expect actions to be created
        // however, technically the synchronous action could cut ahead of some pending side effects from
        // the existing event. So maybe that could be disallowed and forced into optional asynchrony or fixed?
        
        // |> Given a behavior in the graph that creates an action outside of a side effect
        let g = BGGraph()
        let b = BGExtentBuilder(graph: g)
        let r1 = b.moment()
        b.behavior().demands([r1]).runs { extent in
            extent.sideEffect {
                g.action(syncStrategy:.sync) {
                    // do something
                }
                // cant run because I may have code here that expected it to run
            }
            extent.sideEffect {
                // run something else
                // technicallthe the action above is cutting ahead in line and changing state on us
            }
        }
        let e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When that behavior runs
        // |> Then is should be allowed?
        let failed = CheckAssertionHit {
            r1.updateWithAction()
        }
        XCTAssertFalse(failed)
    }
      
    func testBehaviorsRunOnMainThreadWhenConfigured() {
        let g = BGGraph()
        let b = BGExtentBuilder(graph: g)
        let r1 = b.moment()
        
        let backgroundWorkRan = XCTestExpectation()
        
        var behavior1RanOnMain: Bool?
        var behavior2RanOnMain: Bool?
        
        b.behavior()
            .demands(r1)
            .requiresMainThread()
            .runs { extent in
                behavior1RanOnMain = Thread.isMainThread
            }
        
        b.behavior()
            .demands(r1)
            .runs { extent in
                behavior2RanOnMain = Thread.isMainThread
            }
        
        let e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        DispatchQueue.global(qos: .default).async {
            g.action(syncStrategy: .sync) {
                r1.update()
            }
            backgroundWorkRan.fulfill()
        }
        
        wait(for: [backgroundWorkRan], timeout: ASYNC_EXPECTATION_TIMEOUT)
        XCTAssertEqual(behavior1RanOnMain, true)
        XCTAssertEqual(behavior2RanOnMain, false)
    }
}
