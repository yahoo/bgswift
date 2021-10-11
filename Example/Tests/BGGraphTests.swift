//
//  Copyright © 2021 Yahoo
//    

import XCTest
import BGSwift

class BGGraphTests: XCTestCase {

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

    func testDependencyCyclesCaught() {
        // |> Given a graph with dependency cycles
        b.behavior(supplies: [rA], demands: [rB]) { extent in
            // nothing
        }
        b.behavior(supplies: [rB], demands: [rA]) { extent in
            // nothing
        }
        e = BGExtent(builder: b)
        
        // |> When it is added to the graph
        // |> Then it will raise an error
        TestAssertionHit {
            e.addToGraphWithAction()
        }
    }
    
    func testResourceCanOnlyBeSuppliedByOneBehavior() {
        // |> Given an extent with multiple behaviors that supply the same resource
        b.behavior(supplies: [rA], demands: [], body:{ extent in
            // nothing
        })
        b.behavior(supplies: [rA], demands: []) { extent in
            // nothing
        }
        e = BGExtent(builder: b)
        
        // |> When it is added
        // |> Then it will raise an error
        TestAssertionHit {
            e.addToGraphWithAction()
        }
    }

    func testCannotAddDemandNotPartOfGraph() {
        // |> Given a extent with a behavior that demands a resource not added to the graph
        let b2 = BGExtentBuilder(graph: g)
        b2.behavior(supplies: [], demands: [rA]) { extent in
            // nothing
        }
        let e2 = BGExtent(builder: b2)
        
        // |> When it is added to the graph
        // |> Then there should be an error
        TestAssertionHit {
            e2.addToGraphWithAction()
        }
    }

    func testLinksCanOnlyBeUpdatedDuringAnEvent() {
        // |> Given a behavior in a graph
        let bhv = b.behavior(supplies: [], demands: []) { extent in
            // nothing
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When updating demands outside of event
        // |> Then there is an error
        TestAssertionHit {
            bhv.setDemands([rA])
        }
        
        // |> And when updating supplies outside of event
        // |> Then there is an error
        TestAssertionHit {
            bhv.setSupplies([rB])
        }
    }
    
}
