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

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/AppActivity/FPRAppActivityTracker.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"

#import "FirebaseCore/Sources/Private/FIRAppInternal.h"

#import <OCMock/OCMock.h>

@interface FPRAppActivityTrackerTest : FPRTestCase

@end

@interface FPRAppActivityTracker (Tests)

@property(nonatomic) FPRConfigurations *configurations;
+ (BOOL)isPrewarmAvailable;
- (BOOL)isAppStartEnabled;
- (BOOL)isActivePrewarmEnabled;
- (BOOL)isDoubleDispatchEnabled;
- (BOOL)isApplicationPreWarmed;

@end

@implementation FPRAppActivityTrackerTest

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
}

/** Validates if the instance was successfully created. */
- (void)testInstanceCreation {
  XCTAssertNotNil([FPRAppActivityTracker sharedInstance]);
  XCTAssertEqualObjects([FPRAppActivityTracker sharedInstance],
                        [FPRAppActivityTracker sharedInstance]);
}

/** Validates if an active trace is available when the app is active. */
- (void)testActiveTrace {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertNotNil([FPRAppActivityTracker sharedInstance].activeTrace);
}

/** Validates no active trace is available when data collection is disabled. */
- (void)testActiveTraceWhenDataCollectionDisabled {
  BOOL dataCollectionEnabled = [FIRPerformance sharedInstance].dataCollectionEnabled;
  [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertNil([FPRAppActivityTracker sharedInstance].activeTrace);
  [[FIRPerformance sharedInstance] setDataCollectionEnabled:dataCollectionEnabled];
}

/** Validates if the active trace changes across launch of application from foreground to background
 * and then background to foreground.
 */
- (void)testActiveTraceChanging {
  FIRTrace *activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];

  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];

  FIRTrace *newActiveTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertNotEqual(activeTrace, newActiveTrace);
}

/** Validates if the active trace changes across launch of application from foreground to
 *  background.
 */
- (void)testActiveTraceWhenAppChangesStates {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

  FIRTrace *activeTrace = nil;
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertEqual(activeTrace.name, kFPRAppTraceNameBackgroundSession);

  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertEqual(activeTrace.name, kFPRAppTraceNameForegroundSession);
}

/** Validates if the active trace is nil when data collection is toggled.
 */
- (void)testActiveTraceIsNilWhenAppChangesStatesAndDataCollectionToggledFromEnabled {
  BOOL dataCollectionEnabled = [FIRPerformance sharedInstance].dataCollectionEnabled;

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

  FIRTrace *activeTrace = nil;
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertEqual(activeTrace.name, kFPRAppTraceNameBackgroundSession);

  [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];

  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertNil(activeTrace);

  [[FIRPerformance sharedInstance] setDataCollectionEnabled:YES];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertEqual(activeTrace.name, kFPRAppTraceNameBackgroundSession);

  [FIRPerformance sharedInstance].dataCollectionEnabled = dataCollectionEnabled;
}

/** Validates if the active trace is nil when data collection is toggled.
 */
- (void)testActiveTraceIsNilWhenAppChangesStatesAndDataCollectionToggledFromDisabled {
  BOOL dataCollectionEnabled = [FIRPerformance sharedInstance].dataCollectionEnabled;
  [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];

  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

  FIRTrace *activeTrace = nil;
  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertNil(activeTrace);

  [[FIRPerformance sharedInstance] setDataCollectionEnabled:YES];

  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertNotNil(activeTrace);

  [[FIRPerformance sharedInstance] setDataCollectionEnabled:NO];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  activeTrace = [FPRAppActivityTracker sharedInstance].activeTrace;
  XCTAssertNil(activeTrace);

  [FIRPerformance sharedInstance].dataCollectionEnabled = dataCollectionEnabled;
}

/** Validates if the application state is managed correctly. */
- (void)testApplicationStateManagement {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

  [defaultCenter postNotificationName:UIWindowDidBecomeVisibleNotification
                               object:[UIApplication sharedApplication]];
  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertEqual(appTracker.applicationState, FPRApplicationStateBackground);

  [defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertEqual(appTracker.applicationState, FPRApplicationStateForeground);

  [defaultCenter postNotificationName:UIApplicationWillResignActiveNotification
                               object:[UIApplication sharedApplication]];
  XCTAssertEqual(appTracker.applicationState, FPRApplicationStateBackground);
}

- (void)testIsApplicationPrewarmedReturnsYesBecauseOfDoubleDispatch {
  id mockAppTracker = OCMPartialMock([FPRAppActivityTracker sharedInstance]);
  OCMStub([mockAppTracker isPrewarmAvailable]).andReturn(YES);
  OCMStub([mockAppTracker isDoubleDispatchEnabled]).andReturn(YES);
  OCMStub([mockAppTracker isActivePrewarmEnabled]).andReturn(NO);

  [FPRAppActivityTracker load];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidFinishLaunchingNotification
                    object:[UIApplication sharedApplication]];

  XCTAssertTrue([mockAppTracker isApplicationPreWarmed]);
}

- (void)testIsApplicationPrewarmedReturnsNoBecauseOfDoubleDispatch {
  id mockAppTracker = OCMPartialMock([FPRAppActivityTracker sharedInstance]);
  OCMStub([mockAppTracker isPrewarmAvailable]).andReturn(YES);
  OCMStub([mockAppTracker isDoubleDispatchEnabled]).andReturn(YES);
  OCMStub([mockAppTracker isActivePrewarmEnabled]).andReturn(NO);

  [[NSNotificationCenter defaultCenter]
      postNotificationName:UIApplicationDidFinishLaunchingNotification
                    object:[UIApplication sharedApplication]];
  [FPRAppActivityTracker load];

  XCTAssertFalse([mockAppTracker isApplicationPreWarmed]);
}

- (void)testIsApplicationPrewarmedReturnsYesBecauseOfActivePrewarm {
  id mockAppTracker = OCMPartialMock([FPRAppActivityTracker sharedInstance]);
  OCMStub([mockAppTracker isPrewarmAvailable]).andReturn(YES);
  OCMStub([mockAppTracker isDoubleDispatchEnabled]).andReturn(NO);
  OCMStub([mockAppTracker isActivePrewarmEnabled]).andReturn(YES);

  setenv("ActivePrewarm", "1", 1);
  XCTAssertTrue([mockAppTracker isApplicationPreWarmed]);
}

- (void)testIsApplicationPrewarmedReturnsNoBecauseOfActivePrewarm {
  id mockAppTracker = OCMPartialMock([FPRAppActivityTracker sharedInstance]);
  OCMStub([mockAppTracker isPrewarmAvailable]).andReturn(YES);
  OCMStub([mockAppTracker isDoubleDispatchEnabled]).andReturn(NO);
  OCMStub([mockAppTracker isActivePrewarmEnabled]).andReturn(YES);

  XCTAssertFalse([mockAppTracker isApplicationPreWarmed]);
}

- (void)testIsAppStartEnabledObeysDropAllEventsRCFlag {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];

  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(DropAllEvents);
  appTracker.configurations = mockConfigurations;

  XCTAssertFalse([appTracker isApplicationPreWarmed]);
}

- (void)testIsAppStartEnabledObeysKeepAllEventsRCFlag {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];

  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(KeepAllEvents);
  appTracker.configurations = mockConfigurations;

  XCTAssertTrue([appTracker isAppStartEnabled]);
}

- (void)testIsActivePrewarmEnabledAndIsDoubleDispatchEnabledObeysOnlyActivePrewarmRCFlag {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];
  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  appTracker.configurations = mockConfigurations;

  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(OnlyActivePrewarm);
  XCTAssertTrue([appTracker isActivePrewarmEnabled]);
  XCTAssertFalse([appTracker isDoubleDispatchEnabled]);
}

- (void)testIsActivePrewarmEnabledAndIsDoubleDispatchEnabledObeysOnlyDoubleDispatchRCFlag {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];
  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  appTracker.configurations = mockConfigurations;

  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(OnlyDoubleDispatch);
  XCTAssertFalse([appTracker isActivePrewarmEnabled]);
  XCTAssertTrue([appTracker isDoubleDispatchEnabled]);
}

- (void)
    testIsActivePrewarmEnabledAndIsDoubleDispatchEnabledObeysEitherActivePrewarmOrDoubleDispatchRCFlag {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];
  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  appTracker.configurations = mockConfigurations;

  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(EitherActivePrewarmOrDoubleDispatch);
  XCTAssertTrue([appTracker isActivePrewarmEnabled]);
  XCTAssertTrue([appTracker isDoubleDispatchEnabled]);
}

@end
