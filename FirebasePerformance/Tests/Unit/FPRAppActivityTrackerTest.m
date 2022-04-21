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

#import "FirebaseCore/Extension/FIRAppInternal.h"

#import <OCMock/OCMock.h>

@interface FPRAppActivityTrackerTest : FPRTestCase

@end

@interface FPRAppActivityTracker (Tests)

@property(nonatomic) FPRConfigurations *configurations;
- (BOOL)isPrewarmAvailable;
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

/** Validates ActivePrewarm environment variable set to true is detected by prewarm-detection
 */
- (void)test_isApplicationPrewarmed_activePrewarm_returnsYes {
  id mockAppTracker = OCMPartialMock([FPRAppActivityTracker sharedInstance]);
  OCMStub([mockAppTracker isPrewarmAvailable]).andReturn(YES);
  OCMStub([mockAppTracker isActivePrewarmEnabled]).andReturn(YES);

  setenv("ActivePrewarm", "1", 1);
  [FPRAppActivityTracker load];
  XCTAssertTrue([mockAppTracker isApplicationPreWarmed]);
}

/** Validates when ActivePrewarm environment variable is not set, prewarm-detection returns false
 */
- (void)test_isApplicationPrewarmed_activePrewarm_returnsNo {
  id mockAppTracker = OCMPartialMock([FPRAppActivityTracker sharedInstance]);
  OCMStub([mockAppTracker isPrewarmAvailable]).andReturn(YES);
  OCMStub([mockAppTracker isActivePrewarmEnabled]).andReturn(YES);

  XCTAssertFalse([mockAppTracker isApplicationPreWarmed]);
}

/** Validates when RC flag fpr_prewarm_detection is PrewarmDetectionModeNone
 */
- (void)test_isAppStartEnabled_PrewarmDetectionModeKeepNone_returnsNo {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];

  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(PrewarmDetectionModeKeepNone);
  appTracker.configurations = mockConfigurations;

  XCTAssertFalse([appTracker isApplicationPreWarmed]);
}

/** Validates when RC flag fpr_prewarm_detection is PrewarmDetectionModeAll
 */
- (void)test_isAppStartEnabled_PrewarmDetectionModeKeepAll_returnsYes {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];

  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(PrewarmDetectionModeKeepAll);
  appTracker.configurations = mockConfigurations;

  XCTAssertTrue([appTracker isAppStartEnabled]);
}

/** Validates ActivePrewarm filtering is enabled when RC flag fpr_prewarm_detection is
 * PrewarmDetectionModeActivePrewarm
 */
- (void)test_isActivePrewarmEnabled_PrewarmDetectionModeActivePrewarm_returnsYes {
  FPRAppActivityTracker *appTracker = [FPRAppActivityTracker sharedInstance];
  id mockConfigurations = OCMClassMock([FPRConfigurations class]);
  appTracker.configurations = mockConfigurations;

  OCMStub([mockConfigurations prewarmDetectionMode]).andReturn(PrewarmDetectionModeActivePrewarm);
  XCTAssertTrue([appTracker isActivePrewarmEnabled]);
}

@end
