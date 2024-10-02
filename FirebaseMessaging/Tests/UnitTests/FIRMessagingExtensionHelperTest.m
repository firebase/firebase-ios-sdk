/*
 * Copyright 2019 Google
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

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessagingExtensionHelper.h"

API_AVAILABLE(macos(10.14), ios(10.0), watchos(3.0))
typedef void (^FIRMessagingContentHandler)(UNNotificationContent *content);

#if !TARGET_OS_TV
static NSString *const kFCMPayloadOptionsName = @"fcm_options";
static NSString *const kFCMPayloadOptionsImageURLName = @"image";
static NSString *const kValidImageURL =
    @"https://firebasestorage.googleapis.com/v0/b/fcm-ios-f7f9c.appspot.com/o/"
    @"chubbyBunny.jpg?alt=media&token=d6c56a57-c007-4b27-b20f-f267cc83e9e5";

@interface FIRMessagingExtensionHelper (ExposedForTest)

- (void)loadAttachmentForURL:(NSURL *)attachmentURL
           completionHandler:(void (^)(UNNotificationAttachment *))completionHandler;
+ (NSString *)bundleIdentifierByRemovingLastPartFrom:(NSString *)bundleIdentifier;
- (NSString *)fileExtensionForResponse:(NSURLResponse *)response;
@end

@interface FIRMessagingExtensionHelperTest : XCTestCase {
  id _mockExtensionHelper;
  id _mockUtilClass;
  id _mockURLResponse;
}
@end

@implementation FIRMessagingExtensionHelperTest

- (void)setUp {
  [super setUp];
  if (@available(macOS 10.14, iOS 10.0, watchos 3.0, *)) {
    FIRMessagingExtensionHelper *extensionHelper = [FIRMessaging extensionHelper];
    _mockExtensionHelper = OCMPartialMock(extensionHelper);
    _mockUtilClass = OCMClassMock([GULAppEnvironmentUtil class]);
    _mockURLResponse = OCMClassMock([NSURLResponse class]);
  } else {
    // Fallback on earlier versions
  }
}

- (void)tearDown {
  [_mockExtensionHelper stopMocking];
  [_mockUtilClass stopMocking];
  [_mockURLResponse stopMocking];
}

#ifdef COCOAPODS
// This test requires internet access.
- (void)testModifyNotificationWithValidPayloadData {
  if (@available(macOS 10.14, iOS 10.0, watchos 3.0, *)) {
    XCTestExpectation *validPayloadExpectation =
        [self expectationWithDescription:@"Test payload is valid."];
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo =
        @{kFCMPayloadOptionsName : @{kFCMPayloadOptionsImageURLName : kValidImageURL}};
    FIRMessagingContentHandler handler = ^(UNNotificationContent *content) {
      [validPayloadExpectation fulfill];
    };
    [_mockExtensionHelper populateNotificationContent:content withContentHandler:handler];
    OCMVerify([_mockExtensionHelper loadAttachmentForURL:[OCMArg any]
                                       completionHandler:[OCMArg any]]);
    // Wait longer to accommodate increased network latency when running on CI.
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
  }
}
#endif  // COCOAPODS

- (void)testModifyNotificationWithInvalidPayloadData {
  if (@available(macOS 10.14, iOS 10.0, watchos 3.0, *)) {
    XCTestExpectation *validPayloadExpectation =
        [self expectationWithDescription:@"Test payload is valid."];
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo =
        @{kFCMPayloadOptionsName : @{kFCMPayloadOptionsImageURLName : @"a invalid URL"}};
    FIRMessagingContentHandler handler = ^(UNNotificationContent *content) {
      [validPayloadExpectation fulfill];
    };
    [_mockExtensionHelper populateNotificationContent:content withContentHandler:handler];

    OCMReject([_mockExtensionHelper loadAttachmentForURL:[OCMArg any]
                                       completionHandler:[OCMArg any]]);
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
  }
}

- (void)testModifyNotificationWithEmptyPayloadData {
  if (@available(macOS 10.14, iOS 10.0, watchos 3.0, *)) {
    XCTestExpectation *validPayloadExpectation =
        [self expectationWithDescription:@"Test payload is valid."];
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.userInfo =
        @{kFCMPayloadOptionsName : @{kFCMPayloadOptionsImageURLName : @"a invalid URL"}};
    FIRMessagingContentHandler handler = ^(UNNotificationContent *content) {
      [validPayloadExpectation fulfill];
    };
    [_mockExtensionHelper populateNotificationContent:content withContentHandler:handler];
    OCMReject([_mockExtensionHelper loadAttachmentForURL:[OCMArg any]
                                       completionHandler:[OCMArg any]]);
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
  }
}

- (void)testModifyNotificationWithValidPayloadDataNoMimeType {
  if (@available(macOS 10.14, iOS 10.0, *)) {
    NSString *const kValidTestURL = @"test.jpg";
    NSString *const kValidTestExtension = @".jpg";
    OCMStub([_mockURLResponse suggestedFilename]).andReturn(kValidTestURL);
    NSString *const extension = [_mockExtensionHelper fileExtensionForResponse:_mockURLResponse];
    XCTAssertTrue([extension isEqualToString:kValidTestExtension]);
  }
}

- (void)testModifyNotificationWithInvalidPayloadDataInvalidMimeType {
  if (@available(macOS 10.14, iOS 10.0, *)) {
    NSString *const kInvalidTestURL = @"test";
    NSString *const kInvalidTestExtension = @"";
    OCMStub([_mockURLResponse suggestedFilename]).andReturn(kInvalidTestURL);
    OCMStub([_mockURLResponse MIMEType]).andReturn(nil);
    NSString *const extension = [_mockExtensionHelper fileExtensionForResponse:_mockURLResponse];
    XCTAssertTrue([extension isEqualToString:kInvalidTestExtension]);
  }
}

- (void)testModifyNotificationWithInvalidPayloadDataValidMimeType {
  if (@available(macOS 10.14, iOS 10.0, *)) {
    NSString *const kValidMIMETypeTestURL = @"test";
    NSString *const kValidMIMETypeTestMIMEType = @"image/jpeg";
    NSString *const kValidMIMETypeTestExtension = @".jpeg";
    OCMStub([_mockURLResponse suggestedFilename]).andReturn(kValidMIMETypeTestURL);
    OCMStub([_mockURLResponse MIMEType]).andReturn(kValidMIMETypeTestMIMEType);
    NSString *const extension = [_mockExtensionHelper fileExtensionForResponse:_mockURLResponse];
    XCTAssertTrue([extension isEqualToString:kValidMIMETypeTestExtension]);
  }
}

- (void)testDeliveryMetricsLoggingWithEmptyPayload {
  OCMStub([_mockUtilClass isAppExtension]).andReturn(YES);
  NSDictionary *fakeMessageInfo = @{@"aps" : @{}};

  OCMReject([_mockExtensionHelper bundleIdentifierByRemovingLastPartFrom:[OCMArg any]]);
  [_mockExtensionHelper exportDeliveryMetricsToBigQueryWithMessageInfo:fakeMessageInfo];
  OCMVerifyAll(_mockExtensionHelper);
}

- (void)testDeliveryMetricsLoggingWithInvalidMessageID {
  OCMStub([_mockUtilClass isAppExtension]).andReturn(YES);
  NSDictionary *fakeMessageInfo = @{
    @"aps" : @{@"badge" : @9, @"mutable-content" : @1},
    @"fcm_options" : @{@"image" : @"https://google.com"},
    @"google.c.fid" : @"fakeFIDForTest",
    @"google.c.sender.id" : @123456789
  };
  OCMReject([_mockExtensionHelper bundleIdentifierByRemovingLastPartFrom:[OCMArg any]]);
  [_mockExtensionHelper exportDeliveryMetricsToBigQueryWithMessageInfo:fakeMessageInfo];
  OCMVerifyAll(_mockExtensionHelper);
}

- (void)testDeliveryMetricsLoggingWithInvalidFID {
  OCMStub([_mockUtilClass isAppExtension]).andReturn(YES);
  NSDictionary *fakeMessageInfo = @{
    @"aps" : @{@"badge" : @9, @"mutable-content" : @1},
    @"fcm_options" : @{@"image" : @"https://google.com"},
    @"google.c.sender.id" : @123456789
  };
  OCMReject([_mockExtensionHelper bundleIdentifierByRemovingLastPartFrom:[OCMArg any]]);
  [_mockExtensionHelper exportDeliveryMetricsToBigQueryWithMessageInfo:fakeMessageInfo];
  OCMVerifyAll(_mockExtensionHelper);
}

- (void)testDeliveryMetricsLoggingWithDisplayPayload {
  OCMStub([_mockUtilClass isAppExtension]).andReturn(YES);
  NSDictionary *fakeMessageInfo = @{
    @"aps" : @{@"badge" : @9, @"mutable-content" : @1},
    @"fcm_options" : @{@"image" : @"https://google.com"},
    @"gcm.message_id" : @"1627428480762269",
    @"google.c.fid" : @"fakeFIDForTest",
    @"google.c.sender.id" : @123456789
  };
  OCMExpect([_mockExtensionHelper bundleIdentifierByRemovingLastPartFrom:[OCMArg any]]);
  [_mockExtensionHelper exportDeliveryMetricsToBigQueryWithMessageInfo:fakeMessageInfo];
  OCMVerifyAll(_mockExtensionHelper);
}

- (void)testDeliveryMetricsLoggingWithDataPayload {
  OCMStub([_mockUtilClass isAppExtension]).andReturn(NO);
  NSDictionary *fakeMessageInfo = @{
    @"aps" : @{@"badge" : @9, @"content-available" : @1},
    @"fcm_options" : @{@"image" : @"https://google.com"},
    @"gcm.message_id" : @"1627428480762269",
    @"google.c.fid" : @"fakeFIDForTest",
    @"google.c.sender.id" : @123456789
  };
  OCMReject([_mockExtensionHelper bundleIdentifierByRemovingLastPartFrom:[OCMArg any]]);
  [_mockExtensionHelper exportDeliveryMetricsToBigQueryWithMessageInfo:fakeMessageInfo];
  OCMVerifyAll(_mockExtensionHelper);
}

@end

#endif  // !TARGET_OS_TV
