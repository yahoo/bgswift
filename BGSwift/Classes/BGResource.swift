//
//  Copyright © 2021 Yahoo
//

import Foundation

public protocol BGOptionalObject {
    associatedtype Wrapped: AnyObject
    var bg_unwrapped: Wrapped? { get }
}

extension Optional: BGOptionalObject where Wrapped: AnyObject {
    public var bg_unwrapped: Wrapped? {
        return self
    }
}

public protocol BGResource: AnyObject, BGDemandable, CustomDebugStringConvertible {
    var _event: BGEvent { get }
    var debugName: String? { get set }
}

protocol BGResourceInternal: AnyObject, BGResource {
    associatedtype ValueType
    
    var subsequents: Set<BGSubsequentLink> { get set }
    var supplier: BGBehavior? { get set }
    var owner: BGExtent? { get set }
    var _prevEvent: BGEvent { get set }
    var _order: BGDemandable? { get set }
    var _event: BGEvent { get set }
    
    var _value: ValueType { get set }
    func shouldSkipUpdate(_ other: ValueType) -> Bool
    
    var deferClearingTransientValue: Bool { get }
    func clearTransientValue()
}

public extension BGResource {
    var event: BGEvent {
        asInternal.verifyDemands()
        return _event
    }
    
    var traceEvent: BGEvent {
        let asInternal = asInternal
        return _event.sequence == asInternal.graph?.currentEvent?.sequence ? asInternal._prevEvent : _event
    }
    
    var order: BGDemandable {
        let asInternal = asInternal
        if let order = asInternal._order {
            return order
        } else {
            let order = BGDemandLink(resource: asInternal, type: .order)
            asInternal._order = order
            return order
        }
    }
    
    func justUpdated() -> Bool {
        guard let currentEvent = asInternal.graph?.currentEvent else {
            return false
        }
        
        return currentEvent.sequence == event.sequence
    }
    
    func hasUpdated() -> Bool {
        event.sequence > BGEvent.unknownPast.sequence
    }
    
    func hasUpdatedSince(_ resource: BGResource?) -> Bool {
        event.happenedSince(sequence: resource?.event.sequence ?? 0)
    }
    
    func happenedSince(sequence: UInt) -> Bool {
        event.happenedSince(sequence: sequence)
    }
    
    var subsequentBehaviors: [BGBehavior] {
        asInternal.subsequents.compactMap { $0.behavior }
    }
}

internal extension BGResource {
    var asInternal: any BGResourceInternal { self as! (any BGResourceInternal) }
}

extension BGResourceInternal {
    var graph: BGGraph? { owner?.graph }
    
    func verifyDemands() {
        // TODO: compile out checks with build flag
        guard let graph = graph, graph.checkUndeclaredDemands, graph.currentThread == Thread.current else {
            return
        }
        
        if let currentBehavior = graph.currentRunningBehavior, currentBehavior !== supplier {
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
                assertionFailure("Cannot update a resource with a supplying behavior during an action.")
                return .notUpdatable
            }
        } else {
            if self !== owner._added {
                guard graph.processingAction else {
                    assertionFailure("Cannot update a resource with no supplying behaviour outside an action.")
                    return .notUpdatable
                }
            }
        }
        
        guard _event.sequence < currentEvent.sequence else {
            // assert or fail?
            assertionFailure("Can only update a resource once per event.")
            return .notUpdatable
        }
        
        return .updateable(graph: graph, currentEvent: currentEvent)
    }
    
    func _update(_ newValue: ValueType) {
        guard case .updateable(let graph, let event) = updateable else {
            return
        }
        
        if shouldSkipUpdate(newValue) {
            return
        }

        _prevEvent = _event;

        _value = newValue
        _event = event

        graph.updatedResources.append(self)
        
        if deferClearingTransientValue {
            graph.updatedTransientResources.append(self)
        } else {
            clearTransientValue()
        }
    }
    
    func _updateWithAction(_ newValue: ValueType, file: String, line: Int, function: String, syncStrategy: BGGraph.SynchronizationStrategy?) {
        graph?.action(file: file, line: line, function: function, syncStrategy: syncStrategy) {
            self._update(newValue)
        }
    }
    
    func _updateWithAction(_ newValue: ValueType, impulse: String, syncStrategy: BGGraph.SynchronizationStrategy?) {
        graph?.action(impulse: impulse, syncStrategy: syncStrategy) {
            self._update(newValue)
        }
    }
    
    var weakReference: WeakResource {
        WeakResource(self)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct WeakResource: Equatable, Hashable {
    weak var resource: (any BGResourceInternal)?
    let resourcePtr: ObjectIdentifier
    
    init(_ resource: any BGResourceInternal) {
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

public class BGMoment: BGResource, BGResourceInternal {
    typealias ValueType = Void
    var _value: ValueType = Void()
    
    public func update() {
        _update(Void())
    }
    
    public func updateWithAction(file: String = #fileID, line: Int = #line, function: String = #function, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        _updateWithAction(Void(), file: file, line: line, function: function, syncStrategy: syncStrategy)
    }
    
    public func updateWithAction(impulse: String, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        _updateWithAction(Void(), impulse: impulse, syncStrategy: syncStrategy)
    }
    
    // MARK: BGResource
    
    var _debugName: String?
    public var debugName: String? {
        get {
            if _debugName != nil {
                return _debugName
            } else {
                self.owner?.loadDebugNames()
                return _debugName
            }
        }
        set { _debugName = newValue }
    }
    public var _event: BGEvent = .unknownPast
    
    // MARK: BGResourceInternal
    
    var subsequents = Set<BGSubsequentLink>()
    weak var supplier: BGBehavior?
    weak var owner: BGExtent?
    var _prevEvent: BGEvent = .unknownPast
    var _order: BGDemandable?
    
    func shouldSkipUpdate(_ other: Void) -> Bool { false }
    var deferClearingTransientValue: Bool { false }
    func clearTransientValue() {}
    
    // MARK: CustomDebugStringConvertible
    
    public var debugDescription: String {
        var updated = false
        if let currentEvent = graph?.currentEvent,
           currentEvent.sequence == _event.sequence {
            updated = true
        }
        
        return "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(debugName ?? "Unlabeled")), updated=\(updated)>"
    }
}

public class BGTypedMoment<Type>: BGResource, BGResourceInternal {
    public var updatedValue: Type? {
        verifyDemands()
        return _value
    }

    public func update(_ newValue: Type) {
        _update(newValue)
    }

    public func updateWithAction(_ newValue: Type, file: String = #fileID, line: Int = #line, function: String = #function, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        _updateWithAction(newValue, file: file, line: line, function: function, syncStrategy: syncStrategy)
    }

    public func updateWithAction(_ newValue: Type, impulse: String, syncStrategy: BGGraph.SynchronizationStrategy? = nil) {
        _updateWithAction(newValue, impulse: impulse, syncStrategy: syncStrategy)
    }
    
    func shouldSkipUpdate(_ other: Type?) -> Bool { false }
    var deferClearingTransientValue: Bool { true }
    
    func clearTransientValue() {
        _value = nil
    }
    
    // MARK: BGResource
    
    var _debugName: String?
    public var debugName: String? {
        get {
            if _debugName != nil {
                return _debugName
            } else {
                self.owner?.loadDebugNames()
                return _debugName
            }
        }
        set { _debugName = newValue }
    }
    public var _event: BGEvent = .unknownPast
    
    // MARK: BGResourceInternal
    
    typealias ValueType = Type?
    var subsequents = Set<BGSubsequentLink>()
    weak var supplier: BGBehavior?
    weak var owner: BGExtent?
    var _prevEvent: BGEvent = .unknownPast
    var _order: BGDemandable?
    public var _value: Type?
    
    // MARK: CustomDebugStringConvertible
    
    public var debugDescription: String {
        let updated: String
        if let value = _value {
            updated = " updatedValue=\(String(describing: value))"
        } else {
            updated = ""
        }
        
        return "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(debugName ?? "Unlabeled")\(updated)>"
    }
}

public enum BGStateComparison {
    public enum None { case none }
    public enum Equal { case equal }
    public enum Identical { case identical }
}

public class BGState<Type>: BGResource, BGResourceInternal {
    var _prevValue: Type?
    private var comparison: ((_ lhs: Type, _ rhs: Type) -> Bool)?
    
    init(_ value: Type, comparison: ((_ lhs: Type, _ rhs: Type) -> Bool)?) {
        self.comparison = comparison
        self._value = value
        self._prevValue = value
    }
    
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
    
    public var updatedValue: Type? {
        verifyDemands()
        return justUpdated() ? _value : nil
    }
    
    func valueEquals(_ other: Type) -> Bool {
        if let comparison = comparison {
            return comparison(_value, other)
        } else {
            return false
        }
    }
    
    public func update(_ newValue: Type, forced: Bool = false) {
        guard case .updateable(let graph, let event) = updateable else {
            return
        }
        
        if forced || !valueEquals(newValue) {
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
    
    // MARK: BGResource
    
    var _debugName: String?
    public var debugName: String? {
        get {
            if _debugName != nil {
                return _debugName
            } else {
                self.owner?.loadDebugNames()
                return _debugName
            }
        }
        set { _debugName = newValue }
    }
    public var _event: BGEvent = .unknownPast
    
    // MARK: BGResourceInternal
    
    var subsequents = Set<BGSubsequentLink>()
    weak var supplier: BGBehavior?
    weak var owner: BGExtent?
    var _prevEvent: BGEvent = .unknownPast
    var _order: BGDemandable?
    public var _value: Type
    
    func shouldSkipUpdate(_ other: Type) -> Bool {
        valueEquals(other)
    }
    
    var deferClearingTransientValue: Bool { _prevValue != nil }
    
    func clearTransientValue() {
        // Temporarily extend the lifetime of the value on the stack to avoid a crash
        // if clearing this value triggers dealloc code that in turn accesses
        // this value.
        withExtendedLifetime(_prevValue) {
            _prevValue = nil
        }
    }
    
    // MARK: CustomDebugStringConvertible
    
    public var debugDescription: String {
        let traceValue: String
        if let prevValue = _prevValue {
            traceValue = ", traceValue=\(String(describing: prevValue))"
        } else {
            traceValue = ""
        }
        
        return "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(debugName ?? "Unlabeled") value=\(String(describing: _value))\(traceValue)>"
    }
}

public protocol BGDemandable {}

extension BGDemandable {
    
    var link: BGDemandLink {
        switch self {
            case let link as BGDemandLink:
                return link
            case let resource as any BGResourceInternal:
                return BGDemandLink(resource: resource, type: .reactive)
            default:
                preconditionFailure("Unknown `BGDemandable` type.")
        }
    }
}
