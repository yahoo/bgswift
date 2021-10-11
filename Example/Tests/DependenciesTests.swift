//
//  Copyright © 2021 Yahoo
//


import Foundation
import Quick
import Nimble
@testable import BGSwift

class DependenciesTest : QuickSpec {
    override func spec() {
        
        var g: BGGraph!
        var r_a, r_b, r_c: BGState<Int>!
        var bld: BGExtentBuilder<BGExtent>!
        var ext: BGExtent!

        beforeEach {
            g = BGGraph()
            bld = BGExtentBuilder(graph: g)
            r_a = bld.state(0)
            r_b = bld.state(0)
            r_c = bld.state(0)
        }
        
        it("a activates b") {
            // |> Given a behavior with supplies and demands
            bld.behavior(supplies: [r_b], demands: [r_a]) { extent in
                r_b.update(2 * r_a.value)
            }
            ext = BGExtent(builder: bld)
            ext.addToGraphWithAction();

            // |> When the demand is updated
            r_a.updateWithAction(1)

            // |> Then the demanding behavior will run and update its supplied resource
            expect(r_b.value).to(equal(2))
            expect(r_b.event).to(equal(r_a.event))
        }
        
        it("activates behaviors once per event") {
            // |> Given a behavior that demands multiple resources
            var called = 0
            bld.behavior(supplies: [r_c], demands: [r_a, r_b]) { extent in
                called += 1
            }
            ext = BGExtent(builder: bld)
            ext.addToGraphWithAction()
            
            // |> When both resources are updated in same event
            g.action {
                r_a.update(1)
                r_b.update(2)
            }
            
            // |> Then the demanding behavior is activated only once
            expect(called) == 1
        }

        xit("filters out duplicates") {
            /*
            let b1 = bld.behavior(supplies: [r_b, r_b], demands: [r_a, r_a]) { extent in
                
            }
            ext = BGExtent(builder: bld)
            ext.addToGraphWithAction()

            expect(b1.demands!.size) == 1
            expect(b1.supplies!.size) == 1
            expect(r_a.subsequents!.size) == 1
            */
        }
        
    }
}
