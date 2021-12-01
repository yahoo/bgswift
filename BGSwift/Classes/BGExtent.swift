//
//  Copyright © 2021 Yahoo
//


import Foundation

open class BGExtent {
    public weak var graph: BGGraph?
    
    let resources: [BGResource]
    let behaviors: [BGBehavior]
    
    var _added: BGMoment
    public var added: BGResource { _added }
    
    public init(builder: BGExtentBuilderGeneric) {
        graph = builder.graph
        _added = builder._added
        resources = builder.resources
        behaviors = builder.behaviors
        
        builder.resources.removeAll()
        builder.behaviors.removeAll()
        
        self.resources.forEach {
            $0.extent = self
        }
        
        self.behaviors.forEach {
            $0.extent = self
        }
        
        let mirror = Mirror(reflecting: self)
        mirror.children.forEach { child in
            if let resource = child.value as? BGResource {
                if resource.propertyName == nil {
                    resource.propertyName = "\(String(describing: Self.self)).\(child.label ?? "Anonymous_Resource")"
                }
            } else if let behavior = child.value as? BGBehavior {
                if behavior.propertyName == nil {
                    behavior.propertyName = "\(String(describing: Self.self)).\(child.label ?? "Anonymous_Behavior")"
                }
            }
        }
    }
    
    deinit {
        guard let graph = self.graph else {
            return
        }
        let behaviors = self.behaviors
        
        graph.action(syncStrategy: .none) { [weak graph] in
            guard let graph = graph else {
                return
            }
            
            behaviors.forEach(graph.removeBehavior)
        }
    }
    
    public func addToGraph() {
        graph?.addExtent(self)
    }
    
    public func addToGraphWithAction() {
        graph?.action {
            self.addToGraph()
        }
    }
    
    public func sideEffect(file: String = #fileID, line: Int = #line, function: String = #function, _ body: @escaping () -> Void) {
        let impulse = BGGraph.impulseString(file: file, line: line, function: function)
        sideEffect(impulse, body)
    }
    
    public func sideEffect(_ label: String?, _ body: @escaping () -> Void) {
        guard let graph = graph else {
            // assert
            return
        }
        graph.sideEffect(label, body: body)
    }
}

public class BGExtentBuilderGeneric {
    var resources = [BGResource]()
    var behaviors = [BGBehavior]()
    let graph: BGGraph
    let _added = BGMoment()
    public var added: BGResource { _added }
    
    public init(graph: BGGraph) {
        self.graph = graph
        resources.append(_added)
    }
    
    public func moment() -> BGMoment {
        let moment = BGMoment()
        resources.append(moment)
        return moment
    }
    
    public func typedMoment<T>() -> BGTypedMoment<T> {
        let moment = BGTypedMoment<T>()
        resources.append(moment)
        return moment
    }
    
    public func state<T>(_ value: T, comparison: @escaping (T, T) -> Bool) -> BGState<T> {
        let state = BGState(value, comparison: comparison)
        resources.append(state)
        return state
    }
    
    @_disfavoredOverload
    public func state<T>(_ value: T, comparison: BGResource.ComparisonNone = .none) -> BGState<T> {
        return state(value) { _, _ in
            false
        }
    }
    
    public func state<T: Equatable>(_ value: T, comparison: BGResource.ComparisonEqual = .equal) -> BGState<T> {
        return state(value) { lhs, rhs in
            lhs == rhs
        }
    }
    
    public func state<T: AnyObject>(_ value: T, comparison: BGResource.ComparisonIdentical = .identical) -> BGState<T> {
        return state(value) { lhs, rhs in
            lhs === rhs
        }
    }
    
    @_disfavoredOverload
    public func state<T: BGOptionalObject>(_ value: T, comparison: BGResource.ComparisonIdentical = .identical) -> BGState<T> {
        return state(value) { lhs, rhs in
            lhs.bg_unwrapped === rhs.bg_unwrapped
        }
    }
}

public class BGExtentBuilder<Extent: BGExtent>: BGExtentBuilderGeneric {
    
    @discardableResult public func behavior(supplies staticSupplies: [BGResource] = [],
                                            demands staticDemands: [BGResource] = [],
                                            body: @escaping (Extent) -> Void) -> BGBehavior {
        return behavior(supplies: staticSupplies, demands: staticDemands, dynamicSupplies: nil, dynamicDemands: nil, body: body)
    }
    
    @discardableResult public func behavior(supplies staticSupplies: [BGResource] = [],
                                            demands staticDemands: [BGResource] = [],
                                            dynamicSupplies: DynamicResourceLink<Extent>? = nil,
                                            dynamicDemands: DynamicResourceLink<Extent>? = nil,
                                            body: @escaping (Extent) -> Void) -> BGBehavior {
        let genericBody: (BGExtent) -> Void = { extent in
            body(extent as! Extent)
        }
        
        var extendedDemands = staticDemands
        var extendedSupplies = staticSupplies
        let dynamicSuppliesOrderingResource: BGResource?
        let dynamicDemandsOrderingResource: BGResource?
        
        if let dynamicSupplies = dynamicSupplies, !dynamicSupplies.switches.isEmpty {
            let orderingResource = moment()
            orderingResource.propertyName = "DynamicSuppliesOrdering"
            
            dynamicSuppliesOrderingResource = orderingResource
            
            switch dynamicSupplies.order {
            case .pre:
                extendedDemands.append(orderingResource)
            case .post:
                extendedSupplies.append(orderingResource)
            }
        } else {
            dynamicSuppliesOrderingResource = nil
        }
        
        if let dynamicDemands = dynamicDemands, !dynamicDemands.switches.isEmpty {
            let orderingResource = moment()
            orderingResource.propertyName = "DynamicDemandsOrdering"
            
            dynamicDemandsOrderingResource = orderingResource
            
            switch dynamicDemands.order {
            case .pre:
                extendedDemands.append(orderingResource)
            case .post:
                extendedSupplies.append(orderingResource)
            }
        } else {
            dynamicDemandsOrderingResource = nil
        }
        
        let behavior = BGBehavior(supplies: extendedSupplies,
                                  demands: extendedDemands,
                                  body: genericBody)
        behaviors.append(behavior)
        
        if let dynamicSupplies = dynamicSupplies, let orderingResource = dynamicSuppliesOrderingResource {
            let resolver = dynamicSupplies.resolver
            
            var implicitBehaviorSupplies = [BGResource]()
            var implicitBehaviorDemands = dynamicSupplies.switches
            switch dynamicSupplies.order {
            case .pre:
                implicitBehaviorSupplies.append(orderingResource)
            case .post:
                implicitBehaviorDemands.append(orderingResource)
            }
            
            let implicitBehavior = BGBehavior(supplies: implicitBehaviorSupplies, demands: implicitBehaviorDemands) { [weak behavior] extent in
                guard let behavior = behavior else {
                    return
                }
                var supplies = staticSupplies
                supplies.append(contentsOf: resolver(extent as! Extent).compactMap { $0 })
                behavior.setSupplies(supplies)
            }
            behaviors.append(implicitBehavior)
        }
        
        if let dynamicDemands = dynamicDemands, let orderingResource = dynamicDemandsOrderingResource {
            let resolver = dynamicDemands.resolver
            
            var implicitBehaviorSupplies = [BGResource]()
            var implicitBehaviorDemands = dynamicDemands.switches
            switch dynamicDemands.order {
            case .pre:
                implicitBehaviorSupplies.append(orderingResource)
            case .post:
                implicitBehaviorDemands.append(orderingResource)
            }
            
            let implicitBehavior = BGBehavior(supplies: implicitBehaviorSupplies, demands: implicitBehaviorDemands) { [weak behavior] extent in
                guard let behavior = behavior else {
                    return
                }
                var demands = extendedDemands
                demands.append(contentsOf: resolver(extent as! Extent).compactMap { $0 })
                behavior.setDemands(demands)
            }
            behaviors.append(implicitBehavior)
        }
        
        return behavior
    }
}

public class DynamicResourceLink<Extent: BGExtent> {
    var switches: [BGResource]
    var order: OrderingType
    var resolver: (Extent) -> ([BGResource?])
    
    public enum OrderingType {
        case pre
        case post
    }
    
    public init(switches: [BGResource], order: OrderingType, _ resolver: @escaping (Extent) -> ([BGResource?])) {
        self.switches = switches
        self.order = order
        self.resolver = resolver
    }
}


