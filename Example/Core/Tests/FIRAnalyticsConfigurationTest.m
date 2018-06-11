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

#import "FIRTestCase.h"

#import <FirebaseCore/FIRAnalyticsConfiguration+Internal.h>
#import <FirebaseCore/FIRAnalyticsConfiguration.h>

@interface FIRAnalyticsConfigurationTest : FIRTestCase
/// A mock for [NSNotificationCenter defaultCenter].
@property(nonatomic, strong) id notificationCenterMock;
@end

@implementation FIRAnalyticsConfigurationTest

- (void)setUp {
  [super setUp];
  _notificationCenterMock = OCMPartialMock([NSNotificationCenter defaultCenter]);
}

- (void)tearDown {
  [_notificationCenterMock stopMocking];
  [super tearDown];
}

/// Test access to the shared instance.
- (void)testSharedInstance {
  FIRAnalyticsConfiguration *analyticsConfig = [FIRAnalyticsConfiguration sharedInstance];
  XCTAssertNotNil(analyticsConfig);
}

/// Test that setting the minimum session interval on the singleton fires a notification.
- (void)testMinimumSessionIntervalNotification {
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];
  [config setMinimumSessionInterval:2601];
  NSString *notificationName = kFIRAnalyticsConfigurationSetMinimumSessionIntervalNotification;
  OCMVerify([self.notificationCenterMock postNotificationName:notificationName
                                                       object:config
                                                     userInfo:@{
                                                       notificationName : @2601
                                                     }]);
}

/// Test that setting the minimum session timeout interval on the singleton fires a notification.
- (void)testSessionTimeoutIntervalNotification {
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];
  [config setSessionTimeoutInterval:1000];
  NSString *notificationName = kFIRAnalyticsConfigurationSetSessionTimeoutIntervalNotification;
  OCMVerify([self.notificationCenterMock postNotificationName:notificationName
                                                       object:config
                                                     userInfo:@{
                                                       notificationName : @1000
                                                     }]);
}

- (void)testSettingAnalyticsCollectionEnabled {
  // The ordering matters for these notifications.
  [self.notificationCenterMock setExpectationOrderMatters:YES];

  // Test setting to enabled.
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];
  NSString *notificationName = kFIRAnalyticsConfigurationSetEnabledNotification;
  [config setAnalyticsCollectionEnabled:YES];
  OCMVerify([self.notificationCenterMock postNotificationName:notificationName
                                                       object:config
                                                     userInfo:@{
                                                       notificationName : @YES
                                                     }]);

  // Test setting to disabled.
  [config setAnalyticsCollectionEnabled:NO];
  OCMVerify([self.notificationCenterMock postNotificationName:notificationName
                                                       object:config
                                                     userInfo:@{
                                                       notificationName : @NO
                                                     }]);
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
