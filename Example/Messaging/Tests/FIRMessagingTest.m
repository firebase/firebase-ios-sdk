/*
 * Copyright 2017 Google
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

@import XCTest;

#import <OCMock/OCMock.h>

//#import "googlemac/iPhone/Firebase/ABTesting/Public/FIRExperimentController.h"
#import "FIRMessaging.h"
#import "FIRMessagingConfig.h"
#import "FIRMessagingConstants.h"
#import "FIRMessagingTestNotificationUtilities.h"

extern NSString * const kFIRMessagingABTExperimentPayloadKey;

@interface FIRMessaging ()

- (instancetype)initWithConfig:(FIRMessagingConfig *)config;
- (void)updateExperimentsIfNeededFromMessage:(NSDictionary *)message;
- (NSData *)abtExperimentPayloadFromMessage:(NSDictionary *)message;

@end

@interface FIRMessagingTest : XCTestCase

@property(nonatomic, readonly, strong) FIRMessaging *messaging;
@property(nonatomic, readwrite, strong) id mockMessaging;
@property(nonatomic, readwrite, strong) id mockExperimentsControllerClass;
//@property(nonatomic, readonly, strong) FIRExperimentController *localExperimentController;
@property(nonatomic, readonly, strong) id mockLocalExperimentController;

@end

@implementation FIRMessagingTest

- (void)setUp {
  [super setUp];
  FIRMessagingConfig *config = [FIRMessagingConfig defaultConfig];
  _messaging = [[FIRMessaging alloc] initWithConfig:config];
  _mockMessaging = OCMPartialMock(self.messaging);

//  _localExperimentController = [[FIRExperimentController alloc] init];
//  // Create a partial mock for a single instance of FIRExperimentController
//  _mockLocalExperimentController = OCMPartialMock(_localExperimentController);
//
//  _mockExperimentsControllerClass = OCMClassMock([FIRExperimentController class]);
//  // Update sharedInstance to always return our partial mock of FIRExperimentController
//  OCMStub([_mockExperimentsControllerClass sharedInstance]).
//      andReturn(_mockLocalExperimentController);
}

- (void)tearDown {
  _messaging = nil;
  _mockMessaging = nil;
  // Always call stopMocking on class mocks to
  // remove stubbing class methods
  // See: https://medium.com/@jasperkuperus/ocmock-tips-tricks-77b65c8f06d8
  [_mockExperimentsControllerClass stopMocking];
  _mockExperimentsControllerClass = nil;
  [_mockLocalExperimentController stopMocking];
  _mockLocalExperimentController = nil;
//  _localExperimentController = nil;
  [super tearDown];
}

#pragma mark - ABT Experiment Testing

// Tests whether we always check for ABT experiment payloads
- (void)testInspectionForABTExperimentsPayload {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  [self.mockMessaging appDidReceiveMessage:notification];
  OCMVerify([self.mockMessaging updateExperimentsIfNeededFromMessage:notification]);
}

- (void)testParsingNonExistentABTExperimentPayload {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  NSData *payload = [self.messaging abtExperimentPayloadFromMessage:notification];
  XCTAssertNil(payload);
}

- (void)testParsingEmptyStringABTExperimentPayload {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageABTExperimentPayloadKey] = @"";
  NSData *payload = [self.messaging abtExperimentPayloadFromMessage:notification];
  XCTAssertNil(payload);
}

- (void)testParsingNonStringABTExperimentPayload {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  notification[kFIRMessagingMessageABTExperimentPayloadKey] = @(5);
  NSData *payload = [self.messaging abtExperimentPayloadFromMessage:notification];
  XCTAssertNil(payload);
}

- (void)testParsingNonBase64StringABTExperimentPayload {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  NSString *nonBase64String = @"This is not Base64-encoded";
  notification[kFIRMessagingMessageABTExperimentPayloadKey] = nonBase64String;
  NSData *payload = [self.messaging abtExperimentPayloadFromMessage:notification];
  XCTAssertNil(payload);
}

- (void)testParsingBase64EncodedStringABTExperimentPayload {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  NSString *base64EncodedString = [self createValidBase64EncodedString];
  notification[kFIRMessagingMessageABTExperimentPayloadKey] = base64EncodedString;

  NSData *payload = [self.messaging abtExperimentPayloadFromMessage:notification];
  XCTAssertNotNil(payload);
}

#ifdef DISABLE_AB

- (void)testInvokingABTExperimentControllerIfABTExperimentPayloadExists {
  NSMutableDictionary *notification =
      [FIRMessagingTestNotificationUtilities createBasicNotificationWithUniqueMessageID];
  NSString *base64EncodedString = [self createValidBase64EncodedString];
  notification[kFIRMessagingMessageABTExperimentPayloadKey] = base64EncodedString;

  XCTestExpectation *abtExperimentControllerWasInvoked =
      [self expectationWithDescription:@"ABT Experiment Controller was invoked"];

  void (^fulfillBlock)(NSInvocation *) = ^(NSInvocation *invocation) {
    [abtExperimentControllerWasInvoked fulfill];
  };

  // In order to handle both reference and value-based params, declare the stub this way
  // See: http://www.catehuston.com/blog/2016/01/06/ocmock-and-values/
//  [[[[_mockLocalExperimentController stub] andDo:fulfillBlock] ignoringNonObjectArgs]
//      setExperimentWithServiceOrigin:[OCMArg any]
//                              events:[OCMArg any]
//                              policy:0
//                             payload:[OCMArg any]];
//
//  [self.mockMessaging appDidReceiveMessage:notification];
//  [self waitForExpectationsWithTimeout:4.0 handler:nil];
}
#endif

#pragma mark - Helpers

- (NSString *)createValidBase64EncodedString {
  NSString *plainString = @"This is Base64-encoded data";
  NSData *plainData = [plainString dataUsingEncoding:NSUTF8StringEncoding];
  NSString *base64EncodedString = [plainData base64EncodedStringWithOptions:0];
  return base64EncodedString;
}

@end
