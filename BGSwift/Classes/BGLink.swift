//
//  Copyright © 2021 Yahoo
//    

import Foundation

enum LinkType {
    case reactive
    case order
}

struct BGSubsequentLink: Equatable, Hashable {
    weak private(set) var behavior: BGBehavior?
    let type: LinkType
    let behaviorPtr: ObjectIdentifier
    
    init(behavior: BGBehavior, type: LinkType) {
        self.behavior = behavior
        self.type = type
        behaviorPtr = ObjectIdentifier(behavior)
    }
    
    // MARK: Equatable
    
    static func == (lhs: BGSubsequentLink, rhs: BGSubsequentLink) -> Bool {
        if lhs.type == rhs.type,
           let bl = lhs.behavior, let br = rhs.behavior,
           bl === br {
            return true
        }
        return false
    }
    
    // MARK: Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(behaviorPtr)
        hasher.combine(type)
    }
}

struct BGDemandLink: BGDemandable, Equatable, Hashable {
    weak private(set) var resource: BGResourceInternal?
    let type: LinkType
    let resourcePtr: ObjectIdentifier
    
    init(resource: BGResourceInternal, type: LinkType) {
        self.resource = resource
        self.type = type
        resourcePtr = ObjectIdentifier(resource)
    }
    
    // MARK: Equatable
    
    static func == (lhs: BGDemandLink, rhs: BGDemandLink) -> Bool {
        if lhs.type == rhs.type,
           let rl = lhs.resource, let rr = rhs.resource,
           rl === rr {
            return true
        }
        return false
    }
    
    // MARK: Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(resourcePtr)
        hasher.combine(type)
    }
}
