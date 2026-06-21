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

#import <GoogleUtilities/GULUserDefaults.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMAnalyticsEventLoggerImpl.h"
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClearcutLogger.h"

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"
#import "Interop/Analytics/Public/FIRInteropEventNames.h"
#import "Interop/Analytics/Public/FIRInteropParameterNames.h"

@interface FIRIAMAnalyticsEventLoggerImplTests : XCTestCase
@property(nonatomic) FIRIAMClearcutLogger *mockClearcutLogger;
@property(nonatomic) id<FIRIAMTimeFetcher> mockTimeFetcher;
@property(nonatomic) id mockFirebaseAnalytics;
@property(nonatomic) GULUserDefaults *mockUserDefaults;

@end

static NSString *campaignID = @"campaign id";
static NSString *campaignName = @"campaign name";

typedef void (^FIRAUserPropertiesCallback)(NSDictionary *userProperties);

typedef void (^FakeAnalyticsLogEventHandler)(NSString *origin,
                                             NSString *name,
                                             NSDictionary *parameters);
typedef void (^FakeAnalyticsUserPropertyHandler)(NSString *origin, NSString *name, id value);
typedef void (^LastNotificationCallback)(NSString *);
typedef void (^FakeAnalyticsLastNotificationHandler)(NSString *origin, LastNotificationCallback);

@interface FakeAnalytics : NSObject <FIRAnalyticsInterop>

@property FakeAnalyticsLogEventHandler eventHandler;
@property FakeAnalyticsLogEventHandler userPropertyHandler;
@property FakeAnalyticsLastNotificationHandler lastNotificationHandler;

- (instancetype)initWithEventHandler:(FakeAnalyticsLogEventHandler)eventHandler;
- (instancetype)initWithUserPropertyHandler:(FakeAnalyticsUserPropertyHandler)userPropertyHandler;
@end

@implementation FakeAnalytics

- (instancetype)initWithEventHandler:(FakeAnalyticsLogEventHandler)eventHandler {
  self = [super init];
  if (self) {
    _eventHandler = eventHandler;
  }
  return self;
}

- (instancetype)initWithUserPropertyHandler:(FakeAnalyticsUserPropertyHandler)userPropertyHandler {
  self = [super init];
  if (self) {
    _userPropertyHandler = userPropertyHandler;
  }
  return self;
}

- (void)logEventWithOrigin:(nonnull NSString *)origin
                      name:(nonnull NSString *)name
                parameters:(nullable NSDictionary<NSString *, id> *)parameters {
  if (_eventHandler) {
    _eventHandler(origin, name, parameters);
  }
}

- (void)setUserPropertyWithOrigin:(nonnull NSString *)origin
                             name:(nonnull NSString *)name
                            value:(nonnull id)value {
  if (_userPropertyHandler) {
    _userPropertyHandler(origin, name, value);
  }
}

- (void)checkLastNotificationForOrigin:(nonnull NSString *)origin
                                 queue:(nonnull dispatch_queue_t)queue
                              callback:(nonnull void (^)(NSString *_Nullable))
                                           currentLastNotificationProperty {
  if (_lastNotificationHandler) {
    _lastNotificationHandler(origin, currentLastNotificationProperty);
  }
}

// Stubs
- (void)clearConditionalUserProperty:(nonnull NSString *)userPropertyName
                      clearEventName:(nonnull NSString *)clearEventName
                clearEventParameters:(nonnull NSDictionary *)clearEventParameters {
}

- (NSInteger)maxUserProperties:(nonnull NSString *)origin {
  return -1;
}

- (void)registerAnalyticsListener:(nonnull id<FIRAnalyticsInteropListener>)listener
                       withOrigin:(nonnull NSString *)origin {
}

- (void)unregisterAnalyticsListenerWithOrigin:(nonnull NSString *)origin {
}

- (void)clearConditionalUserProperty:(nonnull NSString *)userPropertyName
                           forOrigin:(nonnull NSString *)origin
                      clearEventName:(nonnull NSString *)clearEventName
                clearEventParameters:
                    (nonnull NSDictionary<NSString *, NSString *> *)clearEventParameters {
}

- (nonnull NSArray<NSDictionary<NSString *, NSString *> *> *)
    conditionalUserProperties:(nonnull NSString *)origin
           propertyNamePrefix:(nonnull NSString *)propertyNamePrefix {
  return nil;
}

- (void)setConditionalUserProperty:(nonnull NSDictionary<NSString *, id> *)conditionalUserProperty {
}

- (void)getUserPropertiesWithCallback:(nonnull FIRAInteropUserPropertiesCallback)callback {
}
@end

@implementation FIRIAMAnalyticsEventLoggerImplTests

- (void)setUp {
  [super setUp];
  self.mockClearcutLogger = OCMClassMock(FIRIAMClearcutLogger.class);
  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.mockUserDefaults = OCMClassMock(GULUserDefaults.class);
}

- (void)tearDown {
  [super tearDown];
}

- (void)testLogImpressionEvent {
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"Log to Analytics"];
  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithEventHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertEqualObjects(origin, @"fiam");
        XCTAssertEqualObjects(name, @"firebase_in_app_message_impression");
        XCTAssertEqual([parameters count], 3);
        XCTAssertNotNil(parameters);
        XCTAssertEqual(parameters[@"_nmid"], campaignID);
        XCTAssertEqual(parameters[@"_nmn"], campaignName);
        [expectation1 fulfill];
      }];
  FIRIAMAnalyticsEventLoggerImpl *logger =
      [[FIRIAMAnalyticsEventLoggerImpl alloc] initWithClearcutLogger:self.mockClearcutLogger
                                                    usingTimeFetcher:self.mockTimeFetcher
                                                   usingUserDefaults:nil
                                                           analytics:analytics];

  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  OCMExpect([self.mockClearcutLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventMessageImpression
                 forCampaignID:[OCMArg isEqual:campaignID]
              withCampaignName:[OCMArg isEqual:campaignName]
                 eventTimeInMs:[OCMArg isNil]
                    completion:([OCMArg invokeBlockWithArgs:@YES, nil])]);

  XCTestExpectation *expectation2 =
      [self expectationWithDescription:@"Completion Callback Triggered"];
  [logger logAnalyticsEventForType:FIRIAMAnalyticsEventMessageImpression
                     forCampaignID:campaignID
                  withCampaignName:campaignName
                     eventTimeInMs:nil
                        completion:^(BOOL success) {
                          [expectation2 fulfill];
                        }];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testLogActionEvent {
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"Log to Analytics"];
  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithEventHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertEqualObjects(origin, @"fiam");
        XCTAssertEqualObjects(name, @"firebase_in_app_message_action");
        XCTAssertEqual([parameters count], 3);
        XCTAssertNotNil(parameters);
        XCTAssertEqual(parameters[@"_nmid"], campaignID);
        XCTAssertEqual(parameters[@"_nmn"], campaignName);
        [expectation1 fulfill];
      }];

  FIRIAMAnalyticsEventLoggerImpl *logger =
      [[FIRIAMAnalyticsEventLoggerImpl alloc] initWithClearcutLogger:self.mockClearcutLogger
                                                    usingTimeFetcher:self.mockTimeFetcher
                                                   usingUserDefaults:self.mockUserDefaults
                                                           analytics:analytics];

  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  OCMExpect([self.mockClearcutLogger
      logAnalyticsEventForType:FIRIAMAnalyticsEventActionURLFollow
                 forCampaignID:[OCMArg isEqual:campaignID]
              withCampaignName:[OCMArg isEqual:campaignName]
                 eventTimeInMs:[OCMArg isNil]
                    completion:([OCMArg invokeBlockWithArgs:@YES, nil])]);

  XCTestExpectation *expectation2 =
      [self expectationWithDescription:@"Completion Callback Triggered"];

  [logger logAnalyticsEventForType:FIRIAMAnalyticsEventActionURLFollow
                     forCampaignID:campaignID
                  withCampaignName:campaignName
                     eventTimeInMs:nil
                        completion:^(BOOL success) {
                          [expectation2 fulfill];
                        }];

  [self waitForExpectationsWithTimeout:2.0 handler:nil];
  OCMVerifyAll((id)self.mockClearcutLogger);
}

@end
