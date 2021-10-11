//
//  Copyright © 2021 Yahoo
//

import XCTest
@testable import BGSwift

class ImpulseTests: XCTestCase {
    
    let g = BGGraph()
    
    func testActionWithUnspecifiedImpulse() {
        var impulse: String!
        
        let expectedLine = String(#line + 1)
        g.action { [g] in
            impulse = g.currentEvent!.impulse!
        }
        
        XCTAssertTrue(impulse.contains(#fileID))
        XCTAssertTrue(impulse.contains(#function))
        XCTAssertTrue(impulse.contains(expectedLine))
    }
    
    func testActionWithImpulseString() {
        var impulse: String!
        
        g.action(impulse: "foo") { [g] in
            impulse = g.currentEvent!.impulse!
        }
        
        XCTAssertEqual(impulse, "foo")
    }
}
