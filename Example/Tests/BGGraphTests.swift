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
        b.behavior().supplies([rA]).demands([rB]).runs { extent in
            // nothing
        }
        b.behavior().supplies([rB]).demands([rA]).runs { extent in
            // nothing
        }
        e = BGExtent(builder: b)
        
        // |> When it is added to the graph
        // |> Then it will raise an error
        TestAssertionHit(graph: g) {
            e.addToGraphWithAction()
        }
    }
    
    func testResourceCanOnlyBeSuppliedByOneBehavior() {
        // |> Given an a resource that is supplied by a behavior
        b.behavior().supplies([rA]).runs { extent in
            // nothing
        }
        
        // |> When a behavior sets a static supply that is already supplied by another behavior
        // |> Then it will raise an error
        TestAssertionHit(graph: g) {
            b.behavior().supplies([rA]).runs { extent in
                // nothing
            }
        }
        
        let bhv = b.behavior().runs { extent in
            // nothing
        }
        
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When a behavior sets a dynamic supply that is already supplied by another behavior
        // |> Then it will raise an error
        TestAssertionHit(graph: g) {
            g.action {
                bhv.setDynamicSupplies([self.rA])
            }
        }
    }

    func testLinksCanOnlyBeUpdatedDuringAnEvent() {
        // |> Given a behavior in a graph
        let bhv = b.behavior().runs { extent in
            // nothing
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When updating demands outside of event
        // |> Then there is an error
        TestAssertionHit(graph: g) {
            bhv.setDynamicDemands([rA])
        }
        
        // |> And when updating supplies outside of event
        // |> Then there is an error
        TestAssertionHit(graph: g) {
            bhv.setDynamicSupplies([rB])
        }
    }
    
}
