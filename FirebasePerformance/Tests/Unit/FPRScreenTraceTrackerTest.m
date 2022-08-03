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

#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker+Private.h"
#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker.h"

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "FirebasePerformance/Sources/Timer/FIRTrace+Private.h"

#import <OCMock/OCMock.h>
#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

/** Registers and returns an instance of a custom subclass of UIViewController. */
static UIViewController *FPRCustomViewController(NSString *className, BOOL isViewLoaded) {
  Class customClass = NSClassFromString(className);
  if (!customClass) {
    // Register the class if it does not already exist.
    customClass = objc_allocateClassPair([UIViewController class], className.UTF8String, 0);
    objc_registerClassPair(customClass);
  }

  UIViewController *customVC = [[customClass alloc] init];

  if (isViewLoaded) {
    [customVC view];
  }
  return customVC;
}

/** Test UINavigationController subclass. */
@interface FPRTestNavigationViewController : UINavigationController
@end

@implementation FPRTestNavigationViewController
@end

/** Test UITabBarController subclass. */
@interface FPRTestTabBarController : UITabBarController
@end

@implementation FPRTestTabBarController
@end

/** Test UISplitViewController subclass. */
@interface FPRTestSplitViewController : UISplitViewController
@end

@implementation FPRTestSplitViewController
@end

/** Test UIPageViewController. */
@interface FPRTestPageViewController : UIPageViewController
@end

@implementation FPRTestPageViewController
@end

@interface FPRScreenTraceTrackerTest : FPRTestCase

/** The FPRScreenTraceTracker instance that's being used for a given test. */
@property(nonatomic, nullable) FPRScreenTraceTracker *tracker;

/** The dispatch group a test should wait for completion on before asserting behavior under test. */
@property(nonatomic, nullable) dispatch_group_t dispatchGroupToWaitOn;

@end

@implementation FPRScreenTraceTrackerTest

- (void)setUp {
  [super setUp];

  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
  self.tracker = [[FPRScreenTraceTracker alloc] init];
  self.tracker.displayLink.paused = YES;
  self.dispatchGroupToWaitOn = self.tracker.screenTraceTrackerDispatchGroup;
}

- (void)tearDown {
  [super tearDown];

  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  self.tracker = nil;
  self.dispatchGroupToWaitOn = nil;
}

/** Tests that shared instance returns the same instance. */
- (void)testSingleton {
  FPRScreenTraceTracker *trackerOne = [FPRScreenTraceTracker sharedInstance];
  FPRScreenTraceTracker *trackerTwo = [FPRScreenTraceTracker sharedInstance];

  XCTAssertEqual(trackerOne, trackerTwo);  // Check that it's the same instance.
}

/** Tests that the atomic counters are initialized to zero during init. */
- (void)testCountersInitToZero {
  FPRScreenTraceTracker *tracker = [[FPRScreenTraceTracker alloc] init];
  XCTAssertEqual(tracker.frozenFramesCount, 0);
  XCTAssertEqual(tracker.slowFramesCount, 0);
  XCTAssertEqual(tracker.totalFramesCount, 0);
}

/** Tests that viewControllerDidAppear starts a trace. */
- (void)testViewControllerDidAppearStartsATraceForVCWithLoadedView {
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);

  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.activeScreenTraces.count, 1);
  NSString *expectedTraceName =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController];
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController]);
  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertEqualObjects(createdTrace.name, expectedTraceName);
  XCTAssertFalse(createdTrace.isCompleteAndValid);
}

/** Tests that the trace is not created when data collection is disabled */
- (void)testTraceCreationDisabledWhenDataCollectionDisabled {
  @autoreleasepool {
    BOOL dataCollectionEnabled = [FIRPerformance sharedInstance].dataCollectionEnabled;
    [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];
    UIViewController *newVCInstance =
        FPRCustomViewController(@"MyModule.UIFancyViewController", YES);
    [self.tracker viewControllerDidAppear:newVCInstance];

    // objectForKey: is always executed on the FPRScreenTraceTracker serial queue, which has its own
    // autorelesepool. Without the autoreleasepool, the ViewController instance is not released
    // in a timely manner and this test becomes flaky.
    FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:newVCInstance];
    XCTAssertNil(createdTrace);

    // Clean up.
    [self.tracker viewControllerDidDisappear:newVCInstance];
    newVCInstance = nil;
    [[FIRPerformance sharedInstance] setDataCollectionEnabled:dataCollectionEnabled];
  }
}

/** Tests that the trace is named correctly in case of Swift classes which are of the format
 *  ModuleName.ClassName.
 */
- (void)testUnprefixedClassName {
  @autoreleasepool {
    UIViewController *newVCInstance =
        FPRCustomViewController(@"MyModule.UIFancyViewController", YES);
    [self.tracker viewControllerDidAppear:newVCInstance];
    NSString *expectedTraceName = @"_st_UIFancyViewController";

    // objectForKey: is always executed on the FPRScreenTraceTracker serial queue, which has its own
    // autorelesepool. Without the autoreleasepool, the ViewController instance is not released
    // in a timely manner and this test becomes flaky.
    FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:newVCInstance];
    XCTAssertEqualObjects(createdTrace.name, expectedTraceName);
    createdTrace = nil;

    // Clean up.
    [self.tracker viewControllerDidDisappear:newVCInstance];
    newVCInstance = nil;
  }
}

/** Tests that the module name length is not factored into truncating the screen trace name in case
 *  of Swift classes.
 */
- (void)testDoesNotTruncateClassNameExtraLongSwiftModuleName {
  NSUInteger valueGreaterThanMaxTraceLength = kFPRMaxNameLength + 10;
  NSMutableString *extraLongModuleName =
      [[NSMutableString alloc] initWithCapacity:valueGreaterThanMaxTraceLength];
  for (int i = 0; i < valueGreaterThanMaxTraceLength; ++i) {
    [extraLongModuleName appendString:@"a"];
  }
  XCTAssertEqual(extraLongModuleName.length, valueGreaterThanMaxTraceLength);
  NSString *swiftClassName =
      [NSString stringWithFormat:@"%@.%@", extraLongModuleName, @"MyViewController"];
  NSString *expectedTraceName = @"_st_MyViewController";

  @autoreleasepool {
    UIViewController *newVCInstance = FPRCustomViewController(swiftClassName, YES);
    [self.tracker viewControllerDidAppear:newVCInstance];

    // objectForKey: is always executed on the FPRScreenTraceTracker serial queue, which has its own
    // autorelesepool. Without the autoreleasepool, the ViewController instance is not released
    // in a timely manner and this test becomes flaky.
    FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:newVCInstance];
    XCTAssertEqualObjects(createdTrace.name, expectedTraceName);
    createdTrace = nil;

    // Clean up.
    [self.tracker viewControllerDidDisappear:newVCInstance];
    newVCInstance = nil;
  }
}

/** Tests that if a Swift class name pushes the screen trace name beyond the max trace name length,
 *  the screen trace name is truncated.
 */
- (void)testTruncatesExtraLongSwiftClassName {
  NSUInteger valueGreaterThanMaxTraceLength = kFPRMaxNameLength + 10;
  NSMutableString *extraLongClassName = [[NSMutableString alloc] init];
  for (int i = 0; i < valueGreaterThanMaxTraceLength; ++i) {
    [extraLongClassName appendString:@"a"];
  }
  XCTAssertEqual(extraLongClassName.length, valueGreaterThanMaxTraceLength);
  NSString *swiftClassName = [NSString stringWithFormat:@"%@.%@", @"MyModule", extraLongClassName];

  @autoreleasepool {
    UIViewController *newVCInstance = FPRCustomViewController(swiftClassName, YES);
    [self.tracker viewControllerDidAppear:newVCInstance];

    // objectForKey: is always executed on the FPRScreenTraceTracker serial queue, which has its own
    // autorelesepool. Without the autoreleasepool, the ViewController instance is not released
    // in a timely manner and this test becomes flaky.
    FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:newVCInstance];
    XCTAssertEqual(createdTrace.name.length, kFPRMaxNameLength);
    createdTrace = nil;

    // Clean up.
    [self.tracker viewControllerDidDisappear:newVCInstance];
    newVCInstance = nil;
  }
}

/** Tests that if an ObjC class name pushes the screen trace name beyond the max trace name length,
 *  the screen trace name is truncated.
 */
- (void)testTruncatesExtraLongObjCClassName {
  NSUInteger valueGreaterThanMaxTraceLength = kFPRMaxNameLength + 10;
  NSMutableString *extraLongClassName = [[NSMutableString alloc] init];
  for (int i = 0; i < valueGreaterThanMaxTraceLength; ++i) {
    [extraLongClassName appendString:@"a"];
  }
  XCTAssertEqual(extraLongClassName.length, valueGreaterThanMaxTraceLength);

  @autoreleasepool {
    UIViewController *newVCInstance = FPRCustomViewController(extraLongClassName, YES);
    [self.tracker viewControllerDidAppear:newVCInstance];

    // objectForKey: is always executed on the FPRScreenTraceTracker serial queue, which has its own
    // autorelesepool. Without the autoreleasepool, the ViewController instance is not released
    // in a timely manner and this test becomes flaky.
    FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:newVCInstance];
    XCTAssertEqual(createdTrace.name.length, kFPRMaxNameLength);
    createdTrace = nil;

    // Clean up.
    [self.tracker viewControllerDidDisappear:newVCInstance];
    newVCInstance = nil;
  }
}

/** Tests that a viewController isn't retained by the ScreenTraceTracker. */
- (void)testViewControllerIsHeldWeaklyByTheScreenTraceTracker {
  __block UIViewController *newVCInstance = nil;
  __weak UIViewController *weakVCReference = nil;
  @autoreleasepool {
    newVCInstance = [[UIViewController alloc] init];
    [newVCInstance view];  // Loads the view so that a screen trace is created for it.
    [self.tracker viewControllerDidAppear:newVCInstance];
    [self.tracker viewControllerDidDisappear:newVCInstance];
    weakVCReference = newVCInstance;
    newVCInstance = nil;
  }

  XCTAssertNil(weakVCReference);
}

/** Tests that viewControllerDidDisappear stops a trace. */
- (void)testViewControllerDidDisappearStopsATrace {
  // First screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  NSString *expectedTraceName =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController];
  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertNotNil(createdTrace);
  XCTAssertEqualObjects(expectedTraceName, createdTrace.name);

  // First screen disappears.
  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);
  XCTAssertTrue(createdTrace.isCompleteAndValid);
}

/** Tests that viewControllerDidAppear starts multiple traces if multiple view controllers with the
 *  same class appear one after the other.
 */
- (void)testViewControllerDidAppearStartsMultipleScreenTracesForSameClassIfNeeded {
  // First screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];

  // Second screen appears, first screen is still visible.
  UIViewController *testViewController2 = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController2];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  NSString *expectedTraceNameOne =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController];
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController]);
  FIRTrace *traceForScreenOne = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertEqualObjects(traceForScreenOne.name, expectedTraceNameOne);

  NSString *expectedTraceNameTwo =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController2];
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController2]);
  FIRTrace *traceForScreenTwo = [self.tracker.activeScreenTraces objectForKey:testViewController2];
  XCTAssertEqualObjects(traceForScreenTwo.name, expectedTraceNameTwo);

  // Test that they're different instances.
  XCTAssertNotEqual(traceForScreenOne, traceForScreenTwo);
  XCTAssertEqualObjects(traceForScreenOne.name, traceForScreenTwo.name);
}

/** Tests that viewControllerDidAppear starts multiple traces if multiple view controllers with
 *  different classes appear one after the other.
 */
- (void)testViewControllerDidAppearStartsMultipleScreenTracesForDifferentClassIfNeeded {
  // First screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];

  // Second screen appears, first screen is still visible.
  UIViewController *testViewController2 = FPRCustomViewController(@"FPRTestViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController2];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  NSString *expectedTraceNameOne =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController];
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController]);
  FIRTrace *traceForScreenOne = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertEqualObjects(traceForScreenOne.name, expectedTraceNameOne);

  NSString *expectedTraceNameTwo =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController2];
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController2]);
  FIRTrace *traceForScreenTwo = [self.tracker.activeScreenTraces objectForKey:testViewController2];
  XCTAssertEqualObjects(traceForScreenTwo.name, expectedTraceNameTwo);

  XCTAssertNotEqual(traceForScreenOne,
                    traceForScreenTwo);  // Test that they're different instances.
  XCTAssertNotEqualObjects(traceForScreenOne.name, traceForScreenTwo.name);
}

/** Tests that viewControllerDidDisappear stops the correct trace when multiple traces are present.
 */
- (void)testViewControllerDidDisappearStopsCorrectTraceWhenMultiplePresent {
  // First screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];

  // Second screen appears, first screen is still visible.
  UIViewController *testViewController2 = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController2];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.activeScreenTraces.count, 2);

  FIRTrace *traceForScreenOne = [self.tracker.activeScreenTraces objectForKey:testViewController];
  FIRTrace *traceForScreenTwo = [self.tracker.activeScreenTraces objectForKey:testViewController2];

  XCTAssertFalse(traceForScreenOne.isCompleteAndValid);
  XCTAssertFalse(traceForScreenTwo.isCompleteAndValid);

  [self.tracker viewControllerDidDisappear:testViewController2];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertFalse(traceForScreenOne.isCompleteAndValid);
  XCTAssertTrue(traceForScreenTwo.isCompleteAndValid);
}

/** Tests that viewControllerDidAppear doesn't start a duplicate trace. */
- (void)testViewControllerDidAppearIgnoresDuplicateEvent {
  // First screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  NSString *expectedTraceName =
      [FPRScreenTraceTrackerTest expectedTraceNameForViewController:testViewController];
  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertNotNil(createdTrace);
  XCTAssertEqualObjects(createdTrace.name, expectedTraceName);

  // Send the same event again.
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.activeScreenTraces.count, 1);
  FIRTrace *activeTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertEqual(createdTrace, activeTrace);  // Test that it is the same trace.
}

/** Tests that viewControllerDidAppear gracefully handles a nil viewController. */
- (void)testViewControllerDidAppearGracefullyHandlesNilViewController {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [self.tracker viewControllerDidAppear:nil];
#pragma clang diagnostic pop
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(self.tracker.activeScreenTraces.count, 0);
}

/** Tests that viewControllerDidDisappear for a viewController that did not appear does nothing. */
- (void)testViewControllerDidDisappearIgnoresViewControllerThatWasntScreenTraced {
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  UIViewController *testViewController2 = FPRCustomViewController(@"UIViewController", YES);

  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(self.tracker.activeScreenTraces.count, 1);

  [self.tracker viewControllerDidDisappear:testViewController2];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(self.tracker.activeScreenTraces.count, 1);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [self.tracker viewControllerDidDisappear:nil];
#pragma clang diagnostic pop
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(self.tracker.activeScreenTraces.count, 1);

  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);
  XCTAssertEqual(self.tracker.activeScreenTraces.count, 0);
}

/** Tests that UIViewControllers are weakly retained in the map table that holds the mapping between
 *  them.
 */
- (void)testViewControllerIsWeaklyRetained {
  @autoreleasepool {
    UIViewController *testViewController = [[UIViewController alloc] init];
    id mockTrace = OCMClassMock([FIRTrace class]);
    [self.tracker.activeScreenTraces setObject:mockTrace forKey:testViewController];
    testViewController = nil;
  }

  XCTAssertEqual([self.tracker.activeScreenTraces dictionaryRepresentation].count, 0);
}

/** Tests that a FIRTrace is strongly retained in the map table that holds the mapping between a
 *  view controller and its screen trace.
 */
- (void)testFIRTraceIsStronglyRetained {
  UIViewController *testViewController = [[UIViewController alloc] init];
  NSString *traceName = @"screenTrace";
  FIRTrace *trace = [[FIRTrace alloc] initInternalTraceWithName:traceName];

  [self.tracker.activeScreenTraces setObject:trace forKey:testViewController];
  trace = nil;

  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController]);

  FIRTrace *returnedTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];
  XCTAssertEqualObjects(returnedTrace.name, traceName);
}

/** Tests that a screen trace that doesn't collect any data isn't sent. */
- (void)testTraceWithNoCountersIsNotSent {
  id mockTrace = OCMClassMock([FIRTrace class]);
  UIViewController *testViewController = [[UIViewController alloc] init];
  [self.tracker.activeScreenTraces setObject:mockTrace forKey:testViewController];

  OCMExpect([mockTrace cancel]);
  [[mockTrace reject] stop];

  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  OCMVerifyAll(mockTrace);
}

/** Test that all active traces are stopped when the app resigns active status. */
- (void)testWillAppResignActiveStopsAllActiveTraces {
  // First screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];

  // Second screen appears.
  UIViewController *testViewController2 = FPRCustomViewController(@"FPRTestViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController2];

  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  FIRTrace *traceScreenOne = [self.tracker.activeScreenTraces objectForKey:testViewController];
  FIRTrace *traceScreenTwo = [self.tracker.activeScreenTraces objectForKey:testViewController2];

  XCTAssertNotNil(traceScreenOne);
  XCTAssertNotNil(traceScreenTwo);

  // App is backgrounded.
  NSNotification *appWillResignActiveNSNotification =
      [NSNotification notificationWithName:UIApplicationWillResignActiveNotification object:nil];
  [self.tracker appWillResignActiveNotification:appWillResignActiveNSNotification];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertTrue(traceScreenOne.isCompleteAndValid);
  XCTAssertTrue(traceScreenTwo.isCompleteAndValid);
}

/** Test that viewController refs are weakly saved for future use when the app resigns active
 *  status.
 */
- (void)disabled_testWillAppResignActiveWeaklySavesAllVisibleViewControllers {
  // Screen appears.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  // App is backgrounded.
  NSNotification *appWillResignActiveNSNotification =
      [NSNotification notificationWithName:UIApplicationWillResignActiveNotification object:nil];
  [self.tracker appWillResignActiveNotification:appWillResignActiveNSNotification];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.previouslyVisibleViewControllers.count, 1);
  XCTAssertEqual(self.tracker.activeScreenTraces.count, 0);

  __weak id weakTestViewController = testViewController;
  testViewController = nil;

  // The blocks retain the view controllers and it sometimes takes some time to release them.
  // This is in place to prevent test flakiness. Autoreleasepools do not work in this case.
  while (weakTestViewController) {
    continue;
  }

  XCTAssertNil([self.tracker.previouslyVisibleViewControllers pointerAtIndex:0]);
}

/** Tests that new traces are started with the screens that are currently visible after the app
 *  regains active status.
 */
- (void)testAppDidBecomeActiveWillRestoreTracesOfVisibleScreens {
  // Simulate state where two screen traces were previously active.
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  UIViewController *testViewController2 = FPRCustomViewController(@"FPRTestViewController", YES);
  self.tracker.previouslyVisibleViewControllers = [NSPointerArray weakObjectsPointerArray];
  [self.tracker.previouslyVisibleViewControllers addPointer:(__bridge void *)testViewController];
  [self.tracker.previouslyVisibleViewControllers addPointer:(__bridge void *)testViewController2];

  // App becomes active.
  NSNotification *appDidBecomeActiveNSNotification =
      [NSNotification notificationWithName:UIApplicationDidBecomeActiveNotification object:nil];
  [self.tracker appDidBecomeActiveNotification:appDidBecomeActiveNSNotification];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.activeScreenTraces.count, 2);
  XCTAssertNil(self.tracker.previouslyVisibleViewControllers);
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController]);
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController2]);
}

/** Tests that if one of the previously visible ViewControllers is deallocated, a new trace isn't
 *  started for it, and the app doesn't crash. */
- (void)testAppDidBecomeActiveWillNotRestoreTracesOfNilledViewControllers {
  // Simulate state where two screen traces were previously active.
  UIViewController *testViewController = [[UIViewController alloc] init];
  [testViewController view];  // Loads the view so that a screen trace is created for it.

  UIViewController *testViewController2 = [[UIViewController alloc] init];
  [testViewController2 view];  // Loads the view so that a screen trace is created for it.

  self.tracker.previouslyVisibleViewControllers = [NSPointerArray weakObjectsPointerArray];
  [self.tracker.previouslyVisibleViewControllers addPointer:(__bridge void *)testViewController];
  [self.tracker.previouslyVisibleViewControllers addPointer:(__bridge void *)testViewController2];

  // UIKit deallocates one of the ViewControllers that was previously visible.
  testViewController2 = nil;

  // App becomes active.
  NSNotification *appDidBecomeActiveNSNotification =
      [NSNotification notificationWithName:UIApplicationDidBecomeActiveNotification object:nil];
  [self.tracker appDidBecomeActiveNotification:appDidBecomeActiveNSNotification];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertNil(self.tracker.previouslyVisibleViewControllers);
  XCTAssertNotNil([self.tracker.activeScreenTraces objectForKey:testViewController]);
  XCTAssertNil([self.tracker.activeScreenTraces objectForKey:testViewController2]);
}

/** Tests that if consecutive frames take more time to render than the slow frames threshold, the
 *  slow frame counter of the screen trace tracker is incremented.
 */
- (void)testSlowFrameIsRecorded {
  CFAbsoluteTime firstFrameRenderTimestamp = 1.0;
  CFAbsoluteTime secondFrameRenderTimestamp =
      firstFrameRenderTimestamp + kFPRSlowFrameThreshold + 0.005;  // Buffer for float comparison.

  id displayLinkMock = OCMClassMock([CADisplayLink class]);
  [self.tracker.displayLink invalidate];
  self.tracker.displayLink = displayLinkMock;

  // Set/Reset the previousFrameTimestamp if it has been set by a previous test.
  OCMExpect([displayLinkMock timestamp]).andReturn(firstFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t initialSlowFramesCount = self.tracker.slowFramesCount;

  OCMExpect([displayLinkMock timestamp]).andReturn(secondFrameRenderTimestamp);
  [self.tracker displayLinkStep];

  int64_t newSlowFramesCount = self.tracker.slowFramesCount;
  XCTAssertEqual(newSlowFramesCount, initialSlowFramesCount + 1);
}

/** Tests that the slow and frozen frame counter is not incremented in the case of a good frame. */
- (void)testSlowAndFrozenFrameIsNotRecordedInCaseOfGoodFrame {
  CFAbsoluteTime firstFrameRenderTimestamp = 1.0;
  CFAbsoluteTime secondFrameRenderTimestamp =
      firstFrameRenderTimestamp + kFPRSlowFrameThreshold - 0.005;  // Good frame.

  id displayLinkMock = OCMClassMock([CADisplayLink class]);
  [self.tracker.displayLink invalidate];
  self.tracker.displayLink = displayLinkMock;

  // Set/Reset the previousFrameTimestamp if it has been set by a previous test.
  OCMExpect([displayLinkMock timestamp]).andReturn(firstFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t initialFrozenFramesCount = self.tracker.frozenFramesCount;
  int64_t initialSlowFramesCount = self.tracker.slowFramesCount;

  OCMExpect([displayLinkMock timestamp]).andReturn(secondFrameRenderTimestamp);
  [self.tracker displayLinkStep];

  int64_t newSlowFramesCount = self.tracker.slowFramesCount;
  int64_t newFrozenFramesCount = self.tracker.frozenFramesCount;

  XCTAssertEqual(newSlowFramesCount, initialSlowFramesCount);
  XCTAssertEqual(newFrozenFramesCount, initialFrozenFramesCount);
}

/* Tests that the frozen frame counter is not incremented in case of a slow frame. */
- (void)testFrozenFrameIsNotRecordedInCaseOfSlowFrame {
  CFAbsoluteTime firstFrameRenderTimestamp = 1.0;
  CFAbsoluteTime secondFrameRenderTimestamp =
      firstFrameRenderTimestamp + kFPRSlowFrameThreshold + 0.005;  // Slow frame.

  id displayLinkMock = OCMClassMock([CADisplayLink class]);
  [self.tracker.displayLink invalidate];
  self.tracker.displayLink = displayLinkMock;

  // Set/Reset the previousFrameTimestamp if it has been set by a previous test.
  OCMExpect([displayLinkMock timestamp]).andReturn(firstFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t initialFrozenFramesCount = self.tracker.frozenFramesCount;

  OCMExpect([displayLinkMock timestamp]).andReturn(secondFrameRenderTimestamp);
  [self.tracker displayLinkStep];

  int64_t newFrozenFramesCount = self.tracker.frozenFramesCount;
  XCTAssertEqual(newFrozenFramesCount, initialFrozenFramesCount);
}

/** Tests that the total frames counter is incremented in the case of good, slow and frozen
 *  frames.
 */
- (void)testTotalFramesAreAlwaysRecorded {
  CFAbsoluteTime firstFrameRenderTimestamp = 1.0;
  CFAbsoluteTime secondFrameRenderTimestamp =
      firstFrameRenderTimestamp + kFPRSlowFrameThreshold - 0.005;  // Good frame.
  CFAbsoluteTime thirdFrameRenderTimestamp =
      secondFrameRenderTimestamp + kFPRSlowFrameThreshold + 0.005;  // Slow frame.
  CFAbsoluteTime fourthFrameRenderTimestamp =
      thirdFrameRenderTimestamp + kFPRFrozenFrameThreshold + 0.005;  // Frozen frame.

  id displayLinkMock = OCMClassMock([CADisplayLink class]);
  [self.tracker.displayLink invalidate];
  self.tracker.displayLink = displayLinkMock;

  // Set/Reset the previousFrameTimestamp if it has been set by a previous test.
  OCMExpect([displayLinkMock timestamp]).andReturn(firstFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t initialTotalFramesCount = self.tracker.totalFramesCount;

  OCMExpect([displayLinkMock timestamp]).andReturn(secondFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t newTotalFramesCount = self.tracker.totalFramesCount;
  XCTAssertEqual(newTotalFramesCount, initialTotalFramesCount + 1);

  OCMExpect([displayLinkMock timestamp]).andReturn(thirdFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  newTotalFramesCount = self.tracker.totalFramesCount;
  XCTAssertEqual(newTotalFramesCount, initialTotalFramesCount + 2);

  OCMExpect([displayLinkMock timestamp]).andReturn(fourthFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  newTotalFramesCount = self.tracker.totalFramesCount;
  XCTAssertEqual(newTotalFramesCount, initialTotalFramesCount + 3);
}

/** Tests that if consecutive frames take more time to render than the frozen frames threshold, the
 *  frozen frame counter and slow frame counter of the screen trace tracker is incremented.
 */
- (void)testFrozenFrameAndSlowFrameIsRecorded {
  CFAbsoluteTime firstFrameRenderTimestamp = 1.0;
  CFAbsoluteTime secondFrameRenderTimestamp =
      firstFrameRenderTimestamp + kFPRFrozenFrameThreshold + 0.005;  // Buffer for float comparison.

  id displayLinkMock = OCMClassMock([CADisplayLink class]);
  [self.tracker.displayLink invalidate];
  self.tracker.displayLink = displayLinkMock;

  // Set/Reset the previousFrameTimestamp if it has been set by a previous test.
  OCMExpect([displayLinkMock timestamp]).andReturn(firstFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t initialSlowFramesCount = self.tracker.slowFramesCount;
  int64_t initialFrozenFramesCount = self.tracker.frozenFramesCount;

  OCMExpect([displayLinkMock timestamp]).andReturn(secondFrameRenderTimestamp);
  [self.tracker displayLinkStep];
  int64_t newSlowFramesCount = self.tracker.slowFramesCount;
  int64_t newFrozenFramesCount = self.tracker.frozenFramesCount;

  XCTAssertEqual(newFrozenFramesCount, initialFrozenFramesCount + 1);
  XCTAssertEqual(newSlowFramesCount, initialSlowFramesCount + 1);
}

/** Tests that the correct number of slow, frozen and total frames are recorded when all 3 are
 *  present.
 */
- (void)testTraceHasCorrectFrozenSlowAndTotalFrameMetricsWhenThoseFramesAreRecorded {
  int64_t initialTotalFramesCount = self.tracker.totalFramesCount;
  int64_t initialFrozenFramesCount = self.tracker.frozenFramesCount;
  int64_t initialSlowFramesCount = self.tracker.slowFramesCount;

  int64_t expectedTotalFramesOnTrace = 5;
  int64_t expectedSlowFramesOnTrace = 3;
  int64_t expectedFrozenFramesOnTrace = 1;

  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];

  self.tracker.totalFramesCount = initialTotalFramesCount + expectedTotalFramesOnTrace;
  self.tracker.slowFramesCount = initialSlowFramesCount + expectedSlowFramesOnTrace;
  self.tracker.frozenFramesCount = initialFrozenFramesCount + expectedFrozenFramesOnTrace;

  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual([createdTrace valueForIntMetric:kFPRSlowFrameCounterName],
                 expectedSlowFramesOnTrace);
  XCTAssertEqual([createdTrace valueForIntMetric:kFPRFrozenFrameCounterName],
                 expectedFrozenFramesOnTrace);
  XCTAssertEqual([createdTrace valueForIntMetric:kFPRTotalFramesCounterName],
                 expectedTotalFramesOnTrace);
}

/** Tests that if just total and slow frame and no frozen frames are recorded, then the frozen
 *  frames metric is not present on the trace. */
- (void)testTraceHasJustSlowAndTotalFrameMetricsWhenNoFrozenFramesAreRecorded {
  int64_t initialTotalFramesCount = self.tracker.totalFramesCount;
  int64_t initialFrozenFramesCount = self.tracker.frozenFramesCount;
  int64_t initialSlowFramesCount = self.tracker.slowFramesCount;

  int64_t expectedTotalFramesOnTrace = 5;
  int64_t expectedSlowFramesOnTrace = 3;
  int64_t expectedFrozenFramesOnTrace = 0;

  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];

  self.tracker.totalFramesCount = initialTotalFramesCount + expectedTotalFramesOnTrace;
  self.tracker.slowFramesCount = initialSlowFramesCount + expectedSlowFramesOnTrace;
  self.tracker.frozenFramesCount = initialFrozenFramesCount + expectedFrozenFramesOnTrace;

  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual([createdTrace valueForIntMetric:kFPRSlowFrameCounterName],
                 expectedSlowFramesOnTrace);
  XCTAssertEqual([createdTrace valueForIntMetric:kFPRTotalFramesCounterName],
                 expectedTotalFramesOnTrace);
  XCTAssertNil(createdTrace.counters[kFPRFrozenFrameCounterName]);
  XCTAssertEqual(createdTrace.counters.count, 2);
}

/** Tests that when no frozen or slow frames are recorded, the trace only has the total frames
 *  counter.
 */
- (void)testTraceHasJustTotalFrameMetricsWhenNoFrozenOrSlowFramesAreRecorded {
  int64_t initialTotalFramesCount = self.tracker.totalFramesCount;
  int64_t initialFrozenFramesCount = self.tracker.frozenFramesCount;
  int64_t initialSlowFramesCount = self.tracker.slowFramesCount;

  int64_t expectedTotalFramesOnTrace = 5;
  int64_t expectedSlowFramesOnTrace = 0;
  int64_t expectedFrozenFramesOnTrace = 0;

  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];

  self.tracker.totalFramesCount = initialTotalFramesCount + expectedTotalFramesOnTrace;
  self.tracker.slowFramesCount = initialSlowFramesCount + expectedSlowFramesOnTrace;
  self.tracker.frozenFramesCount = initialFrozenFramesCount + expectedFrozenFramesOnTrace;

  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual([createdTrace valueForIntMetric:kFPRTotalFramesCounterName],
                 expectedTotalFramesOnTrace);
  XCTAssertNil(createdTrace.counters[kFPRSlowFrameCounterName]);
  XCTAssertNil(createdTrace.counters[kFPRFrozenFrameCounterName]);
  XCTAssertEqual(createdTrace.counters.count, 1);
}

/** Tests that if no frames are recorded between a trace being started and stopped, it doesn't have
 *  any metrics associated with it.
 */
- (void)testTraceHasNoMetricsWhenNoFramesAreRecorded {
  UIViewController *testViewController = FPRCustomViewController(@"UIViewController", YES);
  [self.tracker viewControllerDidAppear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  FIRTrace *createdTrace = [self.tracker.activeScreenTraces objectForKey:testViewController];

  [self.tracker viewControllerDidDisappear:testViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(createdTrace.counters.count, 0);
}

/** Tests that screen traces are NOT created for container view controllers. */
- (void)testScreenTracesAreNotCreatedForContainerViewControllers {
  UINavigationController *testNavigationController =
      (UINavigationController *)FPRCustomViewController(@"UINavigationController", YES);

  UITabBarController *testTabBarController =
      (UITabBarController *)FPRCustomViewController(@"UITabBarController", YES);

  UISplitViewController *testSplitViewController =
      (UISplitViewController *)FPRCustomViewController(@"UISplitViewController", YES);

  UIPageViewController *testPageViewController =
      (UIPageViewController *)FPRCustomViewController(@"UIPageViewController", YES);

  [self.tracker viewControllerDidAppear:testNavigationController];
  [self.tracker viewControllerDidAppear:testTabBarController];
  [self.tracker viewControllerDidAppear:testSplitViewController];
  [self.tracker viewControllerDidAppear:testPageViewController];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.activeScreenTraces.count, 0);
}

/** Tests that screen traces are created for canonical container view controller subclasses. */
- (void)testScreenTracesAreCreatedForContainerViewControllerSubclasses {
  FPRTestNavigationViewController *testNavigationControllerSubclass =
      (FPRTestNavigationViewController *)FPRCustomViewController(@"FPRTestNavigationViewController",
                                                                 YES);

  FPRTestTabBarController *testTabBarControllerSubclass =
      (FPRTestTabBarController *)FPRCustomViewController(@"FPRTestTabBarController", YES);

  FPRTestSplitViewController *testSplitViewControllerSubclass =
      (FPRTestSplitViewController *)FPRCustomViewController(@"FPRTestSplitViewController", YES);

  FPRTestPageViewController *testPageViewControllerSubclass =
      (FPRTestPageViewController *)FPRCustomViewController(@"FPRTestPageViewController", YES);

  [self.tracker viewControllerDidAppear:testNavigationControllerSubclass];
  [self.tracker viewControllerDidAppear:testTabBarControllerSubclass];
  [self.tracker viewControllerDidAppear:testSplitViewControllerSubclass];
  [self.tracker viewControllerDidAppear:testPageViewControllerSubclass];
  dispatch_group_wait(self.dispatchGroupToWaitOn, DISPATCH_TIME_FOREVER);

  XCTAssertEqual(self.tracker.activeScreenTraces.count, 4);
}

#pragma mark - Helper methods

+ (NSString *)expectedTraceNameForViewController:(UIViewController *)viewController {
  return [@"_st_" stringByAppendingString:NSStringFromClass([viewController class])];
}

@end
