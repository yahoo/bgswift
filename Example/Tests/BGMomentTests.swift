//
//  Copyright © 2021 Yahoo
//    

import XCTest
import BGSwift

class BGMomentTests: XCTestCase {

    var g: BGGraph!
    var bld: BGExtentBuilder<BGExtent>!
    var ext: BGExtent!

    override func setUpWithError() throws {
        g = BGGraph()
        bld = BGExtentBuilder(graph: g)
    }

    override func tearDownWithError() throws {
    }

    func testMomentUpdates() throws {
        // |> Given a moment in the graph
        let mr1 = bld.moment()
        var afterUpdate = false;
        bld.behavior().demands([mr1]).runs { extent in
            if mr1.justUpdated() {
                afterUpdate = true
            }
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When it is read in the graph (and was not updated)
        var beforeUpdate = false
        var updateEvent: BGEvent? = nil
        g.action {
            beforeUpdate = mr1.justUpdated()
            mr1.update()
            updateEvent = self.g.currentEvent
        }

        // |> Then it didn't justUpdate before updating
        XCTAssertFalse(beforeUpdate)

        // |> And after
        // |> Then it did
        XCTAssertTrue(afterUpdate)

        // |> And outside an event
        // |> It is not just Updated
        XCTAssertFalse(mr1.justUpdated())

        // |> And event stays the same from when it last happened
        XCTAssertEqual(mr1.event, updateEvent)
    }
    
    func testTypedMomentsHaveInformation() {
        // Given a moment with data
        let mr1: BGTypedMoment<Int> = bld.typedMoment()
        var afterUpdate: Int? = nil
        bld.behavior().demands([mr1]).runs { extent in
            if mr1.justUpdated() {
                afterUpdate = mr1.updatedValue
            }
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When it happens
        mr1.updateWithAction(1)

        // |> Then the data is visible in subsequent behaviors
        XCTAssertEqual(afterUpdate, 1)
    }
    
    func testTypedMomentsAreTransient() {
        // NOTE this default prevents retaining data that no longer is needed
        
        class ClassType { }
        
        // |> Given a moment with data
        let mr1: BGTypedMoment<ClassType> = bld.typedMoment()
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When current event is over
        weak var weakValue: ClassType?
        autoreleasepool {
            let value = ClassType()
            weakValue = value
            mr1.updateWithAction(value)
        }

        // |> Then value nils out and is not retained
        XCTAssertNil(mr1.updatedValue)
        XCTAssertNil(weakValue)
    }
    
    func testNonSuppliedMomentsCanUpdateBeforeAdding() {
        // |> Given a moment
        let mr1 = bld.moment()
        var didRun = false;
        bld.behavior().demands([mr1]).runs { extent in
            if mr1.justUpdated() {
                didRun = true
            }
        }
        ext = BGExtent(builder: bld)
        
        // |> When it is updated in the same event as adding to graph
        g.action {
            mr1.update()
            self.ext.addToGraph()
        }

        // |> Then it runs and demanding behavior is run
        XCTAssertTrue(didRun)
    }

    func testCheckUpdatingMomentNotInGraphIsANullOp() {
        // NOTE: Extent can be deallocated and removed from graph while
        // some pending resource update may exist. Doing so should just
        // do nothing.
        
        // |> Given a moment resource not part of the graph
        let mr1 = bld.moment()
        
        // |> When it is updated
        var errorHappened = false
        g.action {
            errorHappened = CheckAssertionHit {
                mr1.update()
            }
        }
        
        // |> Then nothing happens
        XCTAssertFalse(errorHappened)
        XCTAssertEqual(mr1.event, BGEvent.unknownPast)
    }
    
    func testCheckMomentUpdatesOnlyHappenDuringEvent() {
        // |> Given a moment in the graph
        let mr1 = bld.moment()
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        // |> When updating outside of an event
        // |> Then it should fail
        TestAssertionHit {
            mr1.update()
        }
    }

    func testCheckMomentOnlyUpdatedBySupplier() {
        // |> Given a supplied moment
        let mr1 = bld.moment()
        let mr2 = bld.moment()
        bld.behavior().supplies([mr2]).demands([mr1]).runs { extent in
        }
        bld.behavior().demands([mr1]).runs { extent in
            if mr1.justUpdated() {
                mr2.update()
            }
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When it is updated by the wrong behavior
        // |> Then it should throw
        TestAssertionHit {
            self.g.action {
                mr1.update()
            }
        }
    }

    func testCheckUnsuppliedMomentOnlyUpdatedInAction() {
        // |> Given a supplied moment and unsupplied moment
        let mr1 = bld.moment()
        let mr2 = bld.moment()
        var updateFailed = false
        bld.behavior().demands([mr1]).runs { extent in
            updateFailed = CheckAssertionHit {
                mr2.update()
            }
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When the unsupplied moment is updated by a behavior
        g.action {
            mr1.update()
        }

        // |> Then it should throw
        XCTAssertTrue(updateFailed)
    }

    func testCheckSuppliedMomentCannotBeUpdatedInAction() {
        // |> Given a supplied moment
        let mr1 = bld.moment()
        bld.behavior().supplies([mr1]).demands([]).runs { extent in
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When we try updating that moment in an action
        var updateFailed = false
        self.g.action {
            updateFailed = CheckAssertionHit {
                mr1.update()
            }
        }
        
        // |> Then the updating chould throw
        XCTAssertTrue(updateFailed)
    }
}
