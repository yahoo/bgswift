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
        b.behavior().demands([b.added]).runs { extent in
            run = true
        }
        b.behavior().demands([b.added]).runs { extent in
            run = true
        }
        b.behavior().runs { extent in
            nonAddedRun = true
        }
        e = BGExtent(builder: b)
        
        // |> When it is added
        e.addToGraphWithAction()
        
        // |> The added resource is updated
        XCTAssertTrue(run)
        XCTAssertFalse(nonAddedRun)
    }

    func testCanGetResourcesAndBehaviors() {
        b.behavior().runs { _ in }
        b.behavior().runs { _ in }
        e = BGExtent(builder: b)
        
        // |> When it is added
        e.addToGraphWithAction()
        
        // |> Then we can get the resources and behaviors
        XCTAssertEqual(4, e.allResources.count) // _added is a resource also
        XCTAssertEqual(2, e.allBehaviors.count)
    }
    
    func testCheckCannotAddExtentToGraphMultipleTimes() {
        // NOTE: This is primarily to prevent user error.
        // Perhaps it makes sense to remove/add extents in the future.
        
        // |> Given an extent added to a graph
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When it is added again
        // |> Then there is an error
        TestAssertionHit(graph: g) {
            e.addToGraphWithAction()
        }
    }

    func testCheckExtentCanOnlyBeAddedDuringEvent() {
        // |> Given an extent
        e = BGExtent(builder: b)
        
        // |> When added outside an event
        // |> Then there is an error
        TestAssertionHit(graph: g) {
            e.addToGraph()
        }
    }
    
    func testCheckExtentCanOnlyBeRemovedDuringEvent() {
        // |> Given an extent
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When added outside an event
        // |> Then there is an error
        TestAssertionHit(graph: g) {
            e.removeFromGraph()
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
        
        XCTAssertEqual(e2.r1.debugName, "MyExtent.r1")
    }
    
    func testCanTrackWhenExtentsAreAdded() {
        // |> Given a graph with debugOnExtentAdded defined
        var addedExtents: [BGExtent] = []
        var addedResources: [any BGResource] = []
        g.debugOnExtentAdded = {
            addedExtents.append($0)
            addedResources.append(contentsOf: $0.allResources)
        }
        
        // |> When an extent is added
        let b1 = BGExtentBuilder<BGExtent>(graph: g)
        let _ = b1.moment()
        let e1 = BGExtent(builder: b1)
        
        e1.addToGraphWithAction()
        
        // |> Then callback is called
        XCTAssertEqual(e1, addedExtents[0])
        XCTAssertEqual(1, addedExtents.count)
        XCTAssertEqual(2, addedResources.count) // _added is a default resource
        
        // |> And when callback is undefined
        g.debugOnExtentAdded = nil
        
        // and another extent is added
        let b2 = BGExtentBuilder<BGExtent>(graph: g)
        let _ = b2.moment()
        let e2 = BGExtent(builder: b2)
        
        e2.addToGraphWithAction()
        
        // |> Then callback is not called
        XCTAssertEqual(1, addedExtents.count)
        XCTAssertEqual(2, addedResources.count)
    }
    
}
