//
//  Copyright © 2021 Yahoo
//

import Foundation

protocol TransientResource {
    func clearTransientValue()
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

public protocol BGResource: AnyObject, BGDemandable {
    var event: BGEvent { get }
    var traceEvent: BGEvent { get }
    var order: BGDemandable { get }
    func justUpdated() -> Bool
    func hasUpdated() -> Bool
}

internal extension BGResource {
    @inline (__always)
    var asInternal: BGResourceInternal { self as! BGResourceInternal }
}

protocol BGResourceInternal: AnyObject, BGResource, CustomDebugStringConvertible {
    var subsequents: Set<BGSubsequentLink> { get set }
    var supplier: BGBehavior? { get set }
    var owner: BGExtent? { get set }
    var _event: BGEvent { get set }
    var _prevEvent: BGEvent { get set }
    var debugName: String? { get set }
}

struct WeakResource: Equatable, Hashable {
    weak var resource: BGResourceInternal?
    let resourcePtr: ObjectIdentifier
    
    init(_ resource: BGResourceInternal) {
        self.resource = resource
        resourcePtr = ObjectIdentifier(resource)
    }
    
    // MARK: Equatable
    
    static func == (lhs: WeakResource, rhs: WeakResource) -> Bool {
        guard let l = lhs.resource, let r = rhs.resource, l === r else {
            return false
        }
        return true
    }
    
    // MARK: Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(resourcePtr)
    }
}

enum BGResourceUpdatable {
    case notUpdatable
    case updateable(graph: BGGraph, currentEvent: BGEvent)
}

extension BGResourceInternal {
    var graph: BGGraph? { owner?.graph }
    public var event: BGEvent {
        verifyDemands()
        return _event
    }
    
    public var traceEvent: BGEvent {
        _event.sequence == graph?.currentEvent?.sequence ? _prevEvent : _event
    }
    
    public var order: BGDemandable {
        BGDemandLink(resource: self, type: .order)
    }
    
    public func justUpdated() -> Bool {
        guard let currentEvent = graph?.currentEvent else {
            return false
        }
        
        return currentEvent.sequence == event.sequence
    }
    
    public func hasUpdated() -> Bool {
        event.sequence > BGEvent.unknownPast.sequence
    }
    
    func verifyDemands() {
        // TODO: compile out checks with build flag
        
        guard BGGraph.checkUndeclaredDemands else {
            return
        }
        
        if let currentBehavior = graph?.currentRunningBehavior, currentBehavior !== supplier {
            assert(currentBehavior.demands.first(where: { $0.resource === self }) != nil,
                   "Accessed a resource in a behavior that was not declared as a demand.")
        }
    }
    
    var updateable: BGResourceUpdatable {
        guard let graph = self.graph else {
            // If graph is nil, then weak extent has been deallocated and resource updates are no-ops.
            return .notUpdatable
        }
        
        guard let currentEvent = graph.currentEvent else {
            assertionFailure("Can only update a resource during an event.")
            return .notUpdatable
        }
        
        guard let owner = owner else {
            assertionFailure("Cannot update a resource that does not belong to an extent.")
            return .notUpdatable
        }
        
        if let behavior = supplier {
            
            guard graph.currentRunningBehavior === behavior else {
                assertionFailure("Can only supplied resource during its supplying behavior's run.")
                return .notUpdatable
            }
        } else {
            if self !== owner._added {
                guard graph.processingAction else {
                    assertionFailure("Can only update unsupplied resource during an action.")
                    return .notUpdatable
                }
            }
        }
        
        guard _event.sequence < currentEvent.sequence else {
            // assert or fail?
            assertionFailure()
            return .notUpdatable
        }
        
        return .updateable(graph: graph, currentEvent: currentEvent)
    }
    
    var weakReference: WeakResource {
        WeakResource(self)
    }
    
    public var debugDescription: String {
        return "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(debugName ?? "Unlabeled"))>"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

public class BGMoment: BGResource, BGResourceInternal {
    var subsequents = Set<BGSubsequentLink>()
    weak var supplier: BGBehavior?
    weak var owner: BGExtent?
    var debugName: String?
    var _event: BGEvent = .unknownPast
    var _prevEvent: BGEvent = .unknownPast
    
    public func update() {
        guard case .updateable(let graph, let currentEvent) = updateable else {
            return
        }
        
        _prevEvent = _event;
        _event = currentEvent
        
        graph.updatedResources.append(self)
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

public class BGTypedMoment<Type>: BGResource, BGResourceInternal, TransientResource {
    var subsequents = Set<BGSubsequentLink>()
    weak var supplier: BGBehavior?
    weak var owner: BGExtent?
    var debugName: String?
    var _event: BGEvent = .unknownPast
    var _prevEvent: BGEvent = .unknownPast
    
    var _value: Type?
    
    public var updatedValue: Type? {
        verifyDemands()
        return _value
    }

    public func update(_ newValue: Type) {
        guard case .updateable(let graph, let event) = updateable else {
            return
        }

        _prevEvent = _event;

        _value = newValue
        _event = event

        graph.updatedResources.append(self)
        graph.updatedTransientResources.append(self)
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

    func clearTransientValue() {
        _value = nil
    }
}

public enum BGStateComparison {
    public enum None { case none }
    public enum Equal { case equal }
    public enum Identical { case identical }
}

public class BGState<Type>: BGResource, BGResourceInternal, TransientResource, ObservableObject {
    var subsequents = Set<BGSubsequentLink>()
    weak var supplier: BGBehavior?
    weak var owner: BGExtent?
    var debugName: String?
    var _event: BGEvent = .unknownPast
    var _prevEvent: BGEvent = .unknownPast
    
    // These properties support combine and swiftui
    public weak var bindingInput: BGState? // could even be ourselves for two way binding
    private var _observableUpdated: BGEvent = .unknownPast
    public var observableValue: Type {
        get {
            if _event.sequence > _observableUpdated.sequence {
                return traceValue
            } else {
                return value
            }
        }
        set {
            bindingInput?.updateWithAction(newValue)
        }
    }
    
    var _value: Type
    var _prevValue: Type?
    private var comparison: ((Type, Type) -> Bool)?
    
    public var value: Type {
        verifyDemands()
        return _value
    }
    
    public var traceValue: Type {
        if let value = _prevValue {
            return value
        } else {
            return _value
        }
    }
    
    init(_ value: Type, comparison: ((Type, Type) -> Bool)?) {
        self.comparison = comparison
        self._value = value
        self._prevValue = value
    }
    
    func valueEquals(_ other: Type) -> Bool {
        if let comparison = comparison {
            return comparison(_value, other)
        } else {
            return false
        }
    }
    
    public func update(_ newValue: Type) {
        guard case .updateable(let graph, let event) = updateable else {
            return
        }
        
        if !valueEquals(newValue) {
            owner?.sideEffect { [weak self] in
                if let self {
                    self.objectWillChange.send()
                    self._observableUpdated = self.event
                }
            }
            _prevValue = _value;
            _prevEvent = _event;
            
            _value = newValue
            _event = event
            
            graph.updatedResources.append(self)
            graph.updatedTransientResources.append(self)
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
        return comparison(_value, to) && comparison(traceValue, from)
    }
    
    func clearTransientValue() {
        _prevValue = nil
    }

}

public protocol BGDemandable {
}

extension BGDemandable {
    @inline (__always)
    var link: BGDemandLink {
        switch self {
        case let link as BGDemandLink:
            return link
        case let resource as BGResourceInternal:
            return BGDemandLink(resource: resource, type: .reactive)
        default:
            preconditionFailure("Unknown `BGDemandable` type.")
        }
    }
}

