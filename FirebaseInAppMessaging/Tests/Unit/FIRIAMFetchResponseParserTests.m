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

  XCTAssertEqual(3, [results count]);
  XCTAssertEqual(0, discardCount);

  // First is a test message and the second one is not.
  XCTAssertTrue(results[0].isTestMessage);
  XCTAssertTrue(results[0].renderData.renderingEffectSettings.isTestMessage);
  XCTAssertNil(results[0].appData);

  XCTAssertFalse(results[1].isTestMessage);
  XCTAssertFalse(results[1].renderData.renderingEffectSettings.isTestMessage);

  XCTAssertTrue(results[2].isTestMessage);
  XCTAssertTrue(results[2].renderData.renderingEffectSettings.isTestMessage);
  XCTAssertEqual(results[2].appData.count, 2);
  XCTAssertEqualObjects(results[2].appData[@"a"], @"b");
  XCTAssertEqualObjects(results[2].appData[@"c"], @"d");
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

- (void)testParsingMalformedMessageNodes {
  NSString *testJsonDataFilePath = [[NSBundle bundleForClass:[self class]]
      pathForResource:@"JsonDataWithMalformedMessagesFromFetch"
               ofType:@"txt"];
  NSData *data = [NSData dataWithContentsOfFile:testJsonDataFilePath];
  XCTAssertNotNil(data);
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:nil];
  XCTAssertNotNil(responseDict);

  NSInteger discardCount;
  NSNumber *fetchWaitTime;
  NSArray<FIRIAMMessageDefinition *> *results =
      [self.parser parseAPIResponseDictionary:responseDict
                            discardedMsgCount:&discardCount
                       fetchWaitTimeInSeconds:&fetchWaitTime];

  XCTAssertNil(fetchWaitTime);
  XCTAssertEqual(2, results.count);
  XCTAssertEqual(12, discardCount);

  // Every parsed value that is later used as a string must actually be a string.
  for (FIRIAMMessageDefinition *definition in results) {
    XCTAssertTrue([definition.renderData.messageID isKindOfClass:[NSString class]]);
    XCTAssertTrue([definition.renderData.name isKindOfClass:[NSString class]]);
    XCTAssertTrue([definition.renderData.contentData.titleText isKindOfClass:[NSString class]]);
    for (FIRIAMDisplayTriggerDefinition *trigger in definition.renderTriggers) {
      if (trigger.triggerType == FIRIAMRenderTriggerOnFirebaseAnalyticsEvent) {
        XCTAssertTrue([trigger.firebaseEventName isKindOfClass:[NSString class]]);
        XCTAssertGreaterThan(trigger.firebaseEventName.length, 0);
      }
    }
  }

  FIRIAMMessageDefinition *valid = results[0];
  XCTAssertEqualObjects(@"valid_banner", valid.renderData.messageID);
  XCTAssertEqual(1, valid.renderTriggers.count);
  XCTAssertEqualObjects(@"valid_event", valid.renderTriggers[0].firebaseEventName);

  // Wrongly typed optional fields are dropped while the message itself is kept.
  FIRIAMMessageDefinition *optionalFields = results[1];
  XCTAssertEqualObjects(@"optional_fields_have_wrong_types", optionalFields.renderData.messageID);
  XCTAssertFalse(optionalFields.isTestMessage);
  XCTAssertEqualObjects(@"Valid title", optionalFields.renderData.contentData.titleText);
  XCTAssertNil(optionalFields.renderData.contentData.bodyText);
  XCTAssertNil(optionalFields.renderData.contentData.actionButtonText);
  XCTAssertNil(optionalFields.renderData.contentData.imageURL);
  XCTAssertNil(optionalFields.renderData.contentData.actionURL);
  XCTAssertNil(optionalFields.experimentPayload);
  XCTAssertNil(optionalFields.appData);
  XCTAssertEqual(1, optionalFields.renderTriggers.count);
  XCTAssertEqualObjects(@"valid_event_2", optionalFields.renderTriggers[0].firebaseEventName);
}

- (void)testParsingNonDictionaryResponse {
  NSArray *malformedResponses = @[ @[ @1, @2 ], @"response", @42, [NSNull null] ];
  for (id response in malformedResponses) {
    NSInteger discardCount = -1;
    NSNumber *fetchWaitTime = @1;
    NSArray<FIRIAMMessageDefinition *> *results =
        [self.parser parseAPIResponseDictionary:response
                              discardedMsgCount:&discardCount
                         fetchWaitTimeInSeconds:&fetchWaitTime];
    XCTAssertNil(results, @"%@", response);
    XCTAssertNil(fetchWaitTime, @"%@", response);
  }
}

- (void)testParsingNonArrayMessagesNode {
  NSArray *malformedMessages =
      @[ @"messages", @42, [NSNull null], @{@"campaignId" : @"not in an array"} ];
  for (id messages in malformedMessages) {
    NSInteger discardCount = 0;
    NSNumber *fetchWaitTime;
    NSArray<FIRIAMMessageDefinition *> *results =
        [self.parser parseAPIResponseDictionary:@{@"messages" : messages}
                              discardedMsgCount:&discardCount
                         fetchWaitTimeInSeconds:&fetchWaitTime];
    XCTAssertNil(results, @"%@", messages);
  }
}

- (void)testParsingEmptyResponse {
  NSInteger discardCount = -1;
  NSNumber *fetchWaitTime;
  NSArray<FIRIAMMessageDefinition *> *results =
      [self.parser parseAPIResponseDictionary:@{}
                            discardedMsgCount:&discardCount
                       fetchWaitTimeInSeconds:&fetchWaitTime];
  XCTAssertNotNil(results);
  XCTAssertEqual(0, results.count);
  XCTAssertEqual(0, discardCount);
  XCTAssertNil(fetchWaitTime);
}

- (void)testParsingInvalidFetchExpirationTime {
  NSTimeInterval currentMoment = 100000000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  NSArray *invalidExpirations = @[ @"-1000", @"garbage", @"nan", @"", [NSNull null], @[] ];
  for (id expiration in invalidExpirations) {
    NSInteger discardCount;
    NSNumber *fetchWaitTime;
    NSArray<FIRIAMMessageDefinition *> *results =
        [self.parser parseAPIResponseDictionary:@{@"expirationEpochTimestampMillis" : expiration}
                              discardedMsgCount:&discardCount
                         fetchWaitTimeInSeconds:&fetchWaitTime];
    XCTAssertNotNil(results, @"%@", expiration);
    XCTAssertNil(fetchWaitTime, @"%@", expiration);
  }
}

- (void)testParsingWrongTypedIntermediateContentNodes {
  // Intermediate nodes (title/body/action/button) that are not dictionaries should only drop the
  // fields beneath them, not discard the whole message via an unrecognized selector exception.
  NSDictionary *payload = @{@"campaignId" : @"c1", @"campaignName" : @"name"};
  NSArray *triggers = @[ @{@"fiamTrigger" : @"ON_FOREGROUND"} ];
  NSDictionary *responseDict = @{
    @"messages" : @[
      @{
        @"vanillaPayload" : payload,
        @"triggeringConditions" : triggers,
        @"content" : @{
          @"modal" : @{
            @"title" : @{@"text" : @"Modal title"},
            @"body" : [NSNull null],
            @"actionButton" : @{@"text" : @"not a dictionary", @"buttonHexColor" : @5},
            @"action" : @"not a dictionary",
          }
        }
      },
      @{
        @"vanillaPayload" : payload,
        @"triggeringConditions" : triggers,
        @"content" : @{
          @"card" : @{
            @"title" : @{@"text" : @"Card title", @"hexColor" : [NSNull null]},
            @"body" : @[ @"array" ],
            @"primaryActionButton" : @42,
            @"secondaryActionButton" : @{@"text" : [NSNull null]},
            @"primaryAction" : [NSNull null],
            @"secondaryAction" : @"not a dictionary",
          }
        }
      },
      @{
        @"vanillaPayload" : payload,
        @"triggeringConditions" : triggers,
        @"content" : @{
          @"banner" : @{
            @"title" : @"not a dictionary",
          }
        }
      },
    ]
  };

  NSInteger discardCount = -1;
  NSNumber *fetchWaitTime;
  NSArray<FIRIAMMessageDefinition *> *results =
      [self.parser parseAPIResponseDictionary:responseDict
                            discardedMsgCount:&discardCount
                       fetchWaitTimeInSeconds:&fetchWaitTime];

  // The banner is discarded because its (required) title is missing, not because of an exception.
  XCTAssertEqual(2, results.count);
  XCTAssertEqual(1, discardCount);

  id<FIRIAMMessageContentData> modal = results[0].renderData.contentData;
  XCTAssertEqualObjects(@"Modal title", modal.titleText);
  XCTAssertNil(modal.bodyText);
  XCTAssertNil(modal.actionButtonText);
  XCTAssertNil(modal.actionURL);

  id<FIRIAMMessageContentData> card = results[1].renderData.contentData;
  XCTAssertEqualObjects(@"Card title", card.titleText);
  XCTAssertNil(card.bodyText);
  XCTAssertNil(card.actionButtonText);
  XCTAssertNil(card.secondaryActionButtonText);
  XCTAssertNil(card.actionURL);
  XCTAssertNil(card.secondaryActionURL);
}

@end
