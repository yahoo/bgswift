//
//  Copyright © 2021 Yahoo
//


import Foundation
import XCTest
@testable import BGSwift

class DependenciesTest : XCTestCase {
    
    var g: BGGraph!
    var r_a, r_b, r_c: BGState<Int>!
    var bld: BGExtentBuilder<BGExtent>!
    var ext: BGExtent!

    override func setUp() {
        super.setUp()
        g = BGGraph()
        bld = BGExtentBuilder(graph: g)
        r_a = bld.state(0)
        r_b = bld.state(0)
        r_c = bld.state(0)
    }
    
    func testAActivatesB() {
        // |> Given a behavior with supplies and demands
        bld.behavior().supplies([r_b]).demands([r_a]).runs { extent in
            self.r_b.update(2 * self.r_a.value)
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction();

        // |> When the demand is updated
        r_a.updateWithAction(1)

        // |> Then the demanding behavior will run and update its supplied resource
        XCTAssertEqual(r_b.value, 2)
        XCTAssertEqual(r_b.event, r_a.event)
    }
    
    func testActivatesBehaviorsOncePerEvent() {
        // |> Given a behavior that demands multiple resources
        var called = 0
        bld.behavior().supplies([r_c]).demands([r_a, r_b]).runs { extent in
            called += 1
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        // |> When both resources are updated in same event
        self.g.action {
            self.r_a.update(1)
            self.r_b.update(2)
        }
        
        // |> Then the demanding behavior is activated only once
        XCTAssertEqual(called, 1)
    }
}

class DependenciesTest2: XCTestCase {
    
    func testBehaviorNotActivatedFromOrderingDemandUpdate() {
        let g = BGGraph()
        let b = BGExtentBuilder(graph: g)
        let r = b.moment()
        
        var reactiveLinkActivated = false
        var orderLinkActivated = false
        
        b.behavior().demands([r]).runs { extent in
            reactiveLinkActivated = true
        }
        
        b.behavior().demands([r.order]).runs { extent in
            orderLinkActivated = true
        }
        
        let ext = BGExtent(builder: b)
        g.action {
            ext.addToGraph()
            r.update()
        }
        
        XCTAssertTrue(reactiveLinkActivated)
        XCTAssertFalse(orderLinkActivated)
    }
}
