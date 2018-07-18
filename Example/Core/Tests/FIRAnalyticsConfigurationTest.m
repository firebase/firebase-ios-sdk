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
/// An observer for NSNotificationCenter.
@property(nonatomic, strong) id observerMock;

@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@end

@implementation FIRAnalyticsConfigurationTest

- (void)setUp {
  [super setUp];

  _observerMock = OCMObserverMock();
  _notificationCenter = [NSNotificationCenter defaultCenter];
}

- (void)tearDown {
  _observerMock = nil;
  _notificationCenter = nil;

  [super tearDown];
}

/// Test access to the shared instance.
- (void)testSharedInstance {
  FIRAnalyticsConfiguration *analyticsConfig = [FIRAnalyticsConfiguration sharedInstance];
  XCTAssertNotNil(analyticsConfig);
}

/// Test that setting the minimum session interval on the singleton fires a notification.
- (void)testMinimumSessionIntervalNotification {
  // Pick a value to set as the session interval and verify it's in the userInfo dictionary of the
  // posted notification.
  NSNumber *sessionInterval = @2601;

  // Set up the expectation for the notification.
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];
  NSString *notificationName = kFIRAnalyticsConfigurationSetMinimumSessionIntervalNotification;
  [self expectNotificationForObserver:self.observerMock
                     notificationName:notificationName
                               object:config
                             userInfo:@{notificationName : sessionInterval}];

  // Trigger the notification.
  [config setMinimumSessionInterval:[sessionInterval integerValue]];

  // Verify the observer mock.
  OCMVerifyAll(self.observerMock);
}

/// Test that setting the minimum session timeout interval on the singleton fires a notification.
- (void)testSessionTimeoutIntervalNotification {
  // Pick a value to set as the timeout interval and verify it's in the userInfo dictionary of the
  // posted notification.
  NSNumber *timeoutInterval = @1000;

  // Set up the expectation for the notification.
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];
  NSString *notificationName = kFIRAnalyticsConfigurationSetSessionTimeoutIntervalNotification;
  [self expectNotificationForObserver:self.observerMock
                     notificationName:notificationName
                               object:config
                             userInfo:@{notificationName : timeoutInterval}];

  // Trigger the notification.
  [config setSessionTimeoutInterval:[timeoutInterval integerValue]];

  /// Verify the observer mock.
  OCMVerifyAll(self.observerMock);
}

- (void)testSettingAnalyticsCollectionEnabled {
  // Test setting to enabled. The ordering matters for these notifications.
  FIRAnalyticsConfiguration *config = [FIRAnalyticsConfiguration sharedInstance];
  NSString *notificationName = kFIRAnalyticsConfigurationSetEnabledNotification;
  [self.notificationCenter addMockObserver:self.observerMock name:notificationName object:config];

  [self.observerMock setExpectationOrderMatters:YES];
  [[self.observerMock expect] notificationWithName:notificationName
                                            object:config
                                          userInfo:@{
                                            notificationName : @YES
                                          }];

  // Test setting to enabled.
  [config setAnalyticsCollectionEnabled:YES];

  // Expect the second notification.
  [[self.observerMock expect] notificationWithName:notificationName
                                            object:config
                                          userInfo:@{
                                            notificationName : @NO
                                          }];

  // Test setting to disabled.
  [config setAnalyticsCollectionEnabled:NO];

  OCMVerifyAll(self.observerMock);
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

#pragma mark - Private Test Helpers

- (void)expectNotificationForObserver:(id)observer
                     notificationName:(NSNotificationName)name
                               object:(nullable id)object
                             userInfo:(nullable NSDictionary *)userInfo {
  [self.notificationCenter addMockObserver:self.observerMock name:name object:object];
  [[observer expect] notificationWithName:name object:object userInfo:userInfo];
}

@end
