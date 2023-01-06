//
//  Copyright © 2021 Yahoo
//


import Foundation

open class BGExtent: NSObject {
    public let graph: BGGraph
    
    var resources: [BGResourceInternal]
    var behaviors: [BGBehavior]
    
    var _added: BGMoment
    public var added: BGResource { _added }
    
    enum Status {
        case inactive
        case added
        case removed
    }
    var status: Status = .inactive
    
    public init(builder: BGExtentBuilderGeneric) {
        graph = builder.graph
        _added = builder._added
        resources = builder.resources
        behaviors = builder.behaviors
        
        builder.resources.removeAll()
        builder.behaviors.removeAll()
        
        super.init()
        
        self.resources.forEach {
            $0.owner = self
        }
        
        self.behaviors.forEach {
            $0.owner = self
        }
        
        let mirror = Mirror(reflecting: self)
        mirror.children.forEach { child in
            if let resource = child.value as? BGResourceInternal {
                if resource.debugName == nil {
                    resource.debugName = "\(String(describing: Self.self)).\(child.label ?? "Anonymous_Resource")"
                }
            } else if let behavior = child.value as? BGBehavior {
                if behavior.debugName == nil {
                    behavior.debugName = "\(String(describing: Self.self)).\(child.label ?? "Anonymous_Behavior")"
                }
            }
        }
    }
    
    deinit {
        guard status == .added else {
            return
        }
        status = .removed

        let resources = resources
        let behaviors = behaviors
        let graph = graph
        graph.action { [weak graph] in
            graph?.removeExtent(resources: resources, behaviors: behaviors)
        }
    }
    
    public func addToGraph() {
        graph.addExtent(self)
    }
    
    public func addToGraphWithAction() {
        graph.action {
            self.addToGraph()
        }
    }
    
    public func removeFromGraph() {
        guard status == .added else {
            assertionFailure("Extents can only be removed once after adding.")
            return
        }
        
        guard graph.processingChanges else {
            assertionFailure("Can only remove behaviors during an event.")
            return
        }
        
        status = .removed
        
        let resources = resources
        let behaviors = behaviors
        self.resources.removeAll()
        self.behaviors.removeAll()
        
        graph.removeExtent(resources: resources, behaviors: behaviors)
    }
    
    public func sideEffect(file: String = #fileID, line: Int = #line, function: String = #function, _ body: @escaping () -> Void) {
        let impulse = BGGraph.impulseString(file: file, line: line, function: function)
        sideEffect(impulse, body)
    }
    
    public func sideEffect(_ label: String?, _ body: @escaping () -> Void) {
        graph.sideEffect(label, body: body)
    }
}

public class BGExtentBuilderGeneric {
    var resources = [BGResourceInternal]()
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
    public func state<T>(_ value: T, comparison: BGStateComparison.None = .none) -> BGState<T> {
        return state(value) { _, _ in
            false
        }
    }
    
    public func state<T: Equatable>(_ value: T, comparison: BGStateComparison.Equal = .equal) -> BGState<T> {
        return state(value) { lhs, rhs in
            lhs == rhs
        }
    }
    
    public func state<T: AnyObject>(_ value: T, comparison: BGStateComparison.Identical = .identical) -> BGState<T> {
        return state(value) { lhs, rhs in
            lhs === rhs
        }
    }
    
    @_disfavoredOverload
    public func state<T: BGOptionalObject>(_ value: T, comparison: BGStateComparison.Identical = .identical) -> BGState<T> {
        return state(value) { lhs, rhs in
            lhs.bg_unwrapped === rhs.bg_unwrapped
        }
    }    
}

public class BGExtentBuilder<Extent: BGExtent>: BGExtentBuilderGeneric {
    
    @discardableResult
    public func behavior() -> BGBehaviorBuilder<Extent> { BGBehaviorBuilder(self) }
    
    fileprivate func behavior(supplies staticSupplies: [BGResource],
                              demands staticDemands: [BGDemandable],
                              dynamicSupplies: BGDynamicSupplyBuilder<Extent>?,
                              dynamicDemands: BGDynamicDemandBuilder<Extent>?,
                              body: @escaping (_ extent: Extent) -> Void) -> BGBehavior {
        var staticSupplies = staticSupplies
        var staticDemands = staticDemands
        
        var postOrdering: BGMoment?
        if dynamicSupplies?.order == .post || dynamicDemands?.order == .post {
            let resource = moment()
            resource.debugName = "DynamicPostOrdering"
            staticSupplies.append(resource)
            postOrdering = resource
        }
        
        var preSuppliesOrdering: BGMoment?
        if dynamicSupplies?.order == .pre {
            let resource = moment()
            resource.debugName = "DynamicSuppliesPreOrdering"
            staticDemands.append(resource)
            preSuppliesOrdering = resource
        }
        
        var preDemandsOrdering: BGMoment?
        if dynamicDemands?.order == .pre {
            let resource = moment()
            resource.debugName = "DynamicDemandsPreOrdering"
            staticDemands.append(resource)
            preDemandsOrdering = resource
        }
        
        let mainBehavior = BGBehavior(supplies: staticSupplies, demands: staticDemands) { extent in
            body(extent as! Extent)
        }
        behaviors.append(mainBehavior)
        
        if let dynamics = dynamicSupplies {
            var demands = dynamics.demands
            var supplies = [BGResource]()
            
            switch dynamics.order {
            case .pre:
                supplies.append(preSuppliesOrdering!)
            case .post:
                demands.append(postOrdering!)
            }
            
            let resolver = dynamics.resolver
            behavior()
                .supplies(supplies)
                .demands(demands)
                .dynamicDemands(dynamics._dynamicDemands)
                .runs { [weak mainBehavior] extent in
                    guard let mainBehavior = mainBehavior else {
                        return
                    }
                    mainBehavior.setDynamicSupplies(resolver(extent).compactMap { $0 })
                }
        }
        
        if let dynamics = dynamicDemands {
            var demands = dynamics.demands
            var supplies = [BGResource]()
            
            switch dynamics.order {
            case .pre:
                supplies.append(preDemandsOrdering!)
            case .post:
                demands.append(postOrdering!)
            }
            
            let resolver = dynamics.resolver
            behavior()
                .supplies(supplies)
                .demands(demands)
                .dynamicDemands(dynamics._dynamicDemands)
                .runs { [weak mainBehavior] extent in
                    guard let mainBehavior = mainBehavior else {
                        return
                    }
                    mainBehavior.setDynamicDemands(resolver(extent).compactMap { $0 })
                }
        }
        
        return mainBehavior
    }
}

public class BGBehaviorBuilder<Extent: BGExtent> {
    let builder: BGExtentBuilder<Extent>
    
    var _supplies = [BGResource]()
    var _demands = [BGDemandable]()
    var _dynamicSupplies: BGDynamicSupplyBuilder<Extent>?
    var _dynamicDemands: BGDynamicDemandBuilder<Extent>?
    
    init(_ builder: BGExtentBuilder<Extent>) {
        self.builder = builder
    }
    
    @discardableResult
    public func supplies(_ supplies: [BGResource]) -> BGBehaviorBuilder {
        _supplies = supplies
        return self
    }
    
    @discardableResult
    public func supplies(_ supplies: BGResource...) -> BGBehaviorBuilder {
        self.supplies(supplies as [BGResource])
    }
    
    @discardableResult
    public func demands(_ demands: [BGDemandable]) -> BGBehaviorBuilder {
        _demands = demands
        return self
    }
    
    @discardableResult
    public func demands(_ demands: BGDemandable...) -> BGBehaviorBuilder {
        self.demands(demands as [BGDemandable])
    }
    
    @discardableResult
    public func dynamicSupplies(_ dynamicSupplies: BGDynamicSupplyBuilder<Extent>?) -> BGBehaviorBuilder {
        _dynamicSupplies = dynamicSupplies
        return self
    }
    
    @discardableResult
    public func dynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>?) -> BGBehaviorBuilder {
        _dynamicDemands = dynamicDemands
        return self
    }
    
    @discardableResult
    public func runs(_ body: @escaping (_ extent: Extent) -> Void) -> BGBehavior {
        builder.behavior(supplies: _supplies,
                         demands: _demands,
                         dynamicSupplies: _dynamicSupplies,
                         dynamicDemands: _dynamicDemands,
                         body: body)
    }
}

public enum BGDynamicsOrderingType {
    case pre
    case post
}

public class BGDynamicSupplyBuilder<Extent: BGExtent> {
    let order: BGDynamicsOrderingType
    let demands: [BGDemandable]
    var _dynamicDemands: BGDynamicDemandBuilder<Extent>?
    let resolver: (_ extent: Extent) -> [BGResource?]
    
    init(_ order: BGDynamicsOrderingType,
         demands: [BGDemandable],
         _ resolver: @escaping (_ extent: Extent) -> [BGResource?]) {
        self.order = order
        self.demands = demands
        self.resolver = resolver
    }
    
    public func withDynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>?) -> BGDynamicSupplyBuilder<Extent> {
        _dynamicDemands = dynamicDemands
        return self
    }
}

public class BGDynamicDemandBuilder<Extent: BGExtent> {
    let order: BGDynamicsOrderingType
    let demands: [BGDemandable]
    var _dynamicDemands: BGDynamicDemandBuilder<Extent>?
    let resolver: (_ extent: Extent) -> [BGDemandable?]
    
    public init(_ order: BGDynamicsOrderingType,
                demands: [BGDemandable],
                _ resolver: @escaping (_ extent: Extent) -> [BGDemandable?]) {
        self.order = order
        self.demands = demands
        self.resolver = resolver
    }
    
    public func withDynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>?) -> BGDynamicDemandBuilder<Extent> {
        _dynamicDemands = dynamicDemands
        return self
    }
}
