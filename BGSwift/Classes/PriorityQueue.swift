//
//  Copyright © 2021 Yahoo
//

import Foundation

class PriorityQueue {
    private let heap: CFBinaryHeap
    private var unheapedElements = [BGBehavior]()
    
    init() {
        var callbacks = CFBinaryHeapCallBacks(version: 0, retain: nil, release: nil, copyDescription: nil) { ptr1, ptr2, context in
            
            let lhs = Unmanaged<BGBehavior>.fromOpaque(ptr1!).takeUnretainedValue().order
            let rhs = Unmanaged<BGBehavior>.fromOpaque(ptr2!).takeUnretainedValue().order
            
            return (
            lhs < rhs ? .compareLessThan :
            lhs > rhs ? .compareGreaterThan :
                .compareEqualTo
            )
        }
        
        heap = CFBinaryHeapCreate(kCFAllocatorDefault, 0, &callbacks, nil)
    }
    
    var count: Int {
        unheapedElements.count + CFBinaryHeapGetCount(heap)
    }
    
    var isEmpty: Bool {
        unheapedElements.isEmpty && CFBinaryHeapGetCount(heap) == 0
    }
    
    func setNeedsReheap() {
        for _ in 0 ..< CFBinaryHeapGetCount(heap) {
            let value = popHeap()
            unheapedElements.append(value)
        }
    }
    
    private func reheapIfNeeded() {
        unheapedElements.forEach { element in
            let ptr = Unmanaged.passRetained(element).toOpaque()
            CFBinaryHeapAddValue(heap, ptr)
        }
        unheapedElements.removeAll()
    }
    
    func push(_ value: BGBehavior) {
        unheapedElements.append(value)
    }
    
    func pop() -> BGBehavior {
        reheapIfNeeded()
        
        guard count > 0 else {
            preconditionFailure()
        }
        
        return popHeap()
    }
    
    func peek() -> BGBehavior {
        reheapIfNeeded()
        
        guard count > 0 else {
            preconditionFailure()
        }
        
        return Unmanaged<BGBehavior>.fromOpaque(CFBinaryHeapGetMinimum(heap)).takeUnretainedValue()
    }
    
    private func popHeap() -> BGBehavior {
        let value = Unmanaged<BGBehavior>.fromOpaque(CFBinaryHeapGetMinimum(heap)).takeRetainedValue()
        CFBinaryHeapRemoveMinimumValue(heap)
        return value
    }
}
