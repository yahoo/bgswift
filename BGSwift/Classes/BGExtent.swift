//
//  Copyright © 2021 Yahoo
//

import Foundation

open class BGExtent: Hashable, CustomDebugStringConvertible {
    public let graph: BGGraph
    
    var resources = [any BGResourceInternal]()
    var behaviors = [BGBehavior]()
    
    var _added: BGMoment
    public var added: BGResource { _added }
    var _mirror: Mirror?
    
    public enum Status {
        case inactive
        case added
        case removed
    }
    public var status: Status = .inactive
    
    public var debugName: String?
    
    public init(builder: BGExtentBuilderGeneric) {
        assert(builder.extent == nil)
        
        graph = builder.graph
        _added = builder._added
        
        builder.extent = self
        
        self.addComponents(from: builder)
        
#if DEBUG
        onExtentCreated?(self)
#endif
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
    
    func addComponents(from builder: BGExtentBuilderGeneric) {
        guard builder.graph === graph,
              status == .inactive
        else {
            assertionFailure()
            return
        }

        builder.resources.forEach {
            $0.owner = self
        }

        builder.behaviors.forEach {
            $0.owner = self
        }

        resources.append(contentsOf: builder.resources)
        behaviors.append(contentsOf: builder.behaviors)

        builder.resources.removeAll()
        builder.behaviors.removeAll()
    }
    
    open func addToGraph() {
        graph.addExtent(self)
    }
    
    public func addToGraphWithAction() {
        graph.action {
            self.addToGraph()
        }
    }
    
    open func removeFromGraph() {
        guard status == .added else {
//            assertionFailure("Extents can only be removed once after adding.")
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
    
    internal func loadDebugNames() {
        if (_mirror == nil) {
            _mirror = Mirror(reflecting: self)
            while let mirror = _mirror, mirror.subjectType is BGExtent.Type {
                mirror.children.forEach { child in
                    if let resource = child.value as? (any BGResourceInternal) {
                        if resource.debugName == nil {
                            resource.debugName = "\(String(describing: Self.self)).\(child.label ?? "Anonymous_Resource")"
                        }
                    } else if let behavior = child.value as? BGBehavior {
                        if behavior.debugName == nil {
                            behavior.debugName = "\(String(describing: Self.self)).\(child.label ?? "Anonymous_Behavior")"
                        }
                    }
                }
                _mirror = mirror.superclassMirror
            }
        }
    }
    
    public func sideEffect(file: String = #fileID, line: Int = #line, function: String = #function, _ body: @escaping () -> Void) {
        let impulse = BGGraph.impulseString(file: file, line: line, function: function)
        sideEffect(impulse, body)
    }
    
    public func sideEffect(_ label: String?, _ body: @escaping () -> Void) {
        graph.sideEffect(label, body: body)
    }
    
    // MARK: CustomDebugStringConvertible
    
    public var debugDescription: String {
        "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(debugName ?? "Unlabeled"))>"
    }
    
    // MARK: Equatable
    
    public static func == (lhs: BGExtent, rhs: BGExtent) -> Bool { lhs === rhs }
    
    // MARK: Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

public class BGExtentBuilderGeneric: NSObject {
    var resources = [any BGResourceInternal]()
    var behaviors = [BGBehavior]()
    let graph: BGGraph
    let _added: BGMoment
    public var added: BGResource { _added }
    
    var extent: BGExtent?
    
    init(graph: BGGraph) {
        self.graph = graph
        
        let added = BGMoment()
        self._added = added
        resources.append(added)
    }
    
    init(extent: BGExtent) {
        self.graph = extent.graph
        self._added = extent._added
        self.extent = extent
    }
    
    public func moment() -> BGMoment {
        let moment = BGMoment()
        
        if let extent = extent {
            assert(extent.status == .inactive)
            moment.owner = extent
            extent.resources.append(moment)
        } else {
            resources.append(moment)
        }
        
#if DEBUG
        onResourceCreated?(moment)
#endif
        
        return moment
    }
    
    public func typedMoment<T>() -> BGTypedMoment<T> {
        let moment = BGTypedMoment<T>()
        
        if let extent = extent {
            assert(extent.status == .inactive)
            moment.owner = extent
            extent.resources.append(moment)
        } else {
            resources.append(moment)
        }
        
#if DEBUG
        onResourceCreated?(moment)
#endif
        
        return moment
    }
    
    public func state<T>(_ value: T, comparison: @escaping (_ lhs: T, _ rhs: T) -> Bool) -> BGState<T> {
        let state = BGState(value, comparison: comparison)
        
        if let extent = extent {
            assert(extent.status == .inactive)
            state.owner = extent
            extent.resources.append(state)
        } else {
            resources.append(state)
        }
        
#if DEBUG
        onResourceCreated?(state)
#endif
        
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
    
    public func generic_behavior() -> BGBehaviorBuilderGeneric { BGBehaviorBuilderGeneric(self) }
    
    func behavior<Extent: BGExtent>(supplies mainBehaviorStaticSupplies: [BGResource],
                                    demands mainBehaviorStaticDemands: [BGDemandable],
                                    preDynamicSupplies: BGDynamicSupplyBuilderGeneric?,
                                    postDynamicSupplies: BGDynamicSupplyBuilderGeneric?,
                                    preDynamicDemands: BGDynamicDemandBuilderGeneric?,
                                    postDynamicDemands: BGDynamicDemandBuilderGeneric?,
                                    body: @escaping (_ extent: Extent) -> Void) -> BGBehavior {
        weak var weakMainBehavior: BGBehavior?
        
        var mainBehaviorStaticSupplies = mainBehaviorStaticSupplies
        var mainBehaviorStaticDemands = mainBehaviorStaticDemands
        
        if postDynamicSupplies != nil || postDynamicDemands != nil {
            let orderingResource = moment()
            orderingResource.debugName = "DynamicPostOrdering"
            mainBehaviorStaticSupplies.append(orderingResource)
            
            if let postDynamicSupplies = postDynamicSupplies {
                var demands = postDynamicSupplies.demands
                demands.append(orderingResource)
                let dynamicDemands = postDynamicSupplies._dynamicDemands
                let resolver = postDynamicSupplies.resolver
                generic_behavior()
                    .demands(demands)
                    .generic_dynamicDemands(dynamicDemands)
                    .generic_runs { extent in
                        guard let mainBehavior = weakMainBehavior else {
                            return
                        }
                        mainBehavior.setDynamicSupplies(resolver(extent).compactMap { $0 })
                    }
            }
            
            if let postDynamicDemands = postDynamicDemands {
                var demands = postDynamicDemands.demands
                demands.append(orderingResource)
                let dynamicDemands = postDynamicDemands._dynamicDemands
                let resolver = postDynamicDemands.resolver
                generic_behavior()
                    .demands(demands)
                    .generic_dynamicDemands(dynamicDemands)
                    .generic_runs { extent in
                        guard let mainBehavior = weakMainBehavior else {
                            return
                        }
                        mainBehavior.setDynamicDemands(resolver(extent).compactMap { $0 })
                    }
            }
        }
        
        if let preDynamicSupplies = preDynamicSupplies {
            let orderingResource = moment()
            orderingResource.debugName = "DynamicSuppliesPreOrdering"
            mainBehaviorStaticDemands.append(orderingResource)
            
            let supplies = [orderingResource]
            let demands = preDynamicSupplies.demands
            let dynamicDemands = preDynamicSupplies._dynamicDemands
            let resolver = preDynamicSupplies.resolver
            generic_behavior()
                .supplies(supplies)
                .demands(demands)
                .generic_dynamicDemands(dynamicDemands)
                .generic_runs { extent in
                    guard let mainBehavior = weakMainBehavior else {
                        return
                    }
                    mainBehavior.setDynamicSupplies(resolver(extent).compactMap { $0 })
                }
        }
        
        if let preDynamicDemands = preDynamicDemands {
            let orderingResource = moment()
            orderingResource.debugName = "DynamicDemandsPreOrdering"
            mainBehaviorStaticDemands.append(orderingResource)
            
            let supplies = [orderingResource]
            let demands = preDynamicDemands.demands
            let dynamicDemands = preDynamicDemands._dynamicDemands
            let resolver = preDynamicDemands.resolver
            generic_behavior()
                .supplies(supplies)
                .demands(demands)
                .generic_dynamicDemands(dynamicDemands)
                .generic_runs { extent in
                    guard let mainBehavior = weakMainBehavior else {
                        return
                    }
                    mainBehavior.setDynamicDemands(resolver(extent).compactMap { $0 })
                }
        }
        
        let mainBehavior = BGBehavior(supplies: mainBehaviorStaticSupplies, demands: mainBehaviorStaticDemands) { extent in
            body(extent as! Extent)
        }
        weakMainBehavior = mainBehavior
        
        if let extent = extent {
            assert(extent.status == .inactive)
            mainBehavior.owner = extent
            extent.behaviors.append(mainBehavior)
        } else {
            behaviors.append(mainBehavior)
        }
        
        return mainBehavior
    }
}

public class BGExtentBuilder<Extent: BGExtent>: BGExtentBuilderGeneric {
    public override init(graph: BGGraph) {
        super.init(graph: graph)
    }
    
    public override init(extent: BGExtent) {
        super.init(extent: extent)
    }
    
    public func behavior() -> BGBehaviorBuilder<Extent> { BGBehaviorBuilder(self) }
}

public class BGParameterizedExtentBuilder<Extent: BGExtent, Params>: BGExtentBuilderGeneric {
    let paramsBlock: (_ extent: Extent) -> Params?
    
    public init(graph: BGGraph, _ paramsBlock: @escaping (_ extent: Extent) -> Params?) {
        self.paramsBlock = paramsBlock
        super.init(graph: graph)
    }

    public init(extent: Extent, _ paramsBlock: @escaping (_ extent: Extent) -> Params?) {
        self.paramsBlock = paramsBlock
        super.init(extent: extent)
    }

    public func behavior() -> BGParameterizedBehaviorBuilder<Extent, Params> { BGParameterizedBehaviorBuilder(self) }
}

public class BGBehaviorBuilderGeneric: NSObject {
    let builder: BGExtentBuilderGeneric
    
    var _supplies = [BGResource]()
    var _demands = [BGDemandable]()
    var _preDynamicSupplies: BGDynamicSupplyBuilderGeneric?
    var _postDynamicSupplies: BGDynamicSupplyBuilderGeneric?
    var _preDynamicDemands: BGDynamicDemandBuilderGeneric?
    var _postDynamicDemands: BGDynamicDemandBuilderGeneric?
    
    public init(_ builder: BGExtentBuilderGeneric) {
        self.builder = builder
    }
    
    @discardableResult
    public func supplies(_ supplies: [BGResource]) -> Self {
        _supplies = supplies
        return self
    }
    
    @discardableResult
    public func supplies(_ supplies: BGResource...) -> Self {
        self.supplies(supplies as [BGResource])
        return self
    }
    
    @discardableResult
    public func demands(_ demands: [BGDemandable]) -> Self {
        _demands = demands
        return self
    }
    
    @discardableResult
    public func demands(_ demands: BGDemandable...) -> Self {
        self.demands(demands as [BGDemandable])
    }
    
    @discardableResult
    func generic_dynamicSupplies(_ dynamicSupplies: BGDynamicSupplyBuilderGeneric?) -> BGBehaviorBuilderGeneric {
        if let dynamicSupplies = dynamicSupplies {
            switch dynamicSupplies.order {
            case .pre:
                _preDynamicSupplies = dynamicSupplies
            case .post:
                _postDynamicSupplies = dynamicSupplies
            }
        }
        return self
    }
    
    @discardableResult
    func generic_dynamicDemands(_ dynamicDemands: BGDynamicDemandBuilderGeneric?) -> BGBehaviorBuilderGeneric {
        if let dynamicDemands = dynamicDemands {
            switch dynamicDemands.order {
            case .pre:
                _preDynamicDemands = dynamicDemands
            case .post:
                _postDynamicDemands = dynamicDemands
            }
        }
        return self
    }
    
    @discardableResult
    func generic_runs(_ body: @escaping (_ extent: BGExtent) -> Void) -> BGBehavior {
        builder.behavior(supplies: _supplies,
                         demands: _demands,
                         preDynamicSupplies: _preDynamicSupplies,
                         postDynamicSupplies: _postDynamicSupplies,
                         preDynamicDemands: _preDynamicDemands,
                         postDynamicDemands: _postDynamicDemands,
                         body: body)
    }
}

public class BGBehaviorBuilder<Extent: BGExtent> : BGBehaviorBuilderGeneric {
    
    @discardableResult
    public func dynamicSupplies(_ dynamicSupplies: BGDynamicSupplyBuilder<Extent>) -> Self {
        generic_dynamicSupplies(dynamicSupplies)
        return self
    }
    
    @discardableResult
    public func dynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>) -> Self {
        generic_dynamicDemands(dynamicDemands)
        return self
    }
    
    @discardableResult
    public func runs(_ body: @escaping (_ extent: Extent) -> Void) -> BGBehavior {
        builder.behavior(supplies: _supplies,
                         demands: _demands,
                         preDynamicSupplies: _preDynamicSupplies,
                         postDynamicSupplies: _postDynamicSupplies,
                         preDynamicDemands: _preDynamicDemands,
                         postDynamicDemands: _postDynamicDemands) { extent in
            body(extent as! Extent)
        }
    }
}

public class BGParameterizedBehaviorBuilder<Extent: BGExtent, Params> : BGBehaviorBuilderGeneric {
    let paramsBlock: (_ extent: Extent) -> Params?
    public init(_ builder: BGParameterizedExtentBuilder<Extent, Params>) {
        paramsBlock = builder.paramsBlock
        super.init(builder)
    }
    
    @discardableResult
    public func dynamicSupplies(_ dynamicSupplies: BGDynamicSupplyBuilder<Extent>) -> Self {
        generic_dynamicSupplies(dynamicSupplies)
        return self
    }
    
    @discardableResult
    public func dynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>) -> Self {
        generic_dynamicDemands(dynamicDemands)
        return self
    }
    
    @discardableResult
    public func runs(_ body: @escaping (_ p: Params) -> Void) -> BGBehavior {
        let paramsBlock = self.paramsBlock
        return builder.behavior(supplies: _supplies,
                                demands: _demands,
                                preDynamicSupplies: _preDynamicSupplies,
                                postDynamicSupplies: _postDynamicSupplies,
                                preDynamicDemands: _preDynamicDemands,
                                postDynamicDemands: _postDynamicDemands) { extent in
            if let params = paramsBlock(extent as! Extent) {
                body(params)
            }
        }
    }
}

public enum BGDynamicsOrderingType: Int {
    case pre
    case post
}

public class BGDynamicSupplyBuilderGeneric {
    let order: BGDynamicsOrderingType
    let demands: [BGDemandable]
    var _dynamicDemands: BGDynamicDemandBuilderGeneric?
    let resolver: (_ extent: BGExtent) -> [BGResource?]
    
    init(_ order: BGDynamicsOrderingType,
         demands: [BGDemandable],
         _ resolver: @escaping (_ extent: BGExtent) -> [BGResource?]) {
        self.order = order
        self.demands = demands
        self.resolver = resolver
    }
    
    @discardableResult
    func generic_withDynamicDemands(_ dynamicDemands: BGDynamicDemandBuilderGeneric?) -> BGDynamicSupplyBuilderGeneric {
        _dynamicDemands = dynamicDemands
        return self
    }
}

public class BGDynamicSupplyBuilder<Extent: BGExtent>: BGDynamicSupplyBuilderGeneric {
    public init(_ order: BGDynamicsOrderingType,
                demands: [BGDemandable],
                _ resolver: @escaping (_ extent: Extent) -> [BGResource?]) {
        super.init(order, demands: demands) { extent in
            resolver(extent as! Extent)
        }
    }
    
    public func withDynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>?) -> BGDynamicSupplyBuilder<Extent> {
        self.generic_withDynamicDemands(dynamicDemands)
        return self
    }
}

public class BGDynamicDemandBuilderGeneric {
    let order: BGDynamicsOrderingType
    let demands: [BGDemandable]
    var _dynamicDemands: BGDynamicDemandBuilderGeneric?
    let resolver: (_ extent: BGExtent) -> [BGDemandable?]
    
    init(_ order: BGDynamicsOrderingType,
         demands: [BGDemandable],
         _ resolver: @escaping (_ extent: BGExtent) -> [BGDemandable?]) {
        self.order = order
        self.demands = demands
        self.resolver = resolver
    }
    
    @discardableResult
    func generic_withDynamicDemands(_ dynamicDemands: BGDynamicDemandBuilderGeneric?) -> BGDynamicDemandBuilderGeneric {
        _dynamicDemands = dynamicDemands
        return self
    }
}

public class BGDynamicDemandBuilder<Extent: BGExtent>: BGDynamicDemandBuilderGeneric {
    public init(_ order: BGDynamicsOrderingType,
                demands: [BGDemandable],
                _ resolver: @escaping (_ extent: Extent) -> [BGDemandable?]) {
        super.init(order, demands: demands) { extent in
            resolver(extent as! Extent)
        }
    }
    
    public func withDynamicDemands(_ dynamicDemands: BGDynamicDemandBuilder<Extent>?) -> BGDynamicDemandBuilder<Extent> {
        generic_withDynamicDemands(dynamicDemands)
        return self
    }
}
