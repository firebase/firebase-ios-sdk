/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMFetchResponseParser.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentDataWithImageURL.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/DisplayTrigger/FIRIAMDisplayTriggerDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"
#import "FirebaseInAppMessaging/Sources/Util/UIColor+FIRIAMHexString.h"

@interface FIRIAMFetchResponseParserTests : XCTestCase
@property(nonatomic, copy) NSString *jsonResponse;
@property(nonatomic) FIRIAMFetchResponseParser *parser;
@property(nonatomic) id<FIRIAMTimeFetcher> mockTimeFetcher;
@end

@implementation FIRIAMFetchResponseParserTests

- (void)setUp {
  [super setUp];
  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.parser = [[FIRIAMFetchResponseParser alloc] initWithTimeFetcher:self.mockTimeFetcher];
}
- (void)tearDown {
  [super tearDown];
}

- (void)testRegularConversion {
  NSString *testJsonDataFilePath =
      [[NSBundle bundleForClass:[self class]] pathForResource:@"TestJsonDataFromFetch"
                                                       ofType:@"txt"];

  NSTimeInterval currentMoment = 100000000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  self.jsonResponse = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];

  NSData *data = [self.jsonResponse dataUsingEncoding:NSUTF8StringEncoding];
  NSError *errorJson = nil;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&errorJson];

  NSInteger discardCount;
  NSNumber *fetchWaitTime;
  NSArray<FIRIAMMessageDefinition *> *results =
      [self.parser parseAPIResponseDictionary:responseDict
                            discardedMsgCount:&discardCount
                       fetchWaitTimeInSeconds:&fetchWaitTime];

  double nextFetchEpochTimeInResponse =
      [responseDict[@"expirationEpochTimestampMillis"] doubleValue];

  // Fetch wait time should be (next fetch epoch time - current moment).
  XCTAssertEqualWithAccuracy([fetchWaitTime doubleValue],
                             nextFetchEpochTimeInResponse / 1000 - currentMoment, 0.1);

  XCTAssertEqual(7, [results count]);
  XCTAssertEqual(0, discardCount);

  FIRIAMMessageDefinition *first = results[0];
  XCTAssertEqualObjects(@"13313766398414028800", first.renderData.messageID);
  XCTAssertEqualObjects(@"first campaign", first.renderData.name);
  XCTAssertEqualObjects(@"I heard you like In-App Messages",
                        first.renderData.contentData.titleText);
  XCTAssertEqualObjects(@"This is message body", first.renderData.contentData.bodyText);
  XCTAssertEqual(FIRIAMRenderAsModalView, first.renderData.renderingEffectSettings.viewMode);
  XCTAssertEqualWithAccuracy(1523986039, first.startTime, 0.1);
  XCTAssertEqualWithAccuracy(1526986039, first.endTime, 0.1);
  XCTAssertNotNil(first.renderData.renderingEffectSettings.textColor);
  XCTAssertEqualObjects(first.renderData.renderingEffectSettings.displayBGColor,
                        [UIColor firiam_colorWithHexString:@"#fffff8"]);
  XCTAssertEqualObjects(first.renderData.renderingEffectSettings.btnBGColor,
                        [UIColor firiam_colorWithHexString:@"#000000"]);
  XCTAssertEqualObjects(first.renderData.contentData.actionURL.absoluteString,
                        @"https://www.google.com");
  XCTAssertEqual(FIRIAMRenderTriggerOnAppForeground, first.renderTriggers[0].triggerType);
  XCTAssertEqual(first.appData.count, 2);
  XCTAssertEqualObjects(first.appData[@"a"], @"b");
  XCTAssertEqualObjects(first.appData[@"c"], @"d");

  FIRIAMMessageDefinition *second = results[1];
  XCTAssertEqualObjects(@"9350598726327992320", second.renderData.messageID);
  XCTAssertEqualObjects(@"Inception1", second.renderData.name);
  XCTAssertEqualObjects(@"Test 2", second.renderData.contentData.titleText);
  XCTAssertNil(second.renderData.contentData.bodyText);
  XCTAssertNil(second.appData);
  XCTAssertEqual(FIRIAMRenderAsModalView, second.renderData.renderingEffectSettings.viewMode);
  XCTAssertEqual(2, second.renderTriggers.count);

  XCTAssertEqualObjects(second.renderData.renderingEffectSettings.displayBGColor,
                        [UIColor firiam_colorWithHexString:@"#ffffff"]);

  // Third message is a banner view message based on an analytics event trigger.
  FIRIAMMessageDefinition *third = results[2];
  XCTAssertEqualObjects(@"14819094573862617088", third.renderData.messageID);
  XCTAssertEqual(FIRIAMRenderAsBannerView, third.renderData.renderingEffectSettings.viewMode);
  XCTAssertEqual(1, third.renderTriggers.count);
  XCTAssertEqualObjects(@"jackpot", third.renderTriggers[0].firebaseEventName);

  // Fifth message is a card view message based on an analytics event trigger.
  FIRIAMMessageDefinition *fifth = results[4];
  XCTAssertEqualObjects(@"5432869654332221", fifth.renderData.messageID);
  XCTAssertEqual(FIRIAMRenderAsCardView, fifth.renderData.renderingEffectSettings.viewMode);
  XCTAssertEqual(1, fifth.renderTriggers.count);
  XCTAssertEqual(FIRIAMRenderTriggerOnAppForeground, fifth.renderTriggers[0].triggerType);
  XCTAssertEqualObjects(@"Super Bowl LIV", fifth.renderData.name);
  XCTAssertEqualObjects(@"Eagles are going to win", fifth.renderData.contentData.titleText);
  XCTAssertEqualObjects(@"Start of a dynasty.", fifth.renderData.contentData.bodyText);
  XCTAssertEqualObjects(@"https://image.com/birds.png",
                        fifth.renderData.contentData.imageURL.absoluteString);
  XCTAssertEqualObjects(@"https://image.com/ls_birds.png",
                        fifth.renderData.contentData.landscapeImageURL.absoluteString);
  XCTAssertEqualObjects(@"https://www.google.com",
                        fifth.renderData.contentData.actionURL.absoluteString);
  XCTAssertEqualObjects(@"Win Super Bowl LIV", fifth.renderData.contentData.actionButtonText);
  XCTAssertEqualObjects(@"https://www.google.com",
                        fifth.renderData.contentData.secondaryActionURL.absoluteString);
  XCTAssertEqualObjects(@"Win Super Bowl LV",
                        fifth.renderData.contentData.secondaryActionButtonText);

  FIRIAMMessageDefinition *sixth = results[5];
  XCTAssertEqualObjects(@"687787988989", sixth.renderData.messageID);
  XCTAssertEqualObjects(@"Super Bowl LV", sixth.renderData.name);
  XCTAssertEqualObjects(@"Eagles are going to win", sixth.renderData.contentData.titleText);
  XCTAssertEqualObjects(sixth.renderData.renderingEffectSettings.btnTextColor,
                        [UIColor firiam_colorWithHexString:@"#1a0dab"]);
  XCTAssertNil(sixth.renderData.contentData.bodyText);
  XCTAssertNil(sixth.appData);
  XCTAssertNotNil(sixth.experimentPayload);
  XCTAssertEqual(FIRIAMRenderAsModalView, sixth.renderData.renderingEffectSettings.viewMode);
  XCTAssertEqual(1, sixth.renderTriggers.count);

  FIRIAMMessageDefinition *seventh = results[6];
  XCTAssertEqualObjects(@"https://example.com/recoverable_image_url",
                        seventh.renderData.contentData.imageURL.absoluteString);
  XCTAssertEqualObjects(nil, seventh.renderData.contentData.landscapeImageURL.absoluteString);
  XCTAssertEqualObjects(@"http://example.com/recoverable_action_url_without_https",
                        seventh.renderData.contentData.actionURL.absoluteString);
  XCTAssertEqualObjects(nil, seventh.renderData.contentData.secondaryActionURL.absoluteString);
}

- (void)testParsingTestMessage {
  NSString *testJsonDataFilePath = [[NSBundle bundleForClass:[self class]]
      pathForResource:@"TestJsonDataWithTestMessageFromFetch"
               ofType:@"txt"];

  self.jsonResponse = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];

  NSData *data = [self.jsonResponse dataUsingEncoding:NSUTF8StringEncoding];
  NSError *errorJson = nil;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&errorJson];

  NSInteger discardCount;
  NSNumber *fetchWaitTime;
  NSArray<FIRIAMMessageDefinition *> *results =
      [self.parser parseAPIResponseDictionary:responseDict
                            discardedMsgCount:&discardCount
                       fetchWaitTimeInSeconds:&fetchWaitTime];

  // In our fixture file used in this test, there is no fetch expiration time
  XCTAssertNil(fetchWaitTime);

  XCTAssertEqual(2, [results count]);
  XCTAssertEqual(0, discardCount);

  // First is a test message and the second one is not.
  XCTAssertTrue(results[0].isTestMessage);
  XCTAssertTrue(results[0].renderData.renderingEffectSettings.isTestMessage);

  XCTAssertFalse(results[1].isTestMessage);
  XCTAssertFalse(results[1].renderData.renderingEffectSettings.isTestMessage);
}

- (void)testParsingInvalidTestMessageNodes {
  NSString *testJsonDataFilePath = [[NSBundle bundleForClass:[self class]]
      pathForResource:@"JsonDataWithInvalidMessagesFromFetch"
               ofType:@"txt"];

  self.jsonResponse = [[NSString alloc] initWithContentsOfFile:testJsonDataFilePath
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];

  NSData *data = [self.jsonResponse dataUsingEncoding:NSUTF8StringEncoding];
  NSError *errorJson = nil;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:&errorJson];

  NSInteger discardCount;
  NSNumber *fetchWaitTime;
  NSArray<FIRIAMMessageDefinition *> *results =
      [self.parser parseAPIResponseDictionary:responseDict
                            discardedMsgCount:&discardCount
                       fetchWaitTimeInSeconds:&fetchWaitTime];

  XCTAssertEqual(0, [results count]);

  // First node missing title, second one missig triggering conditions and the third one
  // contains invalid type node.
  XCTAssertEqual(3, discardCount);
}

@end
