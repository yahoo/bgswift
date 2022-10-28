//
//  Copyright © 2021 Yahoo
//    

import Foundation
import XCTest
import BGSwift

class AssertionTests: XCTestCase {
    
    func testAssertsUndeclaredDemandWithSupplier() {
        var assertionHit = false
        
        let g = BGGraph()
        
        let b = BGExtentBuilder(graph: g)
        let r = b.moment()
        
        b.behavior().supplies([r]).runs { _ in
            // do nothing
        }
        
        b.behavior().demands([b.added]).runs { extent in
            assertionHit = CheckAssertionHit {
                _ = r.justUpdated()
            }
        }
        
        let e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        XCTAssertTrue(assertionHit)
    }
    
    func testAssertsUndeclaredDemandWithNoSupplier() {
        var assertionHit = false
        
        let g = BGGraph()
        
        let b = BGExtentBuilder(graph: g)
        let r = b.moment()
        
        b.behavior().demands([b.added]).runs { extent in
            assertionHit = CheckAssertionHit {
                _ = r.justUpdated()
            }
        }
        
        let e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        XCTAssertTrue(assertionHit)
    }
}
