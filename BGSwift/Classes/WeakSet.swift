//
//  Copyright © 2021 Yahoo
//

import Foundation

class WeakSetIterator<Value: AnyObject> {
    private let enumerator: NSEnumerator
    
    init(_ enumerator: NSEnumerator) {
        self.enumerator = enumerator
    }
}

extension WeakSetIterator: IteratorProtocol {
    typealias Element = Value
    
    func next() -> Value? { enumerator.nextObject() as! Value? }
}

class WeakSet<Value: AnyObject> {
    private let hashTable = NSHashTable<Value>.weakObjects()
    
    var count: Int { hashTable.allObjects.count }
    func add(_ value: Value) { hashTable.add(value) }
    func remove(_ value: Value) { hashTable.remove(value) }
    func removeAll() { hashTable.removeAllObjects() }
}

extension WeakSet: Sequence {
    typealias Iterator = WeakSetIterator<Value>
    
    func makeIterator() -> WeakSetIterator<Value> {
        WeakSetIterator(hashTable.objectEnumerator())
    }
    
    func contains(_ element: WeakSet.Element) -> Bool { hashTable.contains(element) }
}

extension WeakSet: CustomDebugStringConvertible {
    var debugDescription: String {
        hashTable.allObjects.debugDescription
    }
}
