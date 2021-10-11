//
//  Copyright © 2021 Yahoo
//

import Foundation

class Mutex {
    let mutex: UnsafeMutablePointer<pthread_mutex_t>
    
    init(recursive: Bool = true) {
        let attributes = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
        attributes.initialize(to: pthread_mutexattr_t())
        
        guard pthread_mutexattr_init(attributes) == 0 else {
            preconditionFailure()
        }
        
        defer {
            pthread_mutexattr_destroy(attributes)
            attributes.deallocate()
        }
        
        pthread_mutexattr_settype(attributes, recursive ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_NORMAL)
        
        mutex = .allocate(capacity: 1)
        mutex.initialize(to: pthread_mutex_t())
        
        guard pthread_mutex_init(mutex, attributes) == 0 else {
            preconditionFailure()
        }
    }
    
    deinit {
        pthread_mutex_destroy(mutex)
        mutex.deallocate()
    }
    
    // jlou 2/18/21 - Avoid concurrent execution by surrounding code with mutex lock/unlock. I believe Swift
    // compiler should be able to inline the non-escaping closure and avoid heap allocation for captured variables
    // but I will need to test this. If not, we can pass variables into the closure with a generic input argument.
    
    @inline(__always)
    func balancedUnlock(_ code: () throws -> Void) rethrows {
        lock()
        defer {
            unlock()
        }
        try code()
    }
    
    @inline(__always)
    func balancedUnlock<T>(_ code: () throws -> T) rethrows -> T {
        lock()
        defer {
            unlock()
        }
        return try code()
    }
    
    @inline(__always)
    func lock() {
        pthread_mutex_lock(mutex)
    }
    
    @inline(__always)
    func tryLock() -> Bool {
        return pthread_mutex_trylock(mutex) == 0
    }
    
    @inline(__always)
    func unlock() {
        pthread_mutex_unlock(mutex)
    }
}
