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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "Interop/Analytics/Public/FIRInteropEventNames.h"
#import "Interop/Analytics/Public/FIRInteropParameterNames.h"

#import "FirebaseMessaging/Sources/FIRMessagingAnalytics.h"

// Analytics tracking is iOS only feature.
#if TARGET_OS_IOS
static NSString *const kFIRParameterLabel = @"label";
static NSString *const kReengagementSource = @"Firebase";
static NSString *const kReengagementMedium = @"notification";
static NSString *const kFIREventOriginFCM = @"fcm";
static const NSTimeInterval kAsyncTestTimeout = 0.5;

typedef void (^FakeAnalyticsLogEventHandler)(NSString *origin,
                                             NSString *name,
                                             NSDictionary *parameters);
typedef void (^FakeAnalyticsUserPropertyHandler)(NSString *origin, NSString *name, id value);

@interface FakeAnalytics : NSObject <FIRAnalyticsInterop>

- (instancetype)initWithEventHandler:(FakeAnalyticsLogEventHandler)eventHandler;
- (instancetype)initWithUserPropertyHandler:(FakeAnalyticsUserPropertyHandler)userPropertyHandler;

@end

@implementation FakeAnalytics

static FakeAnalyticsLogEventHandler _eventHandler;
static FakeAnalyticsLogEventHandler _userPropertyHandler;

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

// Stubs
- (void)clearConditionalUserProperty:(nonnull NSString *)userPropertyName
                      clearEventName:(nonnull NSString *)clearEventName
                clearEventParameters:(nonnull NSDictionary *)clearEventParameters {
}

- (NSInteger)maxUserProperties:(nonnull NSString *)origin {
  return -1;
}

- (void)checkLastNotificationForOrigin:(nonnull NSString *)origin
                                 queue:(nonnull dispatch_queue_t)queue
                              callback:(nonnull void (^)(NSString *_Nullable))
                                           currentLastNotificationProperty {
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

@interface FIRMessagingAnalytics (ExposedForTest)
+ (BOOL)canLogNotification:(NSDictionary *)notification;
+ (NSMutableDictionary *)paramsForEvent:(NSString *)event
                       withNotification:(NSDictionary *)notification;
+ (void)logAnalyticsEventWithOrigin:(NSString *)origin
                               name:(NSString *)name
                         parameters:(NSDictionary *)params
                        toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics;
+ (void)logUserPropertyForConversionTracking:(NSDictionary *)notification
                                 toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics;
+ (void)logOpenNotification:(NSDictionary *)notification
                toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics;
+ (void)logForegroundNotification:(NSDictionary *)notification
                      toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics;
+ (void)logEvent:(NSString *)event
    withNotification:(NSDictionary *)notification
         toAnalytics:(id<FIRAnalyticsInterop> _Nullable)analytics;
;
+ (BOOL)isDisplayNotification:(NSDictionary *)notification;

@end

@interface FIRMessagingAnalyticsTest : XCTestCase

@property(nonatomic, readwrite, strong) id logClassMock;

@end

@implementation FIRMessagingAnalyticsTest

- (void)setUp {
  [super setUp];
  self.logClassMock = OCMClassMock([FIRMessagingAnalytics class]);
}

- (void)tearDown {
  _eventHandler = nil;
  _userPropertyHandler = nil;
  [self.logClassMock stopMocking];
  [super tearDown];
}

- (void)testCanLogNotification {
  NSDictionary *notification = @{};
  XCTAssertFalse([FIRMessagingAnalytics canLogNotification:notification]);

  notification = @{@"google.c.a.e" : @1};
  XCTAssertFalse([FIRMessagingAnalytics canLogNotification:notification]);

  notification = @{@"aps" : @{@"alert" : @"to check the reporting format"}};
  XCTAssertFalse([FIRMessagingAnalytics canLogNotification:notification]);

  notification = @{@"aps" : @{@"alert" : @"to check the reporting format"}, @"google.c.a.e" : @"0"};
  XCTAssertFalse([FIRMessagingAnalytics canLogNotification:notification]);

  notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"gcm.n.e" : @"1",
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.e" : @"1",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0"
  };
  XCTAssertTrue([FIRMessagingAnalytics canLogNotification:notification]);

  notification = @{
    @"aps" : @{@"content-available" : @"1"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"google.c.a.e" : @"1",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0"
  };
  XCTAssertTrue([FIRMessagingAnalytics canLogNotification:notification]);
}

- (void)testEmptyNotification {
  NSMutableDictionary *params = [FIRMessagingAnalytics paramsForEvent:@"" withNotification:@{}];
  XCTAssertNil(params);
}

- (void)testNoParamsIfAnalyticsIsNotEnabled {
  NSDictionary *notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"gcm.n.e" : @"1",
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0"
  };

  NSMutableDictionary *params = [FIRMessagingAnalytics paramsForEvent:@""
                                                     withNotification:notification];
  XCTAssertNil(params);
}

- (void)testNoParamsIfEmpty {
  NSDictionary *notification = @{
    @"google.c.a.e" : @"1",
  };
  NSMutableDictionary *params = [FIRMessagingAnalytics paramsForEvent:@""
                                                     withNotification:notification];
  XCTAssertNotNil(params);

  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithEventHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertEqualObjects(origin, kFIREventOriginFCM);
        XCTAssertEqualObjects(name, @"_cmp");
        XCTAssertEqual([parameters count], 0);
        [expectation fulfill];
      }];
  [FIRMessagingAnalytics logEvent:kFIRIEventFirebaseCampaign
                 withNotification:notification
                      toAnalytics:analytics];
  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}
- (void)testParamForEventAndNotification {
  NSDictionary *notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"gcm.n.e" : @"1",
    @"google.c.a.c_l" : @"Hello World",
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.e" : @"1",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0",
    @"google.c.a.m_l" : @"developer's customized label",
    @"from" : @"/topics/news",
  };

  NSMutableDictionary *params = [FIRMessagingAnalytics paramsForEvent:kFIRIEventNotificationOpen
                                                     withNotification:notification];
  XCTAssertNotNil(params);
  XCTAssertEqualObjects(params[kFIRIParameterMessageIdentifier], @"575315420755741863");
  XCTAssertEqualObjects(params[kFIRIParameterMessageName], @"Hello World");
  XCTAssertEqualObjects(params[kFIRParameterLabel], @"developer's customized label");
  XCTAssertEqualObjects(params[kFIRIParameterTopic], @"/topics/news");
  XCTAssertEqualObjects([params[kFIRIParameterMessageTime] stringValue], @"1522880044");
  XCTAssertEqualObjects(params[kFIRIParameterMessageDeviceTime], @"0");
}

- (void)testInvalidDataInParamsForLogging {
  NSString *composerIdentifier = @"Hellow World";
  NSDictionary *notification = @{
    @"google.c.a.e" : @(YES),
    @"google.c.a.c_l" : composerIdentifier,
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.ts" : @"1522880044",
    @"from" : @"/topics/news",
    @"google.c.a.udt" : @"0",
  };
  NSMutableDictionary *params = [FIRMessagingAnalytics paramsForEvent:kFIRIEventNotificationOpen
                                                     withNotification:notification];
  XCTAssertNil(params);

  notification = @{
    @"google.c.a.e" : @"1",
    @"google.c.a.c_l" : [composerIdentifier dataUsingEncoding:NSUTF8StringEncoding],
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.ts" : @"1522880044",
    @"from" : @"/topics/news",
    @"google.c.a.udt" : @"0",
  };
  params = [FIRMessagingAnalytics paramsForEvent:kFIRIEventNotificationOpen
                                withNotification:notification];
  XCTAssertNil(params[kFIRIParameterMessageName]);
  XCTAssertEqualObjects(params[kFIRIParameterMessageIdentifier], @"575315420755741863");
  XCTAssertEqualObjects(params[kFIRIParameterTopic], @"/topics/news");

  notification = @{
    @"google.c.a.e" : @"1",
    @"google.c.a.c_l" : composerIdentifier,
    @"google.c.a.c_id" : @(575315420755741863),
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.ts" : @"1522880044",
    @"from" : @"/topics/news",
    @"google.c.a.udt" : @"0",
  };
  params = [FIRMessagingAnalytics paramsForEvent:kFIRIEventNotificationOpen
                                withNotification:notification];
  XCTAssertEqualObjects(params[kFIRIParameterMessageName], composerIdentifier);
  XCTAssertNil(params[kFIRIParameterMessageIdentifier]);
  XCTAssertEqualObjects(params[kFIRIParameterTopic], @"/topics/news");

  notification = @{
    @"google.c.a.e" : @"1",
    @"google.c.a.c_l" : composerIdentifier,
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.ts" : @"0",
    @"from" : @"/topics/news",
    @"google.c.a.udt" : @"12345678",
  };
  params = [FIRMessagingAnalytics paramsForEvent:kFIRIEventNotificationOpen
                                withNotification:notification];
  XCTAssertEqualObjects(params[kFIRIParameterMessageName], composerIdentifier);
  XCTAssertEqualObjects(params[kFIRIParameterMessageIdentifier], @"575315420755741863");
  XCTAssertEqualObjects(params[kFIRParameterLabel], @"developer's customized label");
  XCTAssertEqualObjects(params[kFIRIParameterTopic], @"/topics/news");
  XCTAssertNil(params[kFIRIParameterMessageTime]);
  XCTAssertEqualObjects(params[kFIRIParameterMessageDeviceTime], @"12345678");

  notification = @{
    @"google.c.a.e" : @"1",
    @"google.c.a.c_l" : composerIdentifier,
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.ts" : @(0),
    @"from" : @"/topics/news",
    @"google.c.a.udt" : @"12345678",
  };
  params = [FIRMessagingAnalytics paramsForEvent:kFIRIEventNotificationOpen
                                withNotification:notification];
  XCTAssertEqualObjects(params[kFIRIParameterMessageName], composerIdentifier);
  XCTAssertNil(params[kFIRIParameterMessageTime]);
  XCTAssertEqualObjects(params[kFIRIParameterMessageDeviceTime], @"12345678");
}

- (void)testConversionTracking {
  // Notification contains "google.c.a.tc" key.
  NSDictionary *notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"gcm.n.e" : @"1",
    @"google.c.a.c_l" : @"Hello World",
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.e" : @"1",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0",
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.tc" : @"1",
    @"from" : @"/topics/news",
  };
  NSDictionary *params = @{
    kFIRIParameterSource : kReengagementSource,
    kFIRIParameterMedium : kReengagementMedium,
    kFIRIParameterCampaign : @"575315420755741863"
  };
  __block XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithEventHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertEqualObjects(origin, kFIREventOriginFCM);
        XCTAssertEqualObjects(name, @"_cmp");
        XCTAssertEqualObjects(parameters, params);
        [expectation fulfill];
        expectation = nil;
      }];
  [FIRMessagingAnalytics logUserPropertyForConversionTracking:notification toAnalytics:analytics];
  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

- (void)testConversionTrackingUserProperty {
  // Notification contains "google.c.a.tc" key.
  NSDictionary *notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"gcm.n.e" : @"1",
    @"google.c.a.c_l" : @"Hello World",
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.e" : @"1",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0",
    @"google.c.a.m_l" : @"developer's customized label",
    @"google.c.a.tc" : @"1",
    @"from" : @"/topics/news",
  };

  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];
  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithUserPropertyHandler:^(NSString *origin, NSString *name, id value) {
        XCTAssertEqualObjects(origin, kFIREventOriginFCM);
        XCTAssertEqualObjects(name, @"_ln");
        XCTAssertEqualObjects(value, @"575315420755741863");
        [expectation fulfill];
      }];
  [FIRMessagingAnalytics logUserPropertyForConversionTracking:notification toAnalytics:analytics];
  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

- (void)testNoConversionTracking {
  // Notification contains "google.c.a.tc" key.
  NSDictionary *notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
    @"gcm.message_id" : @"0:1522880049414338%944841cd944841cd",
    @"gcm.n.e" : @"1",
    @"google.c.a.c_l" : @"Hello World",
    @"google.c.a.c_id" : @"575315420755741863",
    @"google.c.a.e" : @"1",
    @"google.c.a.ts" : @"1522880044",
    @"google.c.a.udt" : @"0",
    @"google.c.a.m_l" : @"developer's customized label",
    @"from" : @"/topics/news",
  };
  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithEventHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertTrue(NO);
      }];
  [FIRMessagingAnalytics logUserPropertyForConversionTracking:notification toAnalytics:analytics];
}

#if !SWIFT_PACKAGE
// This test depends on a sharedApplication which is not available in the Swift PM test env.
- (void)testLogMessage {
  NSDictionary *notification = @{
    @"google.c.a.e" : @"1",
    @"aps" : @{@"alert" : @"to check the reporting format"},
  };
  [FIRMessagingAnalytics logMessage:notification toAnalytics:nil];
  OCMVerify([self.logClassMock logEvent:OCMOCK_ANY withNotification:notification toAnalytics:nil]);
}
#endif

- (void)testLogOpenNotification {
  NSDictionary *notification = @{
    @"google.c.a.e" : @"1",
    @"aps" : @{@"alert" : @"to check the reporting format"},
  };
  [FIRMessagingAnalytics logOpenNotification:notification toAnalytics:nil];

  OCMVerify([self.logClassMock logUserPropertyForConversionTracking:notification toAnalytics:nil]);
  OCMVerify([self.logClassMock logEvent:kFIRIEventNotificationOpen
                       withNotification:notification
                            toAnalytics:nil]);
}

- (void)testDisplayNotification {
  NSDictionary *notification = @{
    @"google.c.a.e" : @"1",
  };
  XCTAssertFalse([FIRMessagingAnalytics isDisplayNotification:notification]);

  notification = @{
    @"aps" : @{@"alert" : @"to check the reporting format"},
  };
  XCTAssertTrue([FIRMessagingAnalytics isDisplayNotification:notification]);

  notification = @{
    @"google.c.a.e" : @"1",
    @"aps" : @{@"alert" : @{@"title" : @"Hello World"}},
  };
  XCTAssertTrue([FIRMessagingAnalytics isDisplayNotification:notification]);

  notification = @{
    @"google.c.a.e" : @"1",
    @"aps" : @{@"alert" : @{@"body" : @"This is the body of notification."}},
  };
  XCTAssertTrue([FIRMessagingAnalytics isDisplayNotification:notification]);

  notification = @{
    @"google.c.a.e" : @"1",
    @"aps" :
        @{@"alert" : @{@"title" : @"Hello World", @"body" : @"This is the body of notification."}},
  };
  XCTAssertTrue([FIRMessagingAnalytics isDisplayNotification:notification]);

  notification = @{
    @"google.c.a.e" : @"1",
    @"aps" : @{@"alert" : @{@"subtitle" : @"Hello World"}},
  };
  XCTAssertTrue([FIRMessagingAnalytics isDisplayNotification:notification]);
}
@end

#endif  // TARGET_OS_IOS
