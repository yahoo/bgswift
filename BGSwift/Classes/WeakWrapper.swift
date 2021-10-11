//
//  Copyright © 2021 Yahoo
//

import Foundation

struct WeakWrapper<Value: AnyObject> {
    private let objectIdentifier: ObjectIdentifier
    weak var unwrapped: Value?
    init(_ value: Value) {
        unwrapped = value
        objectIdentifier = ObjectIdentifier(value)
    }
}

extension WeakWrapper: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(objectIdentifier)
    }
}

extension WeakWrapper: Equatable {
    static func == (lhs: WeakWrapper<Value>, rhs: WeakWrapper<Value>) -> Bool {
        return lhs.unwrapped === rhs.unwrapped
    }
}
