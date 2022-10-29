//
//  Copyright © 2021 Yahoo
//    

import XCTest
import BGSwift

class EventTests: XCTestCase {

    var g: BGGraph!
    var b: BGExtentBuilder<BGExtent>!
    var e: BGExtent!
    var rA: BGState<Int>!
    var rB: BGState<Int>!
    var rC: BGState<Int>!

    override func setUpWithError() throws {
        g = BGGraph()
        b = BGExtentBuilder(graph: g)
        rA = b.state(0)
        rB = b.state(0)
        rC = b.state(0)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSideEffectsHappenAfterAllBehaviors() {
        // |> Given a behavior in the graph
        var counter = 0;
        var sideEffectCount: Int? = nil;
        b.behavior().demands([rA]).runs { extent in
            counter = counter + 1
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When a sideEffect is created
        g.action {
            self.rA.update(1)
            self.g.sideEffect {
                sideEffectCount = counter
            }
        }
        
        // |> Then it will be run after all behaviors
        XCTAssertEqual(sideEffectCount, 1)
    }

    func testSideEffectsHappenInOrderTheyAreCreated() {
        // |> Given behaviors with side effects
        var runs: [Int] = []
        b.behavior().supplies([rB]).demands([rA]).runs { extent in
            self.rB.update(1)
            extent.sideEffect {
                runs.append(2)
            }
        }
        b.behavior().demands([rB]).runs { extent in
            extent.sideEffect {
                runs.append(1)
            }
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When those behaviors are run
        rA.updateWithAction(1)
        
        // |> Then the sideEffects are run in the order they are created
        XCTAssertEqual(runs[0], 2)
        XCTAssertEqual(runs[1], 1)
    }
    
    func testTransientValuesAreAvailableDuringEffects() {
        // |> Given a behavior with side effects and a transient resource
        var valueAvailable = false
        var updatedAvailable = false
        let rX: BGTypedMoment<Int> = b.typedMoment()
        b.behavior().supplies([rX]).demands([rA]).runs { extent in
            rX.update(2)
            extent.sideEffect {
                valueAvailable = rX.updatedValue == 2
                updatedAvailable = rX.justUpdated()
            }
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When that side effect is run
        g.action {
            self.rA.update(1)
        }
        
        // |> Then the value and updated state of that transient resource will be available
        XCTAssertTrue(valueAvailable)
        XCTAssertTrue(updatedAvailable)
        // and the value/updated state will not be available outside that event
        XCTAssertNil(rX.updatedValue)
        XCTAssertFalse(rX.justUpdated())
    }
    
    func testNestedActionsRunAfterSideEffects() {
        // |> Given a behavior with a side effect that creates a new event
        var counter = 0
        var effectCount: Int?
        var actionCount: Int?
        b.behavior().demands([rA]).runs { extent in
            self.e.sideEffect {
                self.g.action {
                    actionCount = counter
                    counter = counter + 1
                }
            }
            self.e.sideEffect {
                effectCount = counter
                counter = counter + 1
            }
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When a nested chain of sideEffects is started
        rA.updateWithAction(1)
        
        // |> Then side effects are still run in order they were created
        XCTAssertEqual(effectCount, 0)
        XCTAssertEqual(actionCount, 1)
    }
    
    func testActionsAreSynchronousByDefault() {
        // |> Given a graph
        var counter = 0
        
        // |> When an action runs by default
        g.action {
            counter = counter + 1
        }
        
        // |> It will be run synchronously
        XCTAssertEqual(counter, 1)
    }

    func testSideEffectsMustBeCreatedInsideEvent() {
        // |> When a side effect is created outside of an event
        // |> Then an error will be raised
        TestAssertionHit {
            self.g.sideEffect {
                // nothing
            }
        }
    }
    
    func testDateProviderGivesAlternateTime() {
        let g2 = BGGraph {
            return Date(timeIntervalSinceReferenceDate: 0)
        }
        g2.action {
            XCTAssertEqual(g2.currentEvent?.timestamp, Date(timeIntervalSinceReferenceDate: 0))
        }
    }
}

