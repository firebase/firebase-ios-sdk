/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

#import "FirebaseCore/Sources/FIRAnalyticsConfiguration.h"

@interface FIRAnalyticsConfigurationTest : FIRTestCase

@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation FIRAnalyticsConfigurationTest

- (void)setUp {
  [super setUp];

  _notificationCenter = [NSNotificationCenter defaultCenter];
}

- (void)tearDown {
  _notificationCenter = nil;

  [super tearDown];
}

/// Test access to the shared instance.
- (void)testSharedInstance {
  FIRAnalyticsConfiguration *analyticsConfig = [FIRAnalyticsConfiguration sharedInstance];
  XCTAssertNotNil(analyticsConfig);
}

- (void)testSettingAnalyticsCollectionPersistence {
  id userDefaultsMock = OCMPartialMock([NSUserDefaults standardUserDefaults]);
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];

  // Test that defaults are written to when persistence is enabled.
  [config setAnalyticsCollectionEnabled:YES persistSetting:YES];
  OCMVerify([userDefaultsMock setObject:[NSNumber numberWithInteger:kFIRAnalyticsEnabledStateSetYes]
                                 forKey:kFIRAPersistedConfigMeasurementEnabledStateKey]);

  [config setAnalyticsCollectionEnabled:NO persistSetting:YES];
  OCMVerify([userDefaultsMock setObject:[NSNumber numberWithInteger:kFIRAnalyticsEnabledStateSetNo]
                                 forKey:kFIRAPersistedConfigMeasurementEnabledStateKey]);

  // Test that defaults are not written to when persistence is disabled.
  [config setAnalyticsCollectionEnabled:YES persistSetting:NO];
  OCMReject([userDefaultsMock setObject:OCMOCK_ANY
                                 forKey:kFIRAPersistedConfigMeasurementEnabledStateKey]);

  [config setAnalyticsCollectionEnabled:NO persistSetting:NO];
  OCMReject([userDefaultsMock setObject:OCMOCK_ANY
                                 forKey:kFIRAPersistedConfigMeasurementEnabledStateKey]);

  [userDefaultsMock stopMocking];
}

@end
