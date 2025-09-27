//
//  Copyright © 2021 Yahoo
//

import Foundation

enum OrderingState: Int {
    case ordered
    case ordering
    case unordered
}

public class BGBehavior {
    var orderingState = OrderingState.ordered
    var order = UInt(0)
    var enqueuedSequence = UInt(0)
    var lastUpdateSequence = UInt(0)
    var removedSequence = UInt(0)
    
    var debugName: String?
    
    var staticSupplies = Set<WeakResource>()
    var staticDemands = Set<BGDemandLink>()
    
    var supplies = Set<WeakResource>()
    var demands = Set<BGDemandLink>()
    
    var uncommittedDynamicSupplies: [any BGResourceInternal]?
    var uncommittedDynamicDemands: [BGDemandable]?
    
    var uncommittedSupplies: Bool
    var uncommittedDemands: Bool
    
    let runBlock: (BGExtent) -> Void
    
    weak var owner: BGExtent?
    var graph: BGGraph? { owner?.graph }
    
    
    internal init(graph: BGGraph, supplies: [BGResource], demands: [BGDemandable], body: @escaping (BGExtent) -> Void) {
        self.runBlock = body
        
        uncommittedSupplies = !supplies.isEmpty
        uncommittedDemands = !demands.isEmpty
        
        supplies.forEach {
            let resource = $0.asInternal
            guard resource.supplier == nil else {
                graph.assertionFailure("Resource is already supplied by a different behavior.")
                return
            }
            staticSupplies.insert(resource.weakReference)
            resource.supplier = self
        }
        
        demands.forEach { staticDemands.insert($0.link) }
    }
    
    func run() {
        guard let owner = self.owner else {
            return
        }
        runBlock(owner)
    }
    
    public func setDynamicSupplies(_ supplies: [BGResource]) {
        uncommittedDynamicSupplies = (supplies.map { $0.asInternal} )
        uncommittedSupplies = true
        
        if let owner = owner, owner.status == .added {
            owner.graph.updateSupplies(behavior: self)
        }
    }
    
    public func setDynamicSupplies(_ supplies: BGResource...) {
        setDynamicSupplies(supplies as [BGResource])
    }
    
    public func setDynamicDemands(_ demands: [BGDemandable]) {
        uncommittedDynamicDemands = demands
        uncommittedDemands = true
        
        if let owner = owner, owner.status == .added {
            owner.graph.updateDemands(behavior: self)
        }
    }
    
    public func setDynamicDemands(_ demands: BGDemandable...) {
        setDynamicDemands(demands)
    }
}

extension BGBehavior: CustomDebugStringConvertible {
    public var debugDescription: String {
        "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(debugName ?? "Unlabeled"))>"
    }
}

extension BGBehavior: Equatable {
    public static func == (lhs: BGBehavior, rhs: BGBehavior) -> Bool { lhs === rhs }
    
}

extension BGBehavior: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
