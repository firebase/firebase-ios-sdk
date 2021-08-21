// Copyright 2020 Google LLC
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

#pragma mark - Unswizzle based tests

#if !SWIFT_PACKAGE

#import "FirebasePerformance/Sources/Instrumentation/UIKit/FPRUIViewControllerInstrument.h"

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker+Private.h"
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import <GoogleUtilities/GULSwizzler.h>

static BOOL originalViewDidAppearInvoked = NO;
static BOOL originalViewDidDisappearInvoked = NO;

@interface FPRUIViewControllerInstrumentTest : XCTestCase

@end

@implementation FPRUIViewControllerInstrumentTest

+ (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
}

+ (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
}

- (void)setUp {
  [super setUp];
  originalViewDidAppearInvoked = NO;
  originalViewDidDisappearInvoked = NO;
}

/** Tests that the viewControllerDidAppear: of the FPRScreenTraceTracker sharedInstance is invoked
 *  when a UIViewController's viewDidAppear: is invoked.
 */
- (void)testViewDidAppearInvokesViewControllerDidAppearOnScreenTraceTracker {
  UIViewController *testViewController = [[UIViewController alloc] init];
  [[UIApplication sharedApplication].keyWindow addSubview:[testViewController view]];

  FPRUIViewControllerInstrument *instrument = [[FPRUIViewControllerInstrument alloc] init];
  [instrument registerInstrumentors];

  // Partial mock isa swizzles the object and we can listen to whether it received certain messages.
  id screenTraceTrackerListener = OCMPartialMock([FPRScreenTraceTracker sharedInstance]);
  OCMExpect([screenTraceTrackerListener viewControllerDidAppear:testViewController]);

  [testViewController viewDidAppear:YES];
  OCMVerifyAll(screenTraceTrackerListener);

  [screenTraceTrackerListener stopMocking];
  [instrument deregisterInstrumentors];

  [[testViewController view] removeFromSuperview];
}

/** Tests that the viewControllerDidAppear: of the FPRScreenTraceTracker sharedInstance is invoked
 *  when a UIViewController's viewDidAppear: is invoked.
 */
- (void)testViewDidAppearDoesntInvokeViewControllerDidAppearOnNonKeyWindowView {
  UIViewController *testViewController = [[UIViewController alloc] init];

  FPRUIViewControllerInstrument *instrument = [[FPRUIViewControllerInstrument alloc] init];
  [instrument registerInstrumentors];

  // Partial mock isa swizzles the object and we can listen to whether it received certain messages.
  id screenTraceTrackerListener = OCMPartialMock([FPRScreenTraceTracker sharedInstance]);
  OCMReject([screenTraceTrackerListener viewControllerDidAppear:testViewController]);

  [testViewController viewDidAppear:YES];
  OCMVerifyAll(screenTraceTrackerListener);

  [screenTraceTrackerListener stopMocking];
  [instrument deregisterInstrumentors];
}

/** Tests that the viewControllerDidDisappear: of the FPRScreenTraceTracker sharedInstance is
 *  invoked when a UIViewController's viewDidDisappear: is invoked.
 */
- (void)testViewDidDisappearInvokesViewControllerDidDisappearOnScreenTraceTracker {
  UIViewController *testViewController = [[UIViewController alloc] init];

  FPRUIViewControllerInstrument *instrument = [[FPRUIViewControllerInstrument alloc] init];
  [instrument registerInstrumentors];

  // Partial mock isa swizzles the object and we can listen to whether it received certain messages.
  id screenTraceTrackerListener = OCMPartialMock([FPRScreenTraceTracker sharedInstance]);
  OCMExpect([screenTraceTrackerListener viewControllerDidDisappear:testViewController]);

  [testViewController viewDidDisappear:YES];
  OCMVerifyAll(screenTraceTrackerListener);

  [screenTraceTrackerListener stopMocking];
  [instrument deregisterInstrumentors];
}

/** Tests that the instrument invokes the IMP that was previously in place for
 *  [uiViewControllerInstance viewDidAppear:].
 */
- (void)testViewDidAppearInvokesPreviousViewDidAppear {
  __block BOOL previousViewDidAppearCalled = NO;
  Class viewControllerClass = [UIViewController class];
  SEL viewDidAppearSelector = @selector(viewDidAppear:);
  [GULSwizzler swizzleClass:viewControllerClass
                   selector:viewDidAppearSelector
            isClassSelector:NO
                  withBlock:^void(id _self, BOOL animated) {
                    previousViewDidAppearCalled = YES;
                  }];

  UIViewController *testViewController = [[UIViewController alloc] init];

  FPRUIViewControllerInstrument *instrument = [[FPRUIViewControllerInstrument alloc] init];
  [instrument registerInstrumentors];

  XCTAssertFalse(previousViewDidAppearCalled);
  [testViewController viewDidAppear:YES];
  XCTAssertTrue(previousViewDidAppearCalled);

  // This should revert the first IMP that was swizzled as well.
  [instrument deregisterInstrumentors];
}

/** Tests that the instrument invokes the IMP that was previously in place for
 *  [uiViewControllerInstance viewDidDisappear:].
 */
- (void)testViewDidAppearInvokesPreviousViewDidDisappear {
  __block BOOL previousViewDidDisappearCalled = NO;
  Class viewControllerClass = [UIViewController class];
  SEL viewDidDisappearSelector = @selector(viewDidDisappear:);
  [GULSwizzler swizzleClass:viewControllerClass
                   selector:viewDidDisappearSelector
            isClassSelector:NO
                  withBlock:^void(id _self, BOOL animated) {
                    previousViewDidDisappearCalled = YES;
                  }];

  UIViewController *testViewController = [[UIViewController alloc] init];

  FPRUIViewControllerInstrument *instrument = [[FPRUIViewControllerInstrument alloc] init];
  [instrument registerInstrumentors];

  XCTAssertFalse(previousViewDidDisappearCalled);
  [testViewController viewDidDisappear:YES];
  XCTAssertTrue(previousViewDidDisappearCalled);

  // This should revert the first IMP that was swizzled as well.
  [instrument deregisterInstrumentors];
}

@end

#endif  // SWIFT_PACKAGE
