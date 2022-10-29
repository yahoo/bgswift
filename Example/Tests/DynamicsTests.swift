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
        rA.debugName = "rA"
        
        rB = b.state(0)
        rB.debugName = "rB"
        
        rC = b.state(0)
        rC.debugName = "rC"
    }
    
    override func tearDown() {
    }
    
    func testBehaviorOrdersUpdateWhenDemandsAddedWithPreDynamic() throws {
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
        
        b.behavior().supplies([r_b]).demands([r_a]).runs { extent in
            update_b = sequence
            sequence += 1
            r_b.update()
        }
        
        b.behavior().supplies([r_c]).demands([r_b]).runs { extent in
            update_c = sequence
            sequence += 1
            r_c.update()
        }
        
        b.behavior()
            .supplies([r_x])
            .demands([r_a])
            .dynamicDemands(.init(.pre, demands: [r_a], { extent in
                if let value = r_a.updatedValue, value == true {
                    return [r_c]
                } else {
                    return []
                }
            })).runs { extent in
                update_x = sequence
                sequence += 1
                r_x.update()
            }
        
        b.behavior().supplies([r_y]).demands([r_x]).runs { extent in
            update_y = sequence
            sequence += 1
            r_y.update()
        }

        b.behavior().supplies([r_z]).demands([r_y]).runs { extent in
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
    
    func testBehaviorOrdersUpdateWhenSuppliesAddedWithPreDynamic() throws {

        let r_a = b.moment()
        let r_b = b.moment()

        var sequence = 0
        var update_b1 = 0
        var update_b2 = 0

        let b1 = b.behavior()
            .demands([r_a])
            .dynamicSupplies(.init(.pre, demands: [r_a]) { extent in
                return [r_b]
            }).runs { extent in
                r_b.update()
                update_b1 = sequence
                sequence += 1
            }
        
        let b2 = b.behavior().demands([r_b]).runs { extent in
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

    func testPreDynamicDemands() {
        let r_a: BGState<Int> = b.state(0)
        let r_b: BGState<Int> = b.state(0)

        let demand: BGState<BGState<Int>?> = b.state(nil)

        let runCount: BGState<Int> = b.state(0)
        let result: BGState<Int?> = b.state(nil)
        b.behavior()
            .supplies([result, runCount])
            .demands([demand])
            .dynamicDemands(.init(.pre, demands: [demand]) { extent in
                if let demand = demand.value {
                    return [demand]
                } else {
                    return []
                }
            }).runs { extent in
                runCount.update(runCount.value + 1)
                result.update(demand.value?.value)
            }

        e = BGExtent(builder: b)

        e.addToGraphWithAction()
        XCTAssertEqual(runCount.value, 0)
        XCTAssertNil(result.value)

        // When dynamic demand is set to r_a
        g.action {
            demand.update(r_a)
            r_a.update(1)
            r_b.update(-1)
        }

        // Then the result should be r_a's value
        XCTAssertEqual(runCount.value, 1)
        XCTAssertEqual(result.value, 1)

        // And should run update when r_a updates
        r_a.updateWithAction(2)
        XCTAssertEqual(runCount.value, 2)
        XCTAssertEqual(result.value, 2)

        // And should not run or update when r_b updates
        r_b.updateWithAction(-2)
        XCTAssertEqual(runCount.value, 2)
        XCTAssertEqual(result.value, 2)

        // When dynamic demand is set to r_b
        g.action {
            demand.update(r_b)
            r_a.update(1)
            r_b.update(-1)
        }

        // Then the result should be r_b's value
        XCTAssertEqual(runCount.value, 3)
        XCTAssertEqual(result.value, -1)

        // And should not run update when r_a updates
        r_a.updateWithAction(2)
        XCTAssertEqual(runCount.value, 3)
        XCTAssertEqual(result.value, -1)

        // And should run or update when r_b updates
        r_b.updateWithAction(-2)
        XCTAssertEqual(runCount.value, 4)
        XCTAssertEqual(result.value, -2)
    }

    func testPostDynamicDemands() {
        let r_a: BGState<Int> = b.state(0)
        let r_b: BGState<Int> = b.state(0)

        let demand: BGState<BGState<Int>?> = b.state(nil)

        let runCount: BGState<Int> = b.state(0)
        let result: BGState<Int?> = b.state(nil)
        b.behavior()
            .supplies([result, runCount])
            .dynamicDemands(.init(.post, demands: [demand]) { extent in
                if let demand = demand.value {
                    return [demand]
                } else {
                    return []
                }
            }).runs { extent in
                runCount.update(runCount.value + 1)
                result.update(demand.traceValue?.value)
            }

        e = BGExtent(builder: b)

        e.addToGraphWithAction()
        XCTAssertEqual(runCount.value, 0)
        XCTAssertNil(result.value)

        // When dynamic demand is set to r_a
        g.action {
            demand.update(r_a)
            r_a.update(1)
            r_b.update(-1)
        }

        // Then the result should remain the same
        XCTAssertEqual(runCount.value, 1)
        XCTAssertEqual(result.value, nil)

        // And should run update when r_a updates
        r_a.updateWithAction(2)
        XCTAssertEqual(runCount.value, 2)
        XCTAssertEqual(result.value, 2)

        // And should not run or update when r_b updates
        r_b.updateWithAction(-2)
        XCTAssertEqual(runCount.value, 2)
        XCTAssertEqual(result.value, 2)

        // When dynamic demand is set to r_b
        g.action {
            demand.update(r_b)
            r_a.update(1)
            r_b.update(-1)
        }

        // Then the result should r_a's value
        XCTAssertEqual(runCount.value, 3)
        XCTAssertEqual(result.value, 1)

        // And should not run update when r_a updates
        r_a.updateWithAction(2)
        XCTAssertEqual(runCount.value, 3)
        XCTAssertEqual(result.value, 1)

        // And should run or update when r_b updates
        r_b.updateWithAction(-2)
        XCTAssertEqual(runCount.value, 4)
        XCTAssertEqual(result.value, -2)
    }

    func testPreDynamicDemandsWithChildExtents() {
        class ChildExtent: BGExtent {
            let state: BGState<Int>

            init(graph: BGGraph, state: Int) {
                let b = BGExtentBuilder(graph: graph)
                self.state = b.state(state)
                super.init(builder: b)
            }
        }

        let child1 = ChildExtent(graph: g, state: 1)
        let child2 = ChildExtent(graph: g, state: -1)

        let currentChild: BGState<ChildExtent?> = b.state(nil)
        let currentState: BGState<Int?> = b.state(nil)
        let runCount: BGState<Int> = b.state(0)

        b.behavior()
            .supplies([currentState, runCount])
            .demands([currentChild])
            .dynamicDemands(.init(.pre, demands: [currentChild]) { extent in
                [currentChild.value?.state]
            }).runs { extent in
                runCount.update(runCount.value + 1)
                currentState.update(currentChild.value?.state.value)
            }

        e = BGExtent(builder: b)

        g.action {
            self.e.addToGraph()
            child1.addToGraph()
            child2.addToGraph()
        }
        XCTAssertEqual(runCount.value, 0)

        currentChild.updateWithAction(child1)
        XCTAssertEqual(runCount.value, 1)
        XCTAssertEqual(currentState.value, 1)

        child1.state.updateWithAction(2)
        XCTAssertEqual(runCount.value, 2)
        XCTAssertEqual(currentState.value, 2)

        child2.state.updateWithAction(-2)
        XCTAssertEqual(runCount.value, 2)
        XCTAssertEqual(currentState.value, 2)

        g.action {
            currentChild.update(child2)
            child1.state.update(1)
            child2.state.update(-1)
        }
        XCTAssertEqual(runCount.value, 3)
        XCTAssertEqual(currentState.value, -1)

        child1.state.updateWithAction(2)
        XCTAssertEqual(runCount.value, 3)
        XCTAssertEqual(currentState.value, -1)

        child2.state.updateWithAction(-2)
        XCTAssertEqual(runCount.value, 4)
        XCTAssertEqual(currentState.value, -2)
    }

    func testPostDynamicDemandsWithChildExtents() {
        class ChildExtent: BGExtent {
            let done: BGMoment
            let generation: Int

            init(graph: BGGraph, generation: Int) {
                let b = BGExtentBuilder(graph: graph)
                done = b.moment()
                self.generation = generation
                super.init(builder: b)
            }
        }

        let childExtent: BGState<ChildExtent?> = b.state(nil)
        childExtent.debugName = "childExtent"
        
        let cycleChildExtent = b.moment()
        cycleChildExtent.debugName = "cycleChildExtent"

        b.behavior()
            .supplies([childExtent])
            .demands([cycleChildExtent])
            .dynamicDemands(.init(.post, demands: [childExtent]) { extent in
                if let childExtent = childExtent.value {
                    return [childExtent.done]
                } else {
                    return []
                }
            }).runs { extent in
                if cycleChildExtent.justUpdated() || childExtent.value?.done.justUpdated() == true {
                    let newChildExtent = ChildExtent(graph: extent.graph, generation: (childExtent.value?.generation ?? 0) + 1)
                    newChildExtent.addToGraph()
                    childExtent.update(newChildExtent)
                }
            }

        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        cycleChildExtent.updateWithAction()
        let extentGen1 = childExtent.value!
        XCTAssertEqual(extentGen1.generation, 1)

        extentGen1.done.updateWithAction()
        let extentGen2 = childExtent.value!
        XCTAssertEqual(extentGen2.generation, 2)

        // Previous child extent's resource is no longer a demand
        extentGen1.done.updateWithAction()
        XCTAssertIdentical(childExtent.value, extentGen2)

        extentGen2.done.updateWithAction()
        XCTAssertEqual(childExtent.value!.generation, 3)
    }

    func testCanAddAndUpdateSameEvent() {
        // |> Given a new extent
        let rX: BGState<Int> = b.state(0)
        b.behavior()
            .supplies([rX])
            .demands([rA])
            .runs { extent in
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
        b2.behavior().supplies([rC]).demands([rB]).runs { extent in
            self.rC.update(self.rB.value + 1)
        }
        let e2 = BGExtent(builder: b2)

        b.behavior().demands([rA]).runs { extent in
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
        let x_bhv = b.behavior().supplies([x_out]).demands([rA, reordering]).runs { extent in
            whenX = counter
            counter = counter + 1
        }
        let y_out: BGState<Int> = b.state(0)
        let y_bhv = b.behavior().supplies([y_out]).demands([rA, reordering]).runs { extent in
            whenY = counter
            counter = counter + 1
        }
        y_bhv.setDynamicDemands([x_out])

        // this behavior makes y come before x
        b.behavior().supplies([reordering]).demands([rA]).runs { extent in
            if self.rA.justUpdated() {
                x_bhv.setDynamicDemands([y_out])
                y_bhv.setDynamicDemands([])
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
        b.behavior().supplies([rZ]).demands([rY]).runs { extent in
            rZ.update(rY.value)
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When a new extent is added that supplies that resource
        let b2 = BGExtentBuilder(graph: g)
        let rX = b2.state(0)
        b2.behavior().supplies([rY]).demands([rX]).runs { extent in
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
        let bhv1 = b.behavior().runs { extent in
            run = true
        }
        b.behavior().demands([rA]).runs { extent in
            bhv1.setDynamicDemands([self.rA])
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
        b.behavior().supplies([rY]).demands([rA, rX]).runs { extent in
            if rX.justUpdated() {
                rY.update(self.rA.value)
            }
        }
        // this behavior will get its supplies added
        let bhv2 = b.behavior().demands([rA]).runs { extent in
            rX.update(self.rA.value)
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When they are activated by one resource and change supplies
        g.action {
            self.rA.update(3)
            bhv2.setDynamicSupplies([rX])
        }

        // |> Then they should be ordered correctly
        XCTAssertEqual(rY.value, 3)
    }

    func testChangingSuppliesWillUnsupplyOldDynamicResources() {
        // |> Given we supply a resource
        let rX = b.moment()
        let bhv1 = b.behavior().runs { extent in
            // no op
        }
        bhv1.setDynamicSupplies([rX])
        
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        XCTAssertTrue(rX.supplier === bhv1)

        // |> When that behavior no longer supplies the resource
        g.action {
            bhv1.setDynamicSupplies([])
        }

        // |> Then that resource should be free to be supplied by another behavior
        XCTAssertNil(rX.supplier)
    }

    func testChangingDemandsWillUnsupplyOldDemands() {
        // |> Given we have demands
        let rX = b.moment()
        var run = false
        let bhv1 = b.behavior().runs { extent in
            run = true
        }
        bhv1.setDynamicDemands([rX])
        
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When that behavior no longer supplies the resource
        g.action {
            bhv1.setDynamicDemands([])
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
            b2.behavior().demands([self.rA]).runs { extent in
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
        let bhv1 = b.behavior().runs { extent in
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
                bhv1.setDynamicDemands([rX])
                bhv1.setDynamicSupplies([rY])
            }
            XCTAssertEqual(bhv1.demands.count, 1)
            XCTAssertEqual(bhv1.supplies.count, 1)
            // rX and e2 are deallocated and removed when it exits scope
        }

        // |> When those resources are removed
        // |> Then the remaining behavior should have them removed as links
        XCTAssertEqual(bhv1.demands.compactMap({ $0.resource}).count, 0)
        XCTAssertEqual(bhv1.supplies.compactMap({ $0.resource }).count, 0)
    }

    func testRemovedBehaviorsUnlinkFromForeignResources() {
        // |> Given resources that will be linked to a foreign behavior
        let rX = b.moment()
        let rY = b.moment()
        e = BGExtent(builder: b)
        e.addToGraphWithAction()
        autoreleasepool {
            let b2 = BGExtentBuilder(graph: self.g)
            b2.behavior().supplies([rY]).demands([rX]).runs { extent in
                // nothing
            }
            let e2 = BGExtent(builder: b2)
            e2.addToGraphWithAction()
            XCTAssertEqual(rX.subsequents.count, 1)
            XCTAssertTrue(rY.supplier != nil)
            // behavior is removed and dealloced
        }

        XCTAssertEqual(rX.subsequents.filter({ $0.behavior != nil }).count, 0)
        XCTAssertTrue(rY.supplier == nil)
    }

    func testSetDemandsTwiceWorks() {
        // |> Given a behavior with no demands
        var run = false
        let bhv = b.behavior().runs { extent in
            run = true
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When that behavior gets its demands updated twice in same event
        g.action {
            bhv.setDynamicDemands([self.rA])
            bhv.setDynamicDemands([self.rB])
        }

        // |> Then the most recent update should hold
        rA.updateWithAction(1)
        XCTAssertFalse(run)
        rB.updateWithAction(1)
        XCTAssertTrue(run)
    }

    func testSetSuppliesTwiceWorks() {
        // |> Given a behavior with no supplies
        let bhv = b.behavior().demands([rA]).runs { extent in
            self.rB.update(1)
        }
        e = BGExtent(builder: b)
        e.addToGraphWithAction()

        // |> When that behavior gets its supplies updated twice in same event
        g.action {
            bhv.setDynamicSupplies([self.rA])
            bhv.setDynamicSupplies([self.rB])
        }

        // |> Then the most recent update should hold
        let failed = CheckAssertionHit {
            rA.updateWithAction(1)
        }
        XCTAssertFalse(failed)
    }

    func testDynamicsClosureFiltersNilResources() {
        let r_a: BGState<Int> = b.state(0)
        let r_b: BGState<Int> = b.state(0)
        let r_c: BGState<Int> = b.state(0)
        let r_d: BGState<Int> = b.state(0)

        let bhv = b.behavior()
            .dynamicSupplies(.init(.pre, demands: [b.added]) { _ in
                [r_a, nil, r_b, nil]
            }).dynamicDemands(.init(.post, demands: [b.added]) { _ in
                [nil, r_c, nil, r_d]
            }).runs { _ in
                // do nothing
            }

        let extent = BGExtent(builder: b)
        extent.addToGraphWithAction()
        XCTAssertTrue(bhv.supplies.contains(r_a.weakReference))
        XCTAssertTrue(bhv.supplies.contains(r_b.weakReference))
        XCTAssertTrue(bhv.demands.contains(BGDemandLink(resource: r_c, type: .reactive)))
        XCTAssertTrue(bhv.demands.contains(BGDemandLink(resource: r_d, type: .reactive)))
    }
    
    func testNestedDynamicDemands() {
        class LeafExtent: BGExtent {
            let leafValue: BGState<Int>
            
            init(graph: BGGraph) {
                let b = BGExtentBuilder<LeafExtent>(graph: graph)
                leafValue = b.state(0)
                super.init(builder: b)
            }
        }
        
        class BranchExtent: BGExtent {
            let leaves: BGState<[LeafExtent]>
            
            init(graph: BGGraph) {
                let b = BGExtentBuilder<BranchExtent>(graph: graph)
                leaves = b.state([])
                super.init(builder: b)
            }
        }
        
        class RootExtent: BGExtent {
            let branches: BGState<[BranchExtent]>
            let totalValue: BGState<Int>
            
            init(graph: BGGraph) {
                let b = BGExtentBuilder<RootExtent>(graph: graph)
                
                branches = b.state([])
                totalValue = b.state(0)
                
                b.behavior()
                    .supplies([totalValue])
                    .demands([branches])
                    .dynamicDemands(.init(.pre, demands: [branches], { extent in
                        var demands = [BGDemandable]()
                        extent.branches.value.forEach {
                            demands.append($0.leaves)
                            $0.leaves.value.forEach {
                                demands.append($0.leafValue)
                            }
                        }
                        return demands
                    }).withDynamicDemands(.init(.pre, demands: [branches], { extent in
                        extent.branches.value.map({ $0.leaves })
                    })))
                    .runs { extent in
                        extent.totalValue.update(extent.branches.value.reduce(0) { partialResult, branch in
                            branch.leaves.value.reduce(partialResult) { partialResult, leaf in
                                partialResult + leaf.leafValue.value
                            }
                        })
                    }
                
                super.init(builder: b)
            }
        }
        
        let rootExtent = RootExtent(graph: g)
        g.action {
            rootExtent.addToGraph()
            
            let branches = [[1, 2, 3], [4, 5, 6], [7, 8, 9]].map { leafValues in
                let branch = BranchExtent(graph: self.g)
                branch.addToGraph()
                
                let leaves = leafValues.map { value in
                    let leaf = LeafExtent(graph: self.g)
                    leaf.addToGraph()
                    leaf.leafValue.update(value)
                    return leaf
                }
                branch.leaves.update(leaves)
                return branch
            }
            
            rootExtent.branches.update(branches)
        }
        
        XCTAssertEqual(rootExtent.totalValue.value, (1...9).reduce(0, { $0 + $1 }))
    }
}
