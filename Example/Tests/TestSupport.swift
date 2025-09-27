//
//  Copyright © 2021 Yahoo
//    

import Foundation
import XCTest
@testable import BGSwift

func TestAssertionHit(graph: BGGraph, _ code: () -> (), _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let assertionHit = CheckAssertionHit(graph: graph, code)
    
    if !assertionHit {
        XCTFail(message(), file: file, line: line)
    }
}

func CheckAssertionHit(graph: BGGraph, _ code: () -> ()) -> Bool {
    var assertionHit = false
    graph.debugOnAssertionFailure = { _, _, _ in
        assertionHit = true
    }
    
    defer {
        graph.debugOnAssertionFailure = nil
    }
    
    code()
    
    return assertionHit
}
