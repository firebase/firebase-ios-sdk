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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FirebaseDynamicLinks/Sources/FIRDLScionLogging.h"

static const NSTimeInterval kAsyncTestTimeout = 0.5;

typedef void (^FakeAnalyticsLogEventWithOriginNameParametersHandler)(NSString *origin,
                                                                     NSString *name,
                                                                     NSDictionary *parameters);

@interface FakeAnalytics : NSObject <FIRAnalyticsInterop>

- (instancetype)initWithHandler:(FakeAnalyticsLogEventWithOriginNameParametersHandler)handler;

@end

@implementation FakeAnalytics

static FakeAnalyticsLogEventWithOriginNameParametersHandler _handler;

- (instancetype)initWithHandler:(FakeAnalyticsLogEventWithOriginNameParametersHandler)handler {
  self = [super init];
  if (self) {
    _handler = handler;
  }
  return self;
}

- (void)logEventWithOrigin:(nonnull NSString *)origin
                      name:(nonnull NSString *)name
                parameters:(nullable NSDictionary<NSString *, id> *)parameters {
  if (_handler) {
    _handler(origin, name, parameters);
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

- (void)setUserPropertyWithOrigin:(nonnull NSString *)origin
                             name:(nonnull NSString *)name
                            value:(nonnull id)value {
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

@interface FIRDLScionLoggingTest : XCTestCase
@end

@implementation FIRDLScionLoggingTest

- (void)testGINLogEventToScionCallsLogMethodWithFirstOpen {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        [expectation fulfill];
      }];

  FIRDLLogEventToScion(FIRDLLogEventFirstOpen, nil, nil, nil, analytics);
  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

- (void)testGINLogEventToScionContainsCorrectNameWithFirstOpen {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertEqualObjects(name, @"dynamic_link_first_open", @"scion name param was incorrect");
        [expectation fulfill];
      }];

  FIRDLLogEventToScion(FIRDLLogEventFirstOpen, nil, nil, nil, analytics);
  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

- (void)testGINLogEventToScionCallsLogMethodWithAppOpen {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        [expectation fulfill];
      }];
  FIRDLLogEventToScion(FIRDLLogEventAppOpen, nil, nil, nil, analytics);

  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

- (void)testGINLogEventToScionContainsCorrectNameWithAppOpen {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithHandler:^(NSString *origin, NSString *name, NSDictionary *parameters) {
        XCTAssertEqualObjects(name, @"dynamic_link_app_open", @"scion name param was incorrect");
        [expectation fulfill];
      }];
  FIRDLLogEventToScion(FIRDLLogEventAppOpen, nil, nil, nil, analytics);

  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

- (void)testGINLogEventToScionLogsParametersCorrectly {
  NSString *source = @"9-2nkg";
  NSString *medium = @"fjg0";
  NSString *campaign = @"gjoo3u5";

  NSString *sourceKey = @"source";
  NSString *mediumKey = @"medium";
  NSString *campaignKey = @"campaign";

  XCTestExpectation *expectation = [self expectationWithDescription:@"completion"];

  FakeAnalytics *analytics = [[FakeAnalytics alloc]
      initWithHandler:^(NSString *origin, NSString *name, NSDictionary *params) {
        XCTAssertEqualObjects(params[sourceKey], source, @"scion logger has incorrect source.");
        XCTAssertEqualObjects(params[mediumKey], medium, @"scion logger has incorrect medium.");
        XCTAssertEqualObjects(params[campaignKey], campaign,
                              @"scion logger has incorrect campaign.");
        [expectation fulfill];
      }];

  FIRDLLogEventToScion(FIRDLLogEventAppOpen, source, medium, campaign, analytics);

  [self waitForExpectationsWithTimeout:kAsyncTestTimeout handler:nil];
}

@end
