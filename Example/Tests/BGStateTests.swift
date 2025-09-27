//
//  Copyright © 2021 Yahoo
//    

import Foundation
import XCTest
@testable import BGSwift

class BGStateTests : XCTestCase {
    
    var g: BGGraph!
    var r_a, r_b: BGState<Int>!
    var bld: BGExtentBuilder<BGExtent>!
    var ext: BGExtent!

    override func setUp() {
        g = BGGraph()
        bld = BGExtentBuilder(graph: g)
        r_a = bld.state(0)
        r_b = bld.state(0)
    }

    func testHasInitialState() {
        // |> When we create a new state resource
        // |> It has an initial value
        XCTAssertEqual(r_a.value, 0)
    }

    func testUpdatesWhenAddedToGraph() {
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        // |> When it is updated
        r_a.updateWithAction(2)

        // |> Then it has new value and event
        XCTAssertEqual(r_a.value, 2)
        XCTAssertEqual(r_a.event, g.lastEvent)
    }
            
    func testCanHandleNullNilValues() {
        // Motivation: nullable states are useful for modeling false/true with data

        // |> Given a nullable state
        let r_n: BGState<Int?> = bld.state(nil)
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When updated
        r_n.updateWithAction(1)

        // |> Then it will have that new state
        XCTAssertEqual(r_n.value, 1)

        // |> And when updated to nil
        r_n.updateWithAction(nil)

        // |> Then it will have nil state
        XCTAssertNil(r_n.value)
    }

    func testWorksAsDemandAndSupply() {
        // |> Given state resources and behaviors
        var ran = false;
        bld.behavior().supplies([r_b]).demands([r_a]).runs { extent in
            self.r_b.update(self.r_a.value)
        }

        bld.behavior().demands([r_b]).runs { extent in
            ran = true
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()

        // |> When event is started
        r_a.updateWithAction(1)
        
        // |> Then subsequent behaviors are run
        XCTAssertEqual(r_b.value, 1)
        XCTAssertEqual(ran, true)
    }

    func testJustUpdatedChecksDuringEvent() {
        var updatedA = false
        var updatedB = false
        var updatedToA = false
        var updatedToWrongToA = false
        var updatedToB = false
        var updatedToFromA = false
        var updatedToFromWrongToA = false
        var updatedToFromWrongFromA = false
        var updatedToFromB = false
        var updatedFromA = false
        var updatedFromWrongFromA = false
        var updatedFromB = false
        
        // |> Given a behavior that tracks updated methods
        bld.behavior().demands([r_a, r_b]).runs { extent in
            updatedA = self.r_a.justUpdated()
            updatedB = self.r_b.justUpdated()
            updatedToA = self.r_a.justUpdated(to: 1)
            updatedToWrongToA = self.r_a.justUpdated(to: 2)
            updatedToB = self.r_b.justUpdated(to: 1)
            updatedToFromA = self.r_a.justUpdated(to: 1, from: 0)
            updatedToFromWrongToA = self.r_a.justUpdated(to: 2, from: 0)
            updatedToFromWrongFromA = self.r_a.justUpdated(to: 1, from: 2)
            updatedToFromB = self.r_b.justUpdated(to: 1, from: 0)
            updatedFromA = self.r_a.justUpdated(from: 0)
            updatedFromWrongFromA = self.r_a.justUpdated(from: 2)
            updatedFromB = self.r_b.justUpdated(from: 0)
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        // |> When r_a updates
        r_a.updateWithAction(1)
        
        // |> Then updates are tracked inside behavior
        XCTAssertEqual(updatedA, true)
        XCTAssertEqual(r_a.justUpdated(), false) // false outside event
        XCTAssertEqual(updatedB, false) // not updated
        XCTAssertEqual(updatedToA, true)
        XCTAssertEqual(r_a.justUpdated(to: 1), false)
        XCTAssertEqual(updatedToWrongToA, false)
        XCTAssertEqual(updatedToB, false)
        XCTAssertEqual(updatedToFromA, true)
        XCTAssertEqual(r_a.justUpdated(to: 1, from: 0), false)
        XCTAssertEqual(updatedToFromWrongToA, false)
        XCTAssertEqual(updatedToFromWrongFromA, false)
        XCTAssertEqual(updatedToFromB, false)
        XCTAssertEqual(updatedFromA, true)
        XCTAssertEqual(r_a.justUpdated(from: 0), false)
        XCTAssertEqual(updatedFromWrongFromA, false)
        XCTAssertEqual(updatedFromB, false)
    }
    
    func testCanAccessTraceValuesAndEvents() {
        var beforeValue: Int? = nil
        var beforeEvent: BGEvent? = nil
        
        // |> Given a behavior that accesses trace
        bld.behavior().demands([r_a]).runs { extent in
            beforeValue = self.r_a.traceValue
            beforeEvent = self.r_a.traceEvent
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        // |> When resource is updated
        r_a.updateWithAction(1)
        
        // |> Trace captures original state during
        XCTAssertEqual(beforeValue, 0)
        XCTAssertEqual(beforeEvent, BGEvent.unknownPast)
        // and current state outside event
        XCTAssertEqual(r_a.traceValue, 1)
        XCTAssertEqual(r_a.traceEvent, g.lastEvent)
    }
    
    func testCanUpdateResourceDuringSameEventAsAdding() {
        // @SAL this doesn't work yet, can't add and update in the same event
        var didRun = false
        bld.behavior().demands([r_a]).runs { extent in
            didRun = true
        }
        ext = BGExtent(builder: bld)
        
        self.g.action {
            self.r_a.update(1)
            self.ext.addToGraph()
        }
        
        XCTAssertEqual(r_a.value, 1)
        XCTAssertEqual(didRun, true)
    }

    // @SAL 8/16/2025 -- these quickspec tests werent running under xcodebuild, so this
    // wasn't failing. Moving to spm tests caused it to run and fail.
    // An ability to update a resource before extent is added to graph may be a desired
    // behavior, but it is not currently supported.
//            it("can update resource before extent is added to graph") {
//                //ext = BGExtent(builder: bld)
//
//                r_a.update(1)
//                
//                expect(ext.status) == .inactive
//                expect(r_a.value) == 1
//            }
    
    func testCanUpdateStateBeforeAdding() {
        // |> Given a state resource that hasn't been added
        let r = bld.state(0)
        ext = BGExtent(builder: bld)
        
        // |> When we update
        r.setInitialValue(1)
        // |> Then it's value is the new initial value
        XCTAssertEqual(r.value, 1)
        XCTAssertEqual(r._prevValue, 1)
    }
    
    func testCanUpdateStateBeforeBuildingExtent() {
        // |> Given a state resource that hasn't been added
        let r = bld.state(0)
        
        // |> When we update
        r.setInitialValue(1)
        // |> Then it's value is the new initial value
        XCTAssertEqual(r.value, 1)
        XCTAssertEqual(r._prevValue, 1)
    }
    
    func testCannotSetInitialValueAfterAdding() {
        // |> Given a state that has been added
        let r = bld.state(0)
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        // |> when we try to set initial value
        // |> then it will assert
        TestAssertionHit(graph: g) {
            r.setInitialValue(1)
        }
    }
    
    func testEnsuresCanUpdateChecksAreRun() {
        // NOTE: there are multiple canUpdate checks, this just ensures that
        // code path is followed
        bld.behavior().demands([r_a]).runs { extent in
            self.r_b.update(self.r_a.value)
        }
        ext = BGExtent(builder: bld)
        ext.addToGraphWithAction()
        
        TestAssertionHit(graph: g) {
            r_a.updateWithAction(1)
        }
    }
    
}

fileprivate struct Struct {}
fileprivate class Object {}

fileprivate class EquatableObject: Equatable {
    var failEquality = false
    
    static func == (lhs: EquatableObject, rhs: EquatableObject) -> Bool {
        !lhs.failEquality && !rhs.failEquality
    }
}

class BGStateUpdateTests: XCTestCase {
    
    let g = BGGraph()
    var b: BGExtentBuilder<BGExtent>!
    
    override func setUp() {
        b = BGExtentBuilder(graph: g)
    }
        
    override func tearDown() {
        g.debugOnAssertionFailure = nil
    }
    
    // MARK: Non-Equatable, Non-Object
    
    func testNonEquatableStruct_default() {
        // default is .none
        
        let s = b.state(Struct())
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testNonEquatableStruct_noCheck() {
        let s = b.state(Struct(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Equatable, Non-Object
    
    func testEquatable_default() {
        // default is .equal
        
        let s = b.state("foo")
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update("foo")
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update("bar")
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatable_noCheck() {
        let s = b.state("foo", comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatable_equals() {
        let s = b.state("foo", comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
//            s.valueEquality("foo", equalityCheck: .equal)
            s.update("foo")
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update("bar")
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatable_forced() {
        let s = b.state("foo", comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update("foo")
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update("foo", forced: true)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Non-Equatable, Object
    
    func testObject_default() {
        // default is .identical
        
        let s = b.state(Object())
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testObject_noCheck() {
        let s = b.state(Object(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testObject_indentical() {
        let s = b.state(Object(), comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Equatable, Object
    
    func testEquatableObject_default() {
        // default is .equal
        
        let obj = EquatableObject()
        
        let s = b.state(obj)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        self.g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_noCheck() {
        let s = b.state(EquatableObject(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_equal() {
        let obj = EquatableObject()
        
        let s = b.state(obj, comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        self.g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_indentical() {
        let s = b.state(EquatableObject(), comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(EquatableObject())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_forced() {
        let obj = EquatableObject()
        obj.failEquality = false
        
        let s = b.state(obj, comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(obj, forced: true)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Optional, Non-Equatable, Object
    
    func testOptionalObject_default() {
        // default is .identical
        
        let s: BGState<Object?> = b.state(Object())
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalObject_noCheck() {
        let s: BGState<Object?> = b.state(Object(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalObject_indentical() {
        let s: BGState<Object?> = b.state(Object(), comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Optional Equatable, Object
    
    func testOptionalEquatableObject_default() {
        let obj = EquatableObject()
        
        let s: BGState<EquatableObject?> = b.state(EquatableObject())
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        
        self.g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalEquatableObject_noCheck() {
        let s: BGState<EquatableObject?> = b.state(EquatableObject(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalEquatableObject_equal() {
        let obj = EquatableObject()
        
        let s: BGState<EquatableObject?> = b.state(EquatableObject(), comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        
        self.g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalEquatableObject_indentical() {
        let obj1 = EquatableObject()
        obj1.failEquality = false
        
        let obj2 = EquatableObject()
        obj2.failEquality = false
        
        let s: BGState<EquatableObject?> = b.state(obj1, comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        self.g.action {
            extent.addToGraph()
            
            s.update(obj1)
            XCTAssertFalse(s.justUpdated())
        }
        
        self.g.action {
            s.update(obj2)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testPreviousValueIsNotRetainedAfterAction() {
        class ClassType {}
        
        weak var weakValue: ClassType?
        let state: BGState<ClassType> = b.state(ClassType())
        let extent = BGExtent(builder: b)
        extent.addToGraphWithAction()
        
        weakValue = state.value
        XCTAssertNotNil(weakValue)
        
        autoreleasepool {
            state.updateWithAction(ClassType())
        }
        
        XCTAssertNil(weakValue)
    }
}
