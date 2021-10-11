//
//  Copyright © 2021 Yahoo
//    

import XCTest
@testable import BGSwift

class BGExtentTests: XCTestCase {

    var g: BGGraph!
    var b: BGExtentBuilder<BGExtent>!
    var e: BGExtent!
    var rA: BGState<Int>!
    var rB: BGState<Int>!
    var rC: BGState<Int>!

    
    override func setUpWithError() throws {
        g = BGGraph()
        b = BGExtentBuilder(graph: g)
        rA = b.state(0)
        rB = b.state(0)
        rC = b.state(0)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAddedResourceIsUpdatedOnAdding() {
        // |> Given an extent
        var run = false
        var nonAddedRun = false
        b.behavior(supplies: [], demands: [b.added]) { extent in
            run = true
        }
        b.behavior(supplies: [], demands: []) { extent in
            nonAddedRun = true
        }
        e = BGExtent(builder: b)
        
        // |> When it is added
        e.addToGraphWithAction()
        
        // |> The added resource is updated
        XCTAssertTrue(run)
        XCTAssertFalse(nonAddedRun)
    }

    func testCheckCannotAddExtentToGraphMultipleTimes() {
        // NOTE: This is primarily to prevent user error.
        // Perhaps it makes sense to remove/add extents in the future.
        
        // |> Given an extent added to a graph
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When it is added again
        // |> Then there is an error
        TestAssertionHit {
            e.addToGraphWithAction()
        }
    }

    func testCheckExtentCanOnlyBeAddedDuringEvent() {
        // |> Given an extent
        e = BGExtent(builder: b)
        
        // |> When added outside an event
        // |> Then there is an error
        TestAssertionHit {
            e.addToGraph()
        }
    }
    
    
    class MyExtent: BGExtent {
        let r1: BGMoment
        
        init(graph: BGGraph) {
            let b = BGExtentBuilder<MyExtent>(graph: graph)
            r1 = b.moment()
            super.init(builder: b)
        }
    }
    
    func testResourcePropertiesGetNames() {
        let e2 = MyExtent(graph: self.g)
        
        XCTAssertEqual(e2.r1.propertyName, "MyExtent.r1")
    }
    
}
