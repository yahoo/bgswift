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
    
    var propertyName: String?
    
    var supplies = WeakSet<BGResource>()
    var demands = WeakSet<BGResource>()
    
    var modifiedDemands: [BGResource]?
    var modifiedSupplies: [BGResource]?
    
    let runBlock: (BGExtent) -> Void
    
    weak var extent: BGExtent?
    
    
    init(supplies: [BGResource], demands: [BGResource], body: @escaping (BGExtent) -> Void) {
        modifiedSupplies = supplies
        modifiedDemands = demands
        
        self.runBlock = body
    }
    
    func run() {
        guard let extent = self.extent else {
            return
        }
        runBlock(extent)
    }
    
    
    public func setDemands(_ demands: [BGResource]) {
        modifiedDemands = demands
        extent?.graph?.updateDemands(behavior: self)
    }
    
    public func setSupplies(_ supplies: [BGResource]) {
        modifiedSupplies = supplies
        extent?.graph?.updateSupplies(behavior: self)
    }
}

extension BGBehavior: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "<\(String(describing: Self.self)):\(String(format: "%018p", unsafeBitCast(self, to: Int64.self))) (\(propertyName ?? "Unlabeled"))>"
    }
}
