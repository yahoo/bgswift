//
//  Copyright © 2021 Yahoo
//

import Foundation

protocol TransientResource {
    func clearValue()
}

public protocol BGOptionalObject {
    associatedtype Wrapped: AnyObject
    var bg_unwrapped: Wrapped? { get }
}

extension Optional: BGOptionalObject where Wrapped: AnyObject {
    public var bg_unwrapped: Wrapped? {
        return self
    }
}

public class BGResource {
    public enum ComparisonNone { case none }
    public enum ComparisonEqual { case equal }
    public enum ComparisonIdentical { case identical }
    
    var subsequents = WeakSet<BGBehavior>()
    weak var supplier: BGBehavior?
    weak var extent: BGExtent?
    var graph: BGGraph? {
        get { extent?.graph }
    }
    
    private var _event = BGEvent.unknownPast
    public internal(set) var event: BGEvent {
        get {
            verifyDemands()
            return _event
        }
        
        set { _event = newValue }
    }
    
    var eventDirectAccess: BGEvent { _event }
    
    var previousEvent = BGEvent.unknownPast
    
    public var traceEvent: BGEvent {
        return _event.sequence == graph?.currentEvent?.sequence ? previousEvent : _event
    }
    
    var propertyName: String?
    
    public func justUpdated() -> Bool {
        guard let currentEvent = graph?.currentEvent else {
            return false
        }
        
        return currentEvent.sequence == event.sequence
    }
    
    init(name: String? = nil) {
        self.propertyName = name;
    }
    
    public func hasUpdated() -> Bool {
        return event.sequence > BGEvent.unknownPast.sequence
    }
    
    var canUpdate: Bool {
        guard let graph = self.graph else {
            // If graph is nil, then weak extent has been deallocated and resource updates are no-ops.
            return false
        }
        
        guard let currentEvent = graph.currentEvent else {
            assertionFailure("Can only update a resource during an event.")
            return false
        }
        
        guard let extent = extent else {
            assertionFailure("Cannot update a resource that does not belong to an extent.")
            return false
        }
        
        if let behavior = supplier {
            
            guard graph.currentRunningBehavior === behavior else {
                assertionFailure("Can only supplied resource during its supplying behavior's run.")
                return false
            }
        } else {
            if self !== extent._added {
                guard graph.processingAction else {
                    assertionFailure("Can only update unsupplied resource during an action.")
                    return false
                }
            }
        }
        
        guard eventDirectAccess.sequence < currentEvent.sequence else {
            // assert or fail?
            assertionFailure()
            return false
        }
        
        return true
    }
    
    static var assertUndeclaredDemands: Bool {
        ProcessInfo.processInfo.arguments.contains("-BGGraphVerifyDemands")
    }
    
    func verifyDemands() {
        // TODO: compile out checks  with build flag
        
        guard BGResource.assertUndeclaredDemands else {
            return
        }
        
        if let currentBehavior = graph?.currentRunningBehavior, currentBehavior !== supplier {
            assert(currentBehavior.demands.contains(self), "Accessed a resource in a behavior that was not declared as a demand.")
        }
    }
}

extension BGResource: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(propertyName ?? "Unlabeled"))>"
    }
}

extension BGResource: Hashable {
    public static func == (lhs: BGResource, rhs: BGResource) -> Bool {
        return lhs === rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

public class BGTypedResource<Type>: BGResource {
    private var _value: Type
    public internal(set) var value: Type {
        get {
            // TODO: compile out this check with build flag
            if BGResource.assertUndeclaredDemands {
                verifyDemands()
            }
            return _value
        }
        
        set { _value = newValue }
    }
    
    var valueDirectAccess: Type { _value }
    
    init(_ value: Type, name: String? = nil) {
        _value = value
        super.init(name: name)
    }
}

public class BGMoment: BGResource {
    
    public func update() {
        guard canUpdate else {
            return
        }
        
        previousEvent = eventDirectAccess;
        event = graph!.currentEvent!
        
        graph!.updatedResources.append(self)
    }
    
    public func updateWithAction(file: String = #fileID, line: Int = #line, function: String = #function, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        graph?.action(file: file, line: line, function: function, syncStrategy: syncStrategy) {
            self.update()
        }
    }
    
    public func updateWithAction(impulse: String, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        graph?.action(impulse: impulse, syncStrategy: syncStrategy) {
            self.update()
        }
    }

}

public class BGTypedMoment<Type>: BGTypedResource<Type?>, TransientResource {
    public typealias ReadableValueType = Type?
    
    init(name: String? = nil) {
        super.init(nil)
    }
    
    public func update(_ newValue: Type, withAction: Bool = false) {
        guard canUpdate else {
            return
        }
        
        previousEvent = eventDirectAccess;
        
        value = newValue
        event = graph!.currentEvent!
        
        graph!.updatedResources.append(self)
        graph!.updatedTransientResources.append(self)
    }
    
    public func updateWithAction(_ newValue: Type, file: String = #fileID, line: Int = #line, function: String = #function, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        graph?.action(file: file, line: line, function: function, syncStrategy: syncStrategy) {
            self.update(newValue)
        }
    }
    
    public func updateWithAction(_ newValue: Type, impulse: String, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        graph?.action(impulse: impulse, syncStrategy: syncStrategy) {
            self.update(newValue)
        }
    }

    func clearValue() {
        value = nil
    }
    
    public var updatedValue: ReadableValueType { value }
}

public class BGState<Type>: BGTypedResource<Type> {
    public typealias ReadableValueType = Type
    
    private var comparison: ((Type, Type) -> Bool)?
    private var previousValue: Type
    
    public var traceValue: Type {
        get { eventDirectAccess.sequence == graph?.currentEvent?.sequence ? previousValue : valueDirectAccess }
    }
    
    init(_ value: Type, name: String? = nil, comparison: ((Type, Type) -> Bool)?) {
        self.comparison = comparison
        self.previousValue = value
        super.init(value, name: name)
    }
}

extension BGState {
    func commitUpdate(_ newValue: Type) {
        guard let graph = self.graph, let currentEvent = graph.currentEvent else {
            return
        }
        
        previousValue = valueDirectAccess;
        previousEvent = eventDirectAccess;
        
        value = newValue
        event = currentEvent
        
        graph.updatedResources.append(self)
    }
    
    func valueEquals(_ other: Type) -> Bool {
        if let comparison = comparison {
            return comparison(valueDirectAccess, other)
        } else {
            return false
        }
    }
    
    public func update(_ newValue: Type) {
        guard canUpdate else { return }
        
        if !valueEquals(newValue) {
            commitUpdate(newValue)
        }
    }
    
    public func updateWithAction(_ newValue: Type, file: String = #fileID, line: Int = #line, function: String = #function, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        graph?.action(file: file, line: line, function: function, syncStrategy: syncStrategy) {
            self.update(newValue)
        }
    }
    
    public func updateWithAction(_ newValue: Type, impulse: String, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        graph?.action(impulse: impulse, syncStrategy: syncStrategy) {
            self.update(newValue)
        }
    }
    
    public func justUpdated(to: Type) -> Bool {
        return justUpdated() && valueEquals(to)
    }
    
    public func justUpdated(from: Type) -> Bool {
        guard justUpdated(), let comparison = comparison else {
            return false
        }
        return comparison(traceValue, from)
    }
    
    public func justUpdated(to: Type, from: Type) -> Bool {
        guard justUpdated(), let comparison = comparison else {
            return false
        }
        return comparison(valueDirectAccess, to) && comparison(traceValue, from)
    }
}
