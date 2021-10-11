//
//  Copyright © 2021 Yahoo
//    

import Foundation
import XCTest
@testable import BGSwift

func TestAssertionHit(_ code: () -> (), _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let assertionHit = CheckAssertionHit(code)
    
    if !assertionHit {
        XCTFail(message(), file: file, line: line)
    }
}

func CheckAssertionHit(_ code: () -> ()) -> Bool {
    var assertionHit = false
    BGSwift.assertionFailureImpl = { _, _, _ in
        assertionHit = true
    }
    
    defer {
        BGSwift.assertionFailureImpl = nil
    }
    
    code()
    
    return assertionHit
}
