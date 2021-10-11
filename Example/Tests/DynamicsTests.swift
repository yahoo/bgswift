//
//  Copyright © 2021 Yahoo
//    

import XCTest
@testable import BGSwift
//import BGSwift


class DynamicsTests: XCTestCase {
    
    var g: BGGraph!
    var b: BGExtentBuilder<BGExtent>!
    var e: BGExtent!
    var rA: BGState<Int>!
    var rB: BGState<Int>!
    var rC: BGState<Int>!
    
    override func setUp() {
        g = BGGraph()
        b = BGExtentBuilder(graph: g)
        rA = b.state(0)
        rB = b.state(0)
        rC = b.state(0)
    }
    
    override func tearDown() {
    }

    func testBehaviorOrdersUpdateWhenDemandsAdded() throws {
        enum BehaviorOrder {
            case abc
            case acb
        }
        
        let b = BGExtentBuilder(graph: g)
        
        let r_a: BGTypedMoment<Bool> = b.typedMoment()
        let r_b = b.moment()
        let r_c = b.moment()
        
        let r_x = b.moment()
        let r_y = b.moment()
        let r_z = b.moment()
        
        var sequence = 0
        var update_b = 0
        var update_c = 0
        var update_x = 0
        var update_y = 0
        var update_z = 0
        
        b.behavior(supplies: [r_b], demands: [r_a]) { extent in
            update_b = sequence
            sequence += 1
            r_b.update()
        }
        
        b.behavior(supplies: [r_c], demands: [r_b]) { extent in
            update_c = sequence
            sequence += 1
            r_c.update()
        }
        
        b.behavior(supplies: [r_x], demands: [r_a],
                   dynamicDemands: .init(switches: [r_a], { extent in
                    if let value = r_a.value, value == true {
                        return [r_c]
                    } else {
                        return []
                    }
                   })) { extent in
            update_x = sequence
            sequence += 1
            r_x.update()
        }
        
        b.behavior(supplies: [r_y], demands: [r_x]) { extent in
            update_y = sequence
            sequence += 1
            r_y.update()
        }
        
        b.behavior(supplies: [r_z], demands: [r_y]) { extent in
            update_z = sequence
            sequence += 1
            r_z.update()
        }
        
        e = BGExtent(builder: b)
        
        g.action {
            self.e.addToGraph()
            r_a.update(false)
        }
        
        XCTAssertLessThan(update_b, update_c)
        XCTAssertLessThan(update_x, update_c)
        XCTAssertLessThan(update_x, update_y)
        XCTAssertLessThan(update_y, update_z)
        
        sequence = 0
        r_a.updateWithAction(true)
        XCTAssertLessThan(update_b, update_c)
        XCTAssertGreaterThan(update_x, update_c)
        XCTAssertLessThan(update_x, update_y)
        XCTAssertLessThan(update_y, update_z)
    }
    
    func testBehaviorOrdersUpdateWhenSuppliesAdded() throws {
        
        let r_a = b.moment()
        let r_b = b.moment()
        
        var sequence = 0
        var update_b1 = 0
        var update_b2 = 0
        
        let b1 = b.behavior(demands: [r_a],
                            dynamicSupplies: .init(switches: [r_a], { extent in
                                return [r_b]
                            })) { extent in
            r_b.update()
            update_b1 = sequence
            sequence += 1
        }
        
        let b2 = b.behavior(demands: [r_b]) { extent in
            update_b2 = sequence
            sequence += 1
        }
        
        e = BGExtent(builder: b)
        
        e.addToGraphWithAction()
        XCTAssertGreaterThanOrEqual(b1.order, b2.order)
        
        sequence = 0
        r_a.updateWithAction()
        XCTAssertLessThan(update_b1, update_b2)
        XCTAssertLessThan(b1.order, b2.order)
    }
    
    
    func testCanAddAndUpdateSameEvent() {
        // |> Given a new extent
        let rX: BGState<Int> = b.state(0)
        b.behavior(supplies: [rX], demands: [rA]) { extent in
            if self.rA.justUpdated() {
                rX.update(self.rA.value * 2)
            }
        }
        e = BGExtent(builder: b)
        
        // |> When it is added to graph in same event as one of its resources is updated
        // but technically updated before added
        g.action {
            self.rA.update(2)
            self.e.addToGraph()
        }
        
        // |> Then that updating should still activate the concerned behavior
        XCTAssertEqual(rX.value, 4)
    }
    
    func testCanAddExtentInsideBehavior() {
        // |> Given a behavior that adds a new extent when something happens
        let b2 = BGExtentBuilder(graph: g)
        b2.behavior(supplies: [rC], demands: [rB]) { extent in
            self.rC.update(self.rB.value + 1)
        }
        let e2 = BGExtent(builder: b2)

        b.behavior(supplies: [], demands: [rA]) { extent in
            if (self.rA.justUpdated()) {
                e2.addToGraph()
            }
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When updating resource before adding extent with demanding behavior
        g.action {
            self.rB.update(1)
        }
        
        // |> Then demanding behavior isn't run
        XCTAssertEqual(rC.value, 0)

        // |> And when behavior that adds the extent also gets run in same action
        g.action {
            self.rB.update(2)
            self.rA.update(1)
        }
        
        // |> Then new extent is added and demanding behavior activated, and supplied resource is updated
        XCTAssertEqual(rC.value, 3)
    }

    func testActivatedBehaviorsCanReorder() {
        var counter = 0;
        var whenX = 0;
        var whenY = 0;
        
        // |> Given two behaviors where x comes before y
        let reordering = b.moment()
        let x_out: BGState<Int> = b.state(0)
        let x_bhv = b.behavior(supplies: [x_out], demands: [rA, reordering]) { extent in
            whenX = counter
            counter = counter + 1
        }
        let y_out: BGState<Int> = b.state(0)
        let y_bhv = b.behavior(supplies: [y_out], demands: [rA, reordering, x_out]) { extent in
            whenY = counter
            counter = counter + 1
        }
        
        // this behavior makes y come before x
        b.behavior(supplies: [reordering], demands: [rA]) { extent in
            if self.rA.justUpdated() {
                x_bhv.setDemands([self.rA, reordering, y_out])
                y_bhv.setDemands([self.rA, reordering])
            }
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When event that activates both behaviors and the reordering behavior runs
        rA.updateWithAction(2);

        // |> Then Y should get run before X
        XCTAssertEqual(whenX, whenY + 1)
    }

    func testSupplyingResourceAfterSubsequentHasBeenAdded() {
        // NOTE: This test ensures that just adding a supplier is enough to force
        // a resorting.
        
        // |> Given a behavior that demands an unsupplied resource has been added
        let rZ = b.state(0)
        let rY = b.state(0)
        b.behavior(supplies: [rZ], demands: [rY]) { extent in
            rZ.update(rY.value)
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When a new extent is added that supplies that resource
        let b2 = BGExtentBuilder(graph: g)
        let rX = b2.state(0)
        b2.behavior(supplies: [rY], demands: [rX]) { extent in
            rY.update(rX.value)
        }
        let e2 = BGExtent(builder: b2)
        e2.addToGraphWithAction()
        
        // |> Then the original behavior should get sorted correctly on just a supplier change
        rX.updateWithAction(1)
        XCTAssertEqual(rZ.value, 1)
    }
    
    func testChangingBehaviorToDemandAlreadyUpdatedResourceShouldRunBehavior() {
        // |> Given we have a behavior that doesn't demand r_a
        var run = false
        let bhv1 = b.behavior(supplies: [], demands: []) { extent in
            run = true
        }
        b.behavior(supplies: [], demands: [rA]) { extent in
            bhv1.setDemands([self.rA])
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When we update the behavior to demand r_a in the same event that r_a has already run
        rA.updateWithAction(1)
        
        // |> Then our behavior will activate
        XCTAssertTrue(run)
    }

    func testUpdatingSuppliesWillReorderActivatedBehaviors() {
        // NOTE: This tests that activated behaviors will get properly
        // reordered when their supplies change
        
        // |> Given two unorderd behaviors
        let rY = b.state(0)
        let rX = b.state(0)
        b.behavior(supplies: [rY], demands: [rA, rX]) { extent in
            if rX.justUpdated() {
                rY.update(self.rA.value)
            }
        }
        // this behavior will get its supplies added
        let bhv2 = b.behavior(supplies: [], demands: [rA]) { extent in
            rX.update(self.rA.value)
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
    
        // |> When they are activated by one resource and change supplies
        g.action {
            self.rA.update(3)
            bhv2.setSupplies([rX])
        }
        
        // |> Then they should be ordered correctly
        XCTAssertEqual(rY.value, 3)
    }
    
    func testChangingSuppliesWillUnsupplyOldResources() {
        // |> Given we supply a resource
        let rX = b.moment()
        let bhv1 = b.behavior(supplies: [rX], demands: []) { extent in
            // no op
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        XCTAssertTrue(rX.supplier === bhv1)
        
        // |> When that behavior no longer supplies the resource
        g.action {
            bhv1.setSupplies([])
        }
        
        // |> Then that resource should be free to be supplied by another behavior
        XCTAssertNil(rX.supplier)
    }

    func testChangingDemandsWillUnsupplyOldDemands() {
        // |> Given we have demands
        let rX = b.moment()
        var run = false
        let bhv1 = b.behavior(supplies: [], demands: [rX]) { extent in
            run = true
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When that behavior no longer supplies the resource
        g.action {
            bhv1.setDemands([])
        }
        rX.updateWithAction()
        
        // |> Then that resource should be free to be supplied by another behavior
        XCTAssertFalse(run)
    }

    func testRemovedBehaviorsDontRun() {
        // |> Given a foreign demand which gets removed
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        var run = false
        autoreleasepool {
            // add new foreign demand
            let b2 = BGExtentBuilder(graph: g)
            b2.behavior(supplies: [], demands: [self.rA]) { extent in
                run = true
            }
            let e2 = BGExtent(builder: b2)
            e2.addToGraphWithAction()
            // leaving scope here will deinit and remove extent from graph
        }

        // |> When previously demanded resource is updated
        rA.updateWithAction(1)
        
        // |> Then removed demanding behavior is not run
        XCTAssertFalse(run)
    }

    func testRemovedResourcesAreRemovedFromForeignLinks() {
        // |> Given we have a behavior that will link to foreign resources
        let bhv1 = b.behavior(supplies: [], demands: []) { extent in
            // nothing
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        autoreleasepool {
            let b2 = BGExtentBuilder(graph: self.g)
            let rX = b2.moment()
            let rY = b2.moment()
            let e2 = BGExtent(builder: b2)
            self.g.action {
                e2.addToGraph()
                bhv1.setDemands([rX])
                bhv1.setSupplies([rY])
            }
            XCTAssertEqual(bhv1.demands.count, 1)
            XCTAssertEqual(bhv1.supplies.count, 1)
            // rX and e2 are deallocated and removed when it exits scope
        }
        
        // |> When those resources are removed
        // |> Then the remaining behavior should have them removed as links
        XCTAssertEqual(bhv1.demands.count, 0)
        XCTAssertEqual(bhv1.supplies.count, 0)
    }
        
    func testRemovedBehaviorsUnlinkFromForeignResources() {
        // |> Given resources that will be linked to a foreign behavior
        let rX = b.moment()
        let rY = b.moment()
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        autoreleasepool {
            let b2 = BGExtentBuilder(graph: self.g)
            b2.behavior(supplies: [rY], demands: [rX]) { extent in
                // nothing
            }
            let e2 = BGExtent(builder: b2)
            e2.addToGraphWithAction()
            XCTAssertEqual(rX.subsequents.count, 1)
            XCTAssertTrue(rY.supplier != nil)
            // behavior is removed and dealloced
        }

        XCTAssertEqual(rX.subsequents.count, 0)
        XCTAssertTrue(rY.supplier == nil)
    }
    
    func testSetDemandsTwiceWorks() {
        // |> Given a behavior with no demands
        var run = false
        let bhv = b.behavior(supplies: [], demands: []) { extent in
            run = true
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When that behavior gets its demands updated twice in same event
        g.action {
            bhv.setDemands([self.rA])
            bhv.setDemands([self.rB])
        }
        
        // |> Then the most recent update should hold
        rA.updateWithAction(1)
        XCTAssertFalse(run)
        rB.updateWithAction(1)
        XCTAssertTrue(run)
    }
    
    func testSetSuppliesTwiceWorks() {
        // |> Given a behavior with no supplies
        let bhv = b.behavior(supplies: [], demands: [rA]) { extent in
            self.rB.update(1)
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        
        // |> When that behavior gets its supplies updated twice in same event
        g.action {
            bhv.setSupplies([self.rA])
            bhv.setSupplies([self.rB])
        }
        
        // |> Then the most recent update should hold
        let failed = CheckAssertionHit {
            rA.updateWithAction(1)
        }
        XCTAssertFalse(failed)
    }
}
