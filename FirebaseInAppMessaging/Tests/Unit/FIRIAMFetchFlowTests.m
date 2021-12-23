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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentDataWithImageURL.h"
#import "FirebaseInAppMessaging/Sources/Private/DisplayTrigger/FIRIAMDisplayTriggerDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMAnalyticsEventLogger.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMFetchFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMSDKModeManager.h"
#import "FirebaseInAppMessaging/Sources/Public/FirebaseInAppMessaging/FIRInAppMessagingRendering.h"

@interface FIRIAMFetchFlow (Testing)
// Expose to verify that this gets called on initial app launch fetch.
- (void)checkForAppLaunchMessage;
@end

@interface FIRIAMFetchFlowTests : XCTestCase
@property(nonatomic) FIRIAMFetchSetting *fetchSetting;
@property FIRIAMMessageClientCache *clientMessageCache;
@property id<FIRIAMMessageFetcher> mockMessageFetcher;
@property id<FIRIAMBookKeeper> mockBookkeeper;
@property id<FIRIAMTimeFetcher> mockTimeFetcher;
@property FIRIAMFetchFlow *flow;
@property FIRIAMActivityLogger *activityLogger;
@property FIRIAMSDKModeManager *mockSDKModeManager;
@property FIRIAMDisplayExecutor *mockDisplayExecutor;

@property id<FIRIAMAnalyticsEventLogger> mockAnaltycisEventLogger;

// three pre-defined messages
@property FIRIAMMessageDefinition *m1, *m2, *m3;
@end

CGFloat FETCH_MIN_INTERVALS = 1;

@implementation FIRIAMFetchFlowTests
- (void)setupMessageTexture {
  // startTime, endTime here ensures messages with them are active
  NSTimeInterval activeStartTime = 0;
  NSTimeInterval activeEndTime = [[NSDate date] timeIntervalSince1970] + 10000;

  FIRIAMDisplayTriggerDefinition *triggerDefinition =
      [[FIRIAMDisplayTriggerDefinition alloc] initWithFirebaseAnalyticEvent:@"test_event"];

  FIRIAMMessageContentDataWithImageURL *m1ContentData =
      [[FIRIAMMessageContentDataWithImageURL alloc]
               initWithMessageTitle:@"m1 title"
                        messageBody:@"message body"
                   actionButtonText:nil
          secondaryActionButtonText:nil
                          actionURL:[NSURL URLWithString:@"http://google.com"]
                 secondaryActionURL:nil
                           imageURL:[NSURL URLWithString:@"https://unsplash.it/300/300"]
                  landscapeImageURL:nil
                    usingURLSession:nil];

  FIRIAMRenderingEffectSetting *renderSetting1 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting1.viewMode = FIRIAMRenderAsBannerView;

  FIRIAMMessageRenderData *renderData1 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m1"
                                             messageName:@"name"
                                             contentData:m1ContentData
                                         renderingEffect:renderSetting1];

  self.m1 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData1
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ triggerDefinition ]];

  FIRIAMMessageContentDataWithImageURL *m2ContentData =
      [[FIRIAMMessageContentDataWithImageURL alloc]
               initWithMessageTitle:@"m2 title"
                        messageBody:@"message body"
                   actionButtonText:nil
          secondaryActionButtonText:nil
                          actionURL:[NSURL URLWithString:@"http://google.com"]
                 secondaryActionURL:nil
                           imageURL:[NSURL URLWithString:@"https://unsplash.it/300/400"]
                  landscapeImageURL:nil
                    usingURLSession:nil];

  FIRIAMRenderingEffectSetting *renderSetting2 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting2.viewMode = FIRIAMRenderAsModalView;

  FIRIAMMessageRenderData *renderData2 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m2"
                                             messageName:@"name"
                                             contentData:m2ContentData
                                         renderingEffect:renderSetting2];

  self.m2 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData2
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ triggerDefinition ]];

  FIRIAMMessageContentDataWithImageURL *m3ContentData =
      [[FIRIAMMessageContentDataWithImageURL alloc]
               initWithMessageTitle:@"m3 title"
                        messageBody:@"message body"
                   actionButtonText:nil
          secondaryActionButtonText:nil
                          actionURL:[NSURL URLWithString:@"http://google.com"]
                 secondaryActionURL:nil
                           imageURL:[NSURL URLWithString:@"https://unsplash.it/400/300"]
                  landscapeImageURL:nil
                    usingURLSession:nil];

  FIRIAMRenderingEffectSetting *renderSetting3 =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting3.viewMode = FIRIAMRenderAsImageOnlyView;

  FIRIAMMessageRenderData *renderData3 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m3"
                                             messageName:@"name"
                                             contentData:m3ContentData
                                         renderingEffect:renderSetting3];

  self.m3 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData3
                                                      startTime:activeStartTime
                                                        endTime:activeEndTime
                                              triggerDefinition:@[ triggerDefinition ]];
}

- (void)setUp {
  [super setUp];
  [self setupMessageTexture];

  self.fetchSetting = [[FIRIAMFetchSetting alloc] init];
  self.fetchSetting.fetchMinIntervalInMinutes = FETCH_MIN_INTERVALS;
  self.mockMessageFetcher = OCMProtocolMock(@protocol(FIRIAMMessageFetcher));

  FIRIAMFetchResponseParser *parser =
      [[FIRIAMFetchResponseParser alloc] initWithTimeFetcher:[[FIRIAMTimerWithNSDate alloc] init]];

  self.clientMessageCache = [[FIRIAMMessageClientCache alloc] initWithBookkeeper:self.mockBookkeeper
                                                             usingResponseParser:parser];
  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.mockBookkeeper = OCMProtocolMock(@protocol(FIRIAMBookKeeper));
  self.activityLogger = OCMClassMock([FIRIAMActivityLogger class]);
  self.mockAnaltycisEventLogger = OCMProtocolMock(@protocol(FIRIAMAnalyticsEventLogger));

  self.mockSDKModeManager = OCMClassMock([FIRIAMSDKModeManager class]);

  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.mockDisplayExecutor = OCMClassMock([FIRIAMDisplayExecutor class]);

  self.flow = [[FIRIAMFetchFlow alloc] initWithSetting:self.fetchSetting
                                          messageCache:self.clientMessageCache
                                        messageFetcher:self.mockMessageFetcher
                                           timeFetcher:self.mockTimeFetcher
                                            bookKeeper:self.mockBookkeeper
                                        activityLogger:self.activityLogger
                                  analyticsEventLogger:self.mockAnaltycisEventLogger
                                  FIRIAMSDKModeManager:self.mockSDKModeManager
                                       displayExecutor:self.mockDisplayExecutor];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

// In happy path, the fetch is allowed and we are able to fetch two messages back
- (void)testHappyPath {
  OCMStub([self.mockBookkeeper lastFetchTime]).andReturn(0);

  // Set it up so that we already have impressions for m1 and m3
  FIRIAMImpressionRecord *impression1 =
      [[FIRIAMImpressionRecord alloc] initWithMessageID:self.m1.renderData.messageID
                                impressionTimeInSeconds:1233];

  FIRIAMImpressionRecord *impression2 = [[FIRIAMImpressionRecord alloc] initWithMessageID:@"m3"
                                                                  impressionTimeInSeconds:5678];

  NSArray<FIRIAMImpressionRecord *> *impressions = @[ impression1, impression2 ];
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(impressions);

  NSArray<FIRIAMMessageDefinition *> *fetchedMessages = @[ self.m1, self.m2 ];

  // 200 seconds is larger than fetch wait time which is 100 in this setup
  OCMStub([self.mockBookkeeper nextFetchWaitTime]).andReturn(100);
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(200);

  OCMStub([self.mockSDKModeManager currentMode]).andReturn(FIRIAMSDKModeRegular);

  NSNumber *fetchWaitTimeFromResponse = [NSNumber numberWithInt:2000];

  OCMStub([self.mockMessageFetcher
      fetchMessagesWithImpressionList:[OCMArg any]
                       withCompletion:([OCMArg invokeBlockWithArgs:fetchedMessages,
                                                                   fetchWaitTimeFromResponse,
                                                                   [NSNull null], [NSNull null],
                                                                   nil])]);
  [self.flow checkAndFetchForInitialAppLaunch:NO];

  // We expect m1 and m2 to be dumped into clientMessageCache.
  NSArray<FIRIAMMessageDefinition *> *foundMessages = [self.clientMessageCache allRegularMessages];
  XCTAssertEqual(2, foundMessages.count);
  XCTAssertEqualObjects(foundMessages[0].renderData.messageID, self.m1.renderData.messageID);
  XCTAssertEqualObjects(foundMessages[1].renderData.messageID, self.m2.renderData.messageID);

  // Verify that we record the new fetch with bookkeeper
  OCMVerify([self.mockBookkeeper recordNewFetchWithFetchCount:2
                                       withTimestampInSeconds:200
                                            nextFetchWaitTime:fetchWaitTimeFromResponse]);

  // So we are sending the request with impression for m1 and m3 and getting back messages for m1
  // and m2. In here m1 is a recurring message and after the fetch, we should call
  // book keeper's clearImpressionsWithMessageList: method with m1 which is an intersection
  // between the request impression list and the response message id list. We are skipping
  // m2 since it's not included in the impression records sent along with the request.
  OCMVerify(
      [self.mockBookkeeper clearImpressionsWithMessageList:@[ self.m1.renderData.messageID ]]);
}

// No fetch is to be performed if the required fetch interval is not met
- (void)testNoFetchDueToIntervalConstraint {
  OCMStub([self.mockSDKModeManager currentMode]).andReturn(FIRIAMSDKModeRegular);

  // We need to wait at least 300 seconds before making another fetch
  OCMStub([self.mockBookkeeper nextFetchWaitTime]).andReturn(300);

  // And it's only been 200 seconds since last fetch, so no fetch should happen
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(200);
  OCMStub([self.mockBookkeeper lastFetchTime]).andReturn(0);

  // We don't expect fetchMessages: for self.mockMessageFetcher to be triggred
  OCMReject([self.mockMessageFetcher fetchMessagesWithImpressionList:[OCMArg any]
                                                      withCompletion:[OCMArg any]]);
  [self.flow checkAndFetchForInitialAppLaunch:NO];

  NSArray<FIRIAMMessageDefinition *> *foundMessages = [self.clientMessageCache allRegularMessages];
  XCTAssertEqual(0, foundMessages.count);
}

// Fetch always in newly installed mode
- (void)testAlwaysFetchForNewlyInstalledMode {
  OCMStub([self.mockBookkeeper lastFetchTime]).andReturn(0);
  OCMStub([self.mockSDKModeManager currentMode]).andReturn(FIRIAMSDKModeNewlyInstalled);
  OCMStub([self.mockMessageFetcher
      fetchMessagesWithImpressionList:[OCMArg any]
                       withCompletion:([OCMArg invokeBlockWithArgs:@[ self.m1, self.m2 ],
                                                                   [NSNull null], [NSNull null],
                                                                   [NSNull null], nil])]);

  // 100 seconds is less than fetch wait time which is 1000 in this setup,
  // but since we are in newly installed mode, fetch would still happen
  OCMStub([self.mockBookkeeper nextFetchWaitTime]).andReturn(1000);
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(100);

  [self.flow checkAndFetchForInitialAppLaunch:YES];

  // we expect m1 and m2 to be dumped into clientMessageCache
  NSArray<FIRIAMMessageDefinition *> *foundMessages = [self.clientMessageCache allRegularMessages];
  XCTAssertEqual(2, foundMessages.count);
  XCTAssertEqualObjects(foundMessages[0].renderData.messageID, self.m1.renderData.messageID);
  XCTAssertEqualObjects(foundMessages[1].renderData.messageID, self.m2.renderData.messageID);

  // we expect to register a fetch with sdk manager
  OCMVerify([self.mockSDKModeManager registerOneMoreFetch]);

  // we expect that the message cache is checked for app launch messages
  OCMVerify([self.mockDisplayExecutor checkAndDisplayNextAppLaunchMessage]);
}

// Fetch always in testing app instance mode
- (void)testAlwaysFetchForTestingAppInstanceMode {
  OCMStub([self.mockBookkeeper lastFetchTime]).andReturn(0);
  OCMStub([self.mockSDKModeManager currentMode]).andReturn(FIRIAMSDKModeTesting);
  OCMStub([self.mockMessageFetcher
      fetchMessagesWithImpressionList:[OCMArg any]
                       withCompletion:([OCMArg invokeBlockWithArgs:@[ self.m1, self.m2 ],
                                                                   [NSNull null], [NSNull null],
                                                                   [NSNull null], nil])]);
  // 100 seconds is less than fetch wait time which is 1000 in this setup,
  // but since we are in testing app instance mode, fetch would still happen
  OCMStub([self.mockBookkeeper nextFetchWaitTime]).andReturn(1000);
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(100);

  [self.flow checkAndFetchForInitialAppLaunch:NO];

  // we expect m1 and m2 to be dumped into clientMessageCache
  NSArray<FIRIAMMessageDefinition *> *foundMessages = [self.clientMessageCache allRegularMessages];
  XCTAssertEqual(2, foundMessages.count);
  XCTAssertEqualObjects(foundMessages[0].renderData.messageID, self.m1.renderData.messageID);
  XCTAssertEqualObjects(foundMessages[1].renderData.messageID, self.m2.renderData.messageID);

  // we expect to register a fetch with sdk manager
  OCMVerify([self.mockSDKModeManager registerOneMoreFetch]);
}

- (void)testTurnIntoTestigModeOnSeeingTestMessage {
  OCMStub([self.mockBookkeeper lastFetchTime]).andReturn(0);
  OCMStub([self.mockSDKModeManager currentMode]).andReturn(FIRIAMSDKModeNewlyInstalled);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m2.renderData
                                                             appData:nil
                                                   experimentPayload:nil];

  OCMStub([self.mockMessageFetcher
      fetchMessagesWithImpressionList:[OCMArg any]
                       withCompletion:([OCMArg invokeBlockWithArgs:@[ self.m1, testMessage ],
                                                                   [NSNull null], [NSNull null],
                                                                   [NSNull null], nil])]);
  self.fetchSetting.fetchMinIntervalInMinutes = 10;  // at least 600 seconds between fetches
  // 100 seconds is larger than FETCH_MIN_INTERVALS minutes
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(100);

  [self.flow checkAndFetchForInitialAppLaunch:NO];

  // Expecting turning sdk mode into a testing instance
  OCMVerify([self.mockSDKModeManager becomeTestingInstance]);
}

- (void)testNotTurningIntoTestingModeIfAlreadyInTestingMode {
  OCMStub([self.mockBookkeeper lastFetchTime]).andReturn(0);
  OCMStub([self.mockSDKModeManager currentMode]).andReturn(FIRIAMSDKModeTesting);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:self.m2.renderData
                                                             appData:nil
                                                   experimentPayload:nil];

  OCMStub([self.mockMessageFetcher
      fetchMessagesWithImpressionList:[OCMArg any]
                       withCompletion:([OCMArg invokeBlockWithArgs:@[ self.m1, testMessage ],
                                                                   [NSNull null], [NSNull null],
                                                                   [NSNull null], nil])]);
  self.fetchSetting.fetchMinIntervalInMinutes = 10;  // at least 600 seconds between fetches
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(1000);
  OCMReject([self.mockSDKModeManager becomeTestingInstance]);

  [self.flow checkAndFetchForInitialAppLaunch:NO];
}
@end
