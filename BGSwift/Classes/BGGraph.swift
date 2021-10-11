//
//  Copyright © 2021 Yahoo
//

import Foundation

public class BGGraph {
    public enum SynchronizationStrategy {
        case sync
        case async(queue: DispatchQueue? = nil)
    }
    
    private let currentDate: () -> Date
    private let behaviorQueue = PriorityQueue()
    private var actionQueue = [BGAction]()
    private var eventLoopState: EventLoopState?
    private var sequence: UInt = 0
    private var deferredRelease = [Any]()
    private var sideEffectQueue = [BGSideEffect]()
    var updatedTransientResources = [TransientResource]()
    
    private let mutex = Mutex(recursive: true)
    
    private let defaultQueue: DispatchQueue
    
    var behaviorsWithModifiedSupplies = [BGBehavior]()
    var behaviorsWithModifiedDemands = [BGBehavior]()
    var updatedResources = [BGResource]()
    private var untrackedBehaviors = [BGBehavior]()
    private var needsOrdering = [BGBehavior]()
    
    var currentRunningBehavior: BGBehavior?
    
    public var currentEvent: BGEvent? {
        get { eventLoopState?.event }
    }
    
    var processingChanges: Bool {
        eventLoopState?.processingChanges ?? false
    }
    
    var processingAction: Bool {
        eventLoopState?.processingAction ?? false
    }
    
    private var _lastEvent: BGEvent
    public var lastEvent: BGEvent { _lastEvent }
    
    public init(dateProvider: @escaping () -> Date = { Date() }) {
        self._lastEvent = BGEvent.unknownPast
        
        defaultQueue = DispatchQueue(label: "BGGraph.default", qos: .userInteractive)
        
        self.currentDate = dateProvider
    }
    
    public func action(file: String = #fileID, line: Int = #line, function: String = #function, syncStrategy: SynchronizationStrategy? = nil, body: @escaping (() -> Void)) {
        let impulse = BGGraph.impulseString(file: file, line: line, function: function)
        action(impulse: impulse, syncStrategy: syncStrategy, body: body)
    }
    
    public func action(impulse: String?, syncStrategy: SynchronizationStrategy? = nil, body: @escaping (() -> Void)) {
        switch syncStrategy {
        case .sync:
            mutex.balancedUnlock {
                guard !processingAction else {
                    assertionFailure("Nested actions cannot be executed synchronously.")
                    return
                }
                guard !processingChanges else {
                    assertionFailure("Actions originating from behavior closures cannot be executed synchronously.")
                    return
                }
                
                actionQueue.append(BGAction(impulse: impulse, action: body))
                eventLoop()
            }
        case .async(let queue):
            (queue ?? defaultQueue).async {
                self.action(impulse: impulse, syncStrategy: .sync, body: body)
            }
        case .none:
            if mutex.tryLock() {
                let action = BGAction(impulse: impulse, action: body)
                actionQueue.append(action)
                
                // Run sync when the graph is idle or when called from a side-effect.
                if !processingChanges {
                    eventLoop()
                }
                
                mutex.unlock()
            } else {
                // Cannot acquire the lock, so dispatch async
                action(impulse: impulse, syncStrategy: .async(queue: nil), body: body)
            }
        }
    }
    
    public func sideEffect(_ label: String? = nil, body: @escaping () -> Void) {
        guard let event = currentEvent else {
            assertionFailure("Side effects must be created inside actions or behaviors.")
            return
        }
        
        let sideEffect = BGSideEffect(label: label, event: event, run: body)
        self.sideEffectQueue.append(sideEffect)
    }
    
    private func eventLoop() {
        var finished = false
        while !finished {
            autoreleasepool {
                if let eventLoopState = self.eventLoopState {
                
                    if eventLoopState.processingChanges {
                        
                        if !untrackedBehaviors.isEmpty {
                            commitUntrackedBehaviors()
                            return
                        }
                        
                        if !behaviorsWithModifiedSupplies.isEmpty {
                            commitModifiedSupplies()
                        }
                        
                        if !behaviorsWithModifiedDemands.isEmpty {
                            commitModifiedDemands()
                        }
                        
                        if !needsOrdering.isEmpty {
                            orderBehaviors()
                        }
                        
                        if !updatedResources.isEmpty {
                            updatedResources.forEach {
                                for subsequent in $0.subsequents {
                                    submitToQueue(subsequent)
                                }
                            }
                            updatedResources.removeAll()
                        }
                        
                        if !behaviorQueue.isEmpty {
                            
                            let behavior = behaviorQueue.pop()
                            
                            let currentSequence = eventLoopState.event.sequence
                            if behavior.removedSequence != currentSequence {
                                behavior.lastUpdateSequence = currentSequence
                                
                                if let extent = behavior.extent {
                                    currentRunningBehavior = behavior
                                    behavior.runBlock(extent)
                                    currentRunningBehavior = nil
                                }
                            }
                            return
                        }
                    }
                    
                    eventLoopState.processingChanges = false
                    
                    if !sideEffectQueue.isEmpty {
                        executeSideEffect {
                            while !sideEffectQueue.isEmpty {
                                let sideEffect = sideEffectQueue.removeFirst()
                                sideEffect.run()
                            }
                        }
                        return
                    }
                    
                    if !updatedTransientResources.isEmpty {
                        while !updatedTransientResources.isEmpty {
                            updatedTransientResources.removeFirst().clearValue()
                        }
                        return
                    }
                    
                    if !deferredRelease.isEmpty {
                        deferredRelease.removeAll()
                        return
                    }
                    
                    self._lastEvent = eventLoopState.event
                    
                    self.eventLoopState = nil
                }
                
                if let action = actionQueue.first {
                    actionQueue.removeFirst()
                    
                    let currentDate = self.currentDate()
                    sequence += 1
                    let event = BGEvent(sequence: sequence, timestamp: currentDate, impulse: action.impulse)
                    
                    let eventLoopState = EventLoopState(event: event)
                    self.eventLoopState = eventLoopState
                    
                    action.action()
                    eventLoopState.processingAction = false
                    
                    // NOTE: We keep the action block around because it may capture capture and retain some external objects
                    // If it were to go away right after running then that might cause a dealloc to be called as it goes out of scope internal
                    // to the event loop and thus create a side effect during the update phase.
                    // So we keep it around until after all updates are processed.
                    deferredRelease.append(action)
                    
                    return
                }
                
                finished = true
            }
        }
    }
    
    private func commitUntrackedBehaviors() {
        for behavior in untrackedBehaviors {
            if behavior.modifiedSupplies != nil {
                behaviorsWithModifiedSupplies.append(behavior)
            }
            
            if behavior.modifiedDemands != nil {
                behaviorsWithModifiedDemands.append(behavior)
            }
        }
        untrackedBehaviors.removeAll()
    }
    
    private func commitModifiedSupplies() {
        for behavior in behaviorsWithModifiedSupplies {
            if let modifiedSupplies = behavior.modifiedSupplies {
                let removedSupplies = behavior.supplies.filter {
                    return !modifiedSupplies.contains($0)
                }
                let addedSupplies = modifiedSupplies.filter {
                    guard $0.supplier === behavior || $0.supplier == nil else {
                        assertionFailure("Resource is already supplied by a different behavior.")
                        return false
                    }
                    return !behavior.supplies.contains($0)
                }
                
                for supply in removedSupplies {
                    supply.supplier = nil
                    behavior.supplies.remove(supply)
                }
                
                if !addedSupplies.isEmpty {
                    for supply in addedSupplies {
                        supply.supplier = behavior
                        behavior.supplies.add(supply)
                        
                        for subsequent in supply.subsequents {
                            if subsequent.order <= behavior.order {
                                needsOrdering.append(subsequent)
                            }
                        }
                    }
                }
                
                behavior.modifiedSupplies = nil
            }
        }
        behaviorsWithModifiedSupplies.removeAll()
    }
    
    private func commitModifiedDemands() {
        for behavior in behaviorsWithModifiedDemands {
            if let modifiedDemands = behavior.modifiedDemands {
                let removedDemands = behavior.demands.filter {
                    return !modifiedDemands.contains($0)
                }
                let addedDemands = modifiedDemands.filter {
                    assert($0.extent?.graph === self, "Demanded resource has not been added to the graph: \($0.debugDescription)")
                    return !behavior.demands.contains($0)
                }
                
                for demand in removedDemands {
                    demand.subsequents.remove(behavior)
                    behavior.demands.remove(demand)
                }
                
                if !addedDemands.isEmpty {
                    var needsOrdering: Bool = false
                    var needsRunning: Bool = false
                    for demand in addedDemands {
                        demand.subsequents.add(behavior)
                        behavior.demands.add(demand)
                        
                        if demand.justUpdated() {
                            needsRunning = true
                        }
                        
                        if !needsOrdering,
                           let prior = demand.supplier,
                           prior.order >= behavior.order {
                            needsOrdering = true
                        }
                    }
                    
                    if needsOrdering {
                        self.needsOrdering.append(behavior)
                    }
                    if needsRunning {
                        self.submitToQueue(behavior)
                    }
                }
                
                behavior.modifiedDemands = nil
            }
        }
        behaviorsWithModifiedDemands.removeAll()
    }
    
    private func orderBehaviors() {
        var traversalQueue = needsOrdering
        needsOrdering.removeAll()
        
        var needsOrdering = [BGBehavior]()
        while !traversalQueue.isEmpty {
            let behavior = traversalQueue.removeFirst()
            if behavior.orderingState != .unordered {
                behavior.orderingState = .unordered
                needsOrdering.append(behavior)
                
                for supply in behavior.supplies {
                    traversalQueue.append(contentsOf: supply.subsequents)
                }
            }
        }
        
        var needsReheap = false
        needsOrdering.forEach {
            sortDFS(behavior: $0, needsReheap: &needsReheap)
        }
        
        if needsReheap {
            behaviorQueue.setNeedsReheap()
        }
    }
    
    private func sortDFS(behavior: BGBehavior, needsReheap: inout Bool) {
        guard behavior.orderingState != .ordering else {
            // assert or fail?
            assert(behavior.orderingState != .ordering, "Dependency cycle detected")
            return
        }
        
        if behavior.orderingState == .unordered {
            behavior.orderingState = .ordering
            
            var order = UInt(1)
            for demand in behavior.demands {
                if let prior = demand.supplier {
                    if prior.orderingState != .ordered {
                        sortDFS(behavior: prior, needsReheap: &needsReheap)
                    }
                    order = max(order, prior.order + 1)
                }
            }
            
            behavior.orderingState = .ordered
            if order != behavior.order {
                behavior.order = order
                needsReheap = true
            }
        }
    }
    
    func submitToQueue(_ behavior: BGBehavior) {
        // @SAL 8/26/2019-- I'm not sure how either of these would trigger, it seems they are both a result of a broken
        // algorithm, not a misconfigured graph
        // jlou 2/5/19 - These asserts are checking for graph implementation bugs, not for user error.
        assert(eventLoopState?.processingChanges ?? false, "Should not be activating behaviors in current phase.")
        assert(behavior.lastUpdateSequence != sequence, "Behavior already ran.")
        
        if behavior.enqueuedSequence < sequence {
            behavior.enqueuedSequence = sequence
            
            behaviorQueue.push(behavior)
        }
    }
    
    func addExtent(_ extent: BGExtent) {
        guard let eventLoopState = self.eventLoopState, eventLoopState.processingChanges else {
            assertionFailure("Extents must be added during an event.")
            return
        }
        guard extent._added.eventDirectAccess == BGEvent.unknownPast else {
            assertionFailure("Extent can only be added once.")
            return
        }
        
        extent._added.update()
        untrackedBehaviors.append(contentsOf: extent.behaviors)
    }
    
    func updateDemands(behavior: BGBehavior) {
        guard let eventLoopState = self.eventLoopState, eventLoopState.processingChanges else {
            assertionFailure("Can only update demands during an event.")
            return
        }
        behaviorsWithModifiedDemands.append(behavior)
    }
    
    func updateSupplies(behavior: BGBehavior) {
        guard let eventLoopState = self.eventLoopState, eventLoopState.processingChanges else {
            assertionFailure("Can only update supplies during an event.")
            return
        }
        behaviorsWithModifiedSupplies.append(behavior)
    }
    
    func removeBehavior(_ behavior: BGBehavior) {
        guard let eventLoopState = eventLoopState, eventLoopState.processingChanges else {
            assertionFailure("Can only remove behaviors during an event.")
            return
        }
        
        for supply in behavior.supplies {
            supply.supplier = nil
        }
        
        for demand in behavior.demands {
            demand.subsequents.remove(behavior)
        }
        behavior.demands.removeAll()
        
        behavior.removedSequence = eventLoopState.event.sequence
    }
    
    func executeSideEffect(_ work: () -> Void) {
        if Thread.current.isMainThread {
            work()
        } else {
            mutex.unlock()
            DispatchQueue.main.sync {
                mutex.lock()
                work()
                mutex.unlock()
            }
            mutex.lock()
        }
    }
    
    static func impulseString(file: String, line: Int, function: String) -> String {
        "\(function)@\(file):\(line)"
    }
}

fileprivate class EventLoopState {
    let event: BGEvent
    var processingAction: Bool = true
    var processingChanges: Bool = true
    init(event: BGEvent) {
        self.event = event
    }
}

#if DEBUG
var assertionFailureImpl: ((@autoclosure () -> String, StaticString, UInt) -> Void)? = nil

func assert(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        (assertionFailureImpl ?? Swift.assertionFailure)(message(), file, line)
    }
}

func assertionFailure(_ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) {
    (assertionFailureImpl ?? Swift.assertionFailure)(message(), file, line)
}
#endif
