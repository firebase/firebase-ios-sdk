// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/*
 * GULSwizzlerInheritedMethodsSwizzlingTest.h
 *
 * This test tests the behavior when swizzling and unswizzling methods that are inherited. After the
 * execution of these tests, the runtime for these classes is polluted - or to be more specific
 * the subclasses of PollutedTestObject no longer inherit (description:) from their superclass, but
 * now have their own implementation (which incidentally is identical to their superclass'
 * implementation). For this reason, we are using a separate hierarchy of classes from the tests in
 * GULSwizzlerTest.m so as to not interfere with other tests as well as to prevent other tests from
 * interfering with this test.
 */
#import <XCTest/XCTest.h>

#import "GoogleUtilities/MethodSwizzler/Public/GoogleUtilities/GULSwizzler.h"
#import "GoogleUtilities/SwizzlerTestHelpers/Public/GoogleUtilities/GULSwizzler+Unswizzle.h"

/** This class hierarchy exists exclusively for tests that test swizzling and unswizzling methods
 *  declared in an inheritance chain 3 levels deep. After completion of the tests the runtime for
 *  these classes ends up being polluted and would very likely result in these classes not being
 *  useful for any other tests, especially those involving inherited methods.
 */
@interface PollutedTestObject : NSObject

@end

@implementation PollutedTestObject

// This implementation of description is used to test swizzling a method declared several
// inheritance chains up.
- (NSString *)description {
  return [NSString stringWithFormat:@"Method implemented in PollutedTestObject, invoked on: %@",
                                    NSStringFromClass([self class])];
}

@end

/** Subclass of PollutedTestObject. It inherits all of its methods from its superclass. */
@interface PollutedTestObjectSubclass : PollutedTestObject

@end

@implementation PollutedTestObjectSubclass

@end

/** Subclass of PollutedTestObjectSubclass. It inherits all of its methods from its superclass two
 *  levels up (PollutedTestObject).
 */
@interface PollutedTestObjectSubclassSubclass : PollutedTestObjectSubclass

@end

@implementation PollutedTestObjectSubclassSubclass

@end

@interface GULSwizzlerInheritedMethodsSwizzlingTest : XCTestCase

@end

@implementation GULSwizzlerInheritedMethodsSwizzlingTest

/** Tests swizzling and unswizzling inherited instance methods works as expected. Specifically, it
 *  tests how unswizzling works in the case when we swizzle a method declared in the superclass,
 *  consequently swizzle the same method in its subclass - which results in adding the swizzled IMP
 *  to the subclass - and then unswizzle the method in the subclass, but not in the superclass.
 *  We also test this with 3 layers of inheritance to ensure that we restore the correct original
 *  IMP in the case of a subclass, even when the superclass method remains swizzled.
 */
- (void)testSwizzlingAndUnswizzlingInheritedInstanceMethodsForSuperclassesWorksAsExpected {
  PollutedTestObject *pollutedTestObject = [[PollutedTestObject alloc] init];
  PollutedTestObjectSubclass *pollutedTestObjectSubclass =
      [[PollutedTestObjectSubclass alloc] init];
  PollutedTestObjectSubclassSubclass *pollutedTestObjectSubclassSubclass =
      [[PollutedTestObjectSubclassSubclass alloc] init];

  NSString *originalPollutedTestObjectDescription = [pollutedTestObject description];
  NSString *originalPollutedTestObjectSubclassDescription =
      [pollutedTestObjectSubclass description];
  NSString *originalPollutedTestObjectSubclassSubclassDescription =
      [pollutedTestObjectSubclassSubclass description];

  // @selector(description:) is declared by the superclass (PollutedTestObject) but its result
  // varies based on which class it is invoked on. This detail needs to be true for this test to be
  // valid, which is what we're asserting.
  XCTAssertNotEqualObjects(originalPollutedTestObjectDescription,
                           originalPollutedTestObjectSubclassDescription);
  XCTAssertNotEqualObjects(originalPollutedTestObjectDescription,
                           originalPollutedTestObjectSubclassSubclassDescription);
  XCTAssertNotEqualObjects(originalPollutedTestObjectSubclassDescription,
                           originalPollutedTestObjectSubclassSubclassDescription);

  NSString *swizzledPollutedTestObjectDescription =
      [originalPollutedTestObjectDescription stringByAppendingString:@"SWIZZLED!"];
  NSString *swizzledPollutedTestObjectSubclassDescription =
      [originalPollutedTestObjectSubclassDescription stringByAppendingString:@"SWIZZLED!"];
  NSString *swizzledPollutedTestObjectSubclassSubclassDescription =
      [originalPollutedTestObjectSubclassSubclassDescription stringByAppendingString:@"SWIZZLED!"];

  NSString * (^newImplementationPollutedTestObject)(NSString *) = ^NSString *(id _self) {
    return swizzledPollutedTestObjectDescription;
  };

  NSString * (^newImplementationPollutedTestObjectSubclass)(NSString *) = ^NSString *(id _self) {
    return swizzledPollutedTestObjectSubclassDescription;
  };

  NSString * (^newImplementationPollutedTestObjectSubclassSubclass)(NSString *) =
      ^NSString *(id _self) {
    return swizzledPollutedTestObjectSubclassSubclassDescription;
  };

  SEL swizzledSelector = @selector(description);

  // Observe that swizzling the superclass IMP propogates to its subclasses when we haven't yet
  // swizzled and unsiwzzled the subclasses.
  [GULSwizzler swizzleClass:[PollutedTestObject class]
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:newImplementationPollutedTestObject];
  XCTAssertEqualObjects([pollutedTestObject description], swizzledPollutedTestObjectDescription);
  XCTAssertEqualObjects([pollutedTestObjectSubclass description],
                        swizzledPollutedTestObjectDescription);
  XCTAssertEqualObjects([pollutedTestObjectSubclassSubclass description],
                        swizzledPollutedTestObjectDescription);

  [GULSwizzler swizzleClass:[PollutedTestObjectSubclass class]
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:newImplementationPollutedTestObjectSubclass];
  XCTAssertEqualObjects([pollutedTestObjectSubclass description],
                        swizzledPollutedTestObjectSubclassDescription);
  XCTAssertEqualObjects([pollutedTestObjectSubclassSubclass description],
                        swizzledPollutedTestObjectSubclassDescription);

  [GULSwizzler swizzleClass:[PollutedTestObjectSubclassSubclass class]
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:newImplementationPollutedTestObjectSubclassSubclass];
  XCTAssertEqualObjects([pollutedTestObjectSubclassSubclass description],
                        swizzledPollutedTestObjectSubclassSubclassDescription);

  // Unswizzling a subclass invokes the original IMP declared in the super class (which is several
  // inheritance chains up), and mimics the behavior as if we - i.e. GULSwizzler, had never swizzled
  // the specific class in the first place.
  [GULSwizzler unswizzleClass:[PollutedTestObjectSubclassSubclass class]
                     selector:swizzledSelector
              isClassSelector:NO];
  XCTAssertEqualObjects([pollutedTestObjectSubclassSubclass description],
                        originalPollutedTestObjectSubclassSubclassDescription);
  XCTAssertEqualObjects([pollutedTestObjectSubclass description],
                        swizzledPollutedTestObjectSubclassDescription);
  XCTAssertEqualObjects([pollutedTestObject description], swizzledPollutedTestObjectDescription);

  [GULSwizzler unswizzleClass:[PollutedTestObjectSubclass class]
                     selector:swizzledSelector
              isClassSelector:NO];
  XCTAssertEqualObjects([pollutedTestObjectSubclass description],
                        originalPollutedTestObjectSubclassDescription);
  XCTAssertEqualObjects([pollutedTestObject description], swizzledPollutedTestObjectDescription);

  [GULSwizzler unswizzleClass:[PollutedTestObject class]
                     selector:swizzledSelector
              isClassSelector:NO];
  XCTAssertEqualObjects([pollutedTestObject description], originalPollutedTestObjectDescription);

  // This part of the test shows how 'unswizzling' still maintains a polluted runtime and
  // demonstrates the limitations of unswizzling due to the absence of class_removeMethod in ObjC.
  // Because we swizzled methods that didn't exist on the specific class (it came from the super
  // class), we ended up adding them. Swizzling again no longer respects the same inheritance chain
  // we'd observed after we'd first swizzled [PollutedTestObject description].
  [GULSwizzler swizzleClass:[PollutedTestObject class]
                   selector:swizzledSelector
            isClassSelector:NO
                  withBlock:newImplementationPollutedTestObject];
  XCTAssertEqualObjects([pollutedTestObject description], swizzledPollutedTestObjectDescription);
  XCTAssertEqualObjects([pollutedTestObjectSubclass description],
                        originalPollutedTestObjectSubclassDescription);
  XCTAssertEqualObjects([pollutedTestObjectSubclassSubclass description],
                        originalPollutedTestObjectSubclassSubclassDescription);

  [GULSwizzler unswizzleClass:[PollutedTestObject class]
                     selector:swizzledSelector
              isClassSelector:NO];
}

@end
