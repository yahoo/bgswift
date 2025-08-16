//
//  Copyright © 2021 Yahoo
//    

import Foundation
import XCTest
import Quick
import Nimble
@testable import BGSwift

class BGStateTests : QuickSpec {
    override func spec() {
        describe("BGState") {
            var g: BGGraph!
            var r_a, r_b: BGState<Int>!
            var bld: BGExtentBuilder<BGExtent>!
            var ext: BGExtent!

            beforeEach {
                g = BGGraph()
                bld = BGExtentBuilder(graph: g)
                r_a = bld.state(0)
                r_b = bld.state(0)
            }

            it("has initial state") {
                // |> When we create a new state resource
                // |> It has an initial value
                expect(r_a.value) == 0
            }

            context("added to graph") {
                beforeEach {
                    ext = BGExtent(builder: bld)
                    ext.addToGraphWithAction()
                }

                it("updates") {
                    // |> When it is updated
                    r_a.updateWithAction(2)

                    // |> Then it has new value and event
                    expect(r_a.value) == 2
                    expect(r_a.event) == g.lastEvent
                }

            }
            
            it("can handle null/nil values") {
                // Motivation: nullable states are useful for modeling false/true with data

                // |> Given a nullable state
                let r_n: BGState<Int?> = bld.state(nil)
                ext = BGExtent(builder: bld)
                ext.addToGraphWithAction()

                // |> When updated
                r_n.updateWithAction(1)

                // |> Then it will have that new state
                expect(r_n.value) == 1

                // |> And when updated to nil
                r_n.updateWithAction(nil)

                // |> Then it will have nil state
                expect(r_n.value).to(beNil())
            }

            it("works as demand and supply") {
                // |> Given state resources and behaviors
                var ran = false;
                bld.behavior().supplies([r_b]).demands([r_a]).runs { extent in
                    r_b.update(r_a.value)
                }

                bld.behavior().demands([r_b]).runs { extent in
                    ran = true
                }
                ext = BGExtent(builder: bld)
                ext.addToGraphWithAction()

                // |> When event is started
                r_a.updateWithAction(1)
                
                // |> Then subsequent behaviors are run
                expect(r_b.value) == 1
                expect(ran) == true
            }

            it("justUpdated checks work during event") {
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
                    updatedA = r_a.justUpdated()
                    updatedB = r_b.justUpdated()
                    updatedToA = r_a.justUpdated(to: 1)
                    updatedToWrongToA = r_a.justUpdated(to: 2)
                    updatedToB = r_b.justUpdated(to: 1)
                    updatedToFromA = r_a.justUpdated(to: 1, from: 0)
                    updatedToFromWrongToA = r_a.justUpdated(to: 2, from: 0)
                    updatedToFromWrongFromA = r_a.justUpdated(to: 1, from: 2)
                    updatedToFromB = r_b.justUpdated(to: 1, from: 0)
                    updatedFromA = r_a.justUpdated(from: 0)
                    updatedFromWrongFromA = r_a.justUpdated(from: 2)
                    updatedFromB = r_b.justUpdated(from: 0)
                }
                ext = BGExtent(builder: bld)
                ext.addToGraphWithAction()
                
                // |> When r_a updates
                r_a.updateWithAction(1)
                
                // |> Then updates are tracked inside behavior
                expect(updatedA) == true
                expect(r_a.justUpdated()) == false // false outside event
                expect(updatedB) == false // not updated
                expect(updatedToA) == true
                expect(r_a.justUpdated(to: 1)) == false
                expect(updatedToWrongToA) == false
                expect(updatedToB) == false
                expect(updatedToFromA) == true
                expect(r_a.justUpdated(to: 1, from: 0)) == false
                expect(updatedToFromWrongToA) == false
                expect(updatedToFromWrongFromA) == false
                expect(updatedToFromB) == false
                expect(updatedFromA) == true
                expect(r_a.justUpdated(from: 0)) == false
                expect(updatedFromWrongFromA) == false
                expect(updatedFromB) == false
            }
            
            it("can access trace values/events") {
                var beforeValue: Int? = nil
                var beforeEvent: BGEvent? = nil
                
                // |> Given a behavior that accesses trace
                bld.behavior().demands([r_a]).runs { extent in
                    beforeValue = r_a.traceValue
                    beforeEvent = r_a.traceEvent
                }
                ext = BGExtent(builder: bld)
                ext.addToGraphWithAction()
                
                // |> When resource is updated
                r_a.updateWithAction(1)
                
                // |> Trace captures original state during
                expect(beforeValue) == 0
                expect(beforeEvent) == BGEvent.unknownPast
                // and current state outside event
                expect(r_a.traceValue) == 1
                expect(r_a.traceEvent) == g.lastEvent
            }
            
            it("can update resource during same event as adding") {
                // @SAL this doesn't work yet, can't add and update in the same event
                var didRun = false
                bld.behavior().demands([r_a]).runs { extent in
                    didRun = true
                }
                ext = BGExtent(builder: bld)
                
                g.action {
                    r_a.update(1)
                    ext.addToGraph()
                }
                
                expect(r_a.value) == 1
                expect(didRun) == true
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
            
            describe("checks") {
                
                // @SAL we don't have a way of catching asserts yet
                // so these are disabled
                xit("part of graph before updating") {
                    // expect {
                    //     r_a.updateWithAction(1)
                    // }.to(raiseException())
                }
                
                // @SAL-- 10/1/2021 basic canUpdate checks are in the moment tests
                // probably could move those to a BGResource tests class
                it("ensures canUpdate checks are run") {
                    // NOTE: there are multiple canUpdate checks, this just ensures that
                    // code path is followed
                    bld.behavior().demands([r_a]).runs { extent in
                        r_b.update(r_a.value)
                    }
                    ext = BGExtent(builder: bld)
                    ext.addToGraphWithAction()
                    
                    TestAssertionHit {
                        r_a.updateWithAction(1)
                    }
                }
            }
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
        onAssertionFailure = nil
    }
    
    // MARK: Non-Equatable, Non-Object
    
    func testNonEquatableStruct_default() {
        // default is .none
        
        let s = b.state(Struct())
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testNonEquatableStruct_noCheck() {
        let s = b.state(Struct(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        g.action {
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
        
        g.action {
            extent.addToGraph()
            
            s.update("foo")
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update("bar")
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatable_noCheck() {
        let s = b.state("foo", comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatable_equals() {
        let s = b.state("foo", comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
//            s.valueEquality("foo", equalityCheck: .equal)
            s.update("foo")
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update("bar")
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatable_forced() {
        let s = b.state("foo", comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update("foo")
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update("foo", forced: true)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Non-Equatable, Object
    
    func testObject_default() {
        // default is .identical
        
        let s = b.state(Object())
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testObject_noCheck() {
        let s = b.state(Object(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testObject_indentical() {
        let s = b.state(Object(), comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
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
        
        g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_noCheck() {
        let s = b.state(EquatableObject(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_equal() {
        let obj = EquatableObject()
        
        let s = b.state(obj, comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_indentical() {
        let s = b.state(EquatableObject(), comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update(EquatableObject())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testEquatableObject_forced() {
        let obj = EquatableObject()
        obj.failEquality = false
        
        let s = b.state(obj, comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update(obj, forced: true)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Optional, Non-Equatable, Object
    
    func testOptionalObject_default() {
        // default is .identical
        
        let s: BGState<Object?> = b.state(Object())
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalObject_noCheck() {
        let s: BGState<Object?> = b.state(Object(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalObject_indentical() {
        let s: BGState<Object?> = b.state(Object(), comparison: .identical)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
            s.update(Object())
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    // MARK: Optional Equatable, Object
    
    func testOptionalEquatableObject_default() {
        let obj = EquatableObject()
        
        let s: BGState<EquatableObject?> = b.state(EquatableObject())
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        
        g.action {
            s.update(obj)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalEquatableObject_noCheck() {
        let s: BGState<EquatableObject?> = b.state(EquatableObject(), comparison: .none)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(s.value)
            XCTAssertTrue(s.justUpdated())
        }
    }
    
    func testOptionalEquatableObject_equal() {
        let obj = EquatableObject()
        
        let s: BGState<EquatableObject?> = b.state(EquatableObject(), comparison: .equal)
        
        let extent = BGExtent(builder: b)
        
        g.action {
            extent.addToGraph()
            
            s.update(obj)
            XCTAssertFalse(s.justUpdated())
        }
        
        obj.failEquality = true
        
        g.action {
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
        
        g.action {
            extent.addToGraph()
            
            s.update(obj1)
            XCTAssertFalse(s.justUpdated())
        }
        
        g.action {
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
