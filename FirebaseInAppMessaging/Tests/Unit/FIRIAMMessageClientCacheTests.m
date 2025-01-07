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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentDataWithImageURL.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/DisplayTrigger/FIRIAMDisplayTriggerDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayCheckOnAnalyticEventsFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMMessageClientCache.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"

@interface FIRIAMMessageClientCacheTests : XCTestCase
@property id<FIRIAMBookKeeper> mockBookkeeper;
@property(nonatomic) FIRIAMMessageClientCache *clientCache;
@end

@interface FIRIAMMessageClientCache ()
// for the purpose of unit testing validations
@property(nonatomic) NSMutableSet<NSString *> *firebaseAnalyticEventsToWatch;
@end

@implementation FIRIAMMessageClientCacheTests {
  // some predefined message definitions that are handy for certain test cases
  FIRIAMMessageDefinition *m1, *m2, *m3, *m4, *m5;
}

- (void)setUp {
  [super setUp];
  self.mockBookkeeper = OCMProtocolMock(@protocol(FIRIAMBookKeeper));

  FIRIAMFetchResponseParser *parser =
      [[FIRIAMFetchResponseParser alloc] initWithTimeFetcher:[[FIRIAMTimerWithNSDate alloc] init]];
  self.clientCache = [[FIRIAMMessageClientCache alloc] initWithBookkeeper:self.mockBookkeeper
                                                      usingResponseParser:parser];

  // startTime, endTime here ensures messages with them are active
  NSTimeInterval activeStartTime = 0;
  NSTimeInterval activeEndTime = [[NSDate date] timeIntervalSince1970] + 10000;
  // m2 & m 4 will be of contextual trigger
  FIRIAMDisplayTriggerDefinition *contextualTriggerDefinition =
      [[FIRIAMDisplayTriggerDefinition alloc] initWithFirebaseAnalyticEvent:@"test_event"];

  FIRIAMDisplayTriggerDefinition *contextualTriggerDefinition2 =
      [[FIRIAMDisplayTriggerDefinition alloc] initWithFirebaseAnalyticEvent:@"second_event"];

  // m1 and m3 will be of app open trigger
  FIRIAMDisplayTriggerDefinition *appOpentriggerDefinition =
      [[FIRIAMDisplayTriggerDefinition alloc] initForAppForegroundTrigger];

  FIRIAMMessageContentDataWithImageURL *msgContentData =
      [[FIRIAMMessageContentDataWithImageURL alloc]
               initWithMessageTitle:@"title"
                        messageBody:@"message body"
                   actionButtonText:nil
          secondaryActionButtonText:nil
                          actionURL:[NSURL URLWithString:@"http://google.com"]
                 secondaryActionURL:nil
                           imageURL:[NSURL URLWithString:@"https://unsplash.it/300/300"]
                  landscapeImageURL:nil
                    usingURLSession:nil];

  FIRIAMRenderingEffectSetting *renderSetting =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting.viewMode = FIRIAMRenderAsBannerView;

  FIRIAMMessageRenderData *renderData1 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m1"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  m1 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData1
                                                 startTime:activeStartTime
                                                   endTime:activeEndTime
                                         triggerDefinition:@[ appOpentriggerDefinition ]];

  FIRIAMMessageRenderData *renderData2 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m2"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  m2 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData2
                                                 startTime:activeStartTime
                                                   endTime:activeEndTime
                                         triggerDefinition:@[ contextualTriggerDefinition ]];

  FIRIAMMessageRenderData *renderData3 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m3"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  m3 = [[FIRIAMMessageDefinition alloc] initWithRenderData:renderData3
                                                 startTime:activeStartTime
                                                   endTime:activeEndTime
                                         triggerDefinition:@[ appOpentriggerDefinition ]];

  FIRIAMMessageRenderData *renderData4 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m4"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  FIRIAMMessageRenderData *renderData5 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m5"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  m4 = [[FIRIAMMessageDefinition alloc]
      initWithRenderData:renderData4
               startTime:activeStartTime
                 endTime:activeEndTime
       triggerDefinition:@[ contextualTriggerDefinition, contextualTriggerDefinition2 ]];

  // m5 is of mixture of both app-foreground and contextual triggers
  m5 = [[FIRIAMMessageDefinition alloc]
      initWithRenderData:renderData5
               startTime:activeStartTime
                 endTime:activeEndTime
       triggerDefinition:@[ contextualTriggerDefinition, appOpentriggerDefinition ]];
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testResetMessages {
  // test setting a mixture of display-on-app open messages and Firebase Analytics based messages
  // to see if the cache will keep them correctly
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];

  NSArray<FIRIAMMessageDefinition *> *messages = [self.clientCache allRegularMessages];
  XCTAssertEqual(4, [messages count]);

  // m4 have two contextual events defined as triggers
  XCTAssertEqual(2, [self.clientCache.firebaseAnalyticEventsToWatch count]);
  XCTAssert([self.clientCache.firebaseAnalyticEventsToWatch containsObject:@"test_event"]);
  XCTAssert([self.clientCache.firebaseAnalyticEventsToWatch containsObject:@"second_event"]);
}

- (void)testResetMessagesWithImpressionsData {
  // test setting a mixture of display-on-app open messages and Firebase Analytics based messages
  // to see if the cache will keep them correctly

  NSArray<NSString *> *impressionList = @[ @"m1", @"m2" ];
  OCMStub([self.mockBookkeeper getMessageIDsFromImpressions]).andReturn(impressionList);
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];

  // m1 and m2 should have been filtered out
  NSArray<FIRIAMMessageDefinition *> *messages = [self.clientCache allRegularMessages];
  XCTAssertEqual(2, messages.count);

  // m4 have two contextual events defined as triggers
  XCTAssertEqual(2, self.clientCache.firebaseAnalyticEventsToWatch.count);
  XCTAssert([self.clientCache.firebaseAnalyticEventsToWatch containsObject:@"test_event"]);
  XCTAssert([self.clientCache.firebaseAnalyticEventsToWatch containsObject:@"second_event"]);
}

- (void)testNextOnAppOpenDisplayMsg_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);
  // m1 and m3 are messages rendered on app open
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];

  FIRIAMMessageDefinition *nextMsgOnAppOpen = [self.clientCache nextOnAppOpenDisplayMsg];
  XCTAssertEqual(@"m1", nextMsgOnAppOpen.renderData.messageID);
  // remove m1
  [self.clientCache removeMessageWithId:@"m1"];

  // read m2 and remove it
  nextMsgOnAppOpen = [self.clientCache nextOnAppOpenDisplayMsg];
  XCTAssertEqual(@"m3", nextMsgOnAppOpen.renderData.messageID);
  [self.clientCache removeMessageWithId:@"m3"];

  // no more message for display on app open
  nextMsgOnAppOpen = [self.clientCache nextOnAppOpenDisplayMsg];
  XCTAssertNil(nextMsgOnAppOpen);
}

- (void)testNextOnFirebaseAnalyticsEventDisplayMsg_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);
  // m2 and m4 are messages rendered on 'app open'test_event' Firebase Analytics event
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];

  FIRIAMMessageDefinition *nextMsgOnFIREvent =
      [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"test_event"];
  XCTAssertEqual(@"m2", nextMsgOnFIREvent.renderData.messageID);
  // remove m2
  [self.clientCache removeMessageWithId:@"m2"];
  // verify that the watch set is empty after draining all the messages
  XCTAssertTrue([self.clientCache.firebaseAnalyticEventsToWatch containsObject:@"test_event"]);

  // read m4 and remove it
  nextMsgOnFIREvent = [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"test_event"];
  XCTAssertEqual(@"m4", nextMsgOnFIREvent.renderData.messageID);
  // remove m4
  [self.clientCache removeMessageWithId:@"m4"];

  // no more message for display on Firebase Analytics event
  nextMsgOnFIREvent = [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"test_event"];
  XCTAssertNil(nextMsgOnFIREvent);

  // verify that the watch set is empty after draining all the messages
  XCTAssertEqual(0, self.clientCache.firebaseAnalyticEventsToWatch.count);
}

- (void)testNextOnFirebaseAnalyticsEventDisplayMsgEventNameMustMatch_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);
  // m2 and m4 are messages rendered on 'app open'test_event' Firebase Analytics event
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];

  FIRIAMMessageDefinition *nextMsgOnFIREvent =
      [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"different_event"];
  XCTAssertNil(nextMsgOnFIREvent);
}

- (void)testNextOnFirebaseAnalyticsEventDisplayMsgEventNameCanMatchAny_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);
  // m4 are messages of multiple contextual triggers, one of which is for event
  // 'second_event'
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];

  FIRIAMMessageDefinition *nextMsgOnFIREvent =
      [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"second_event"];
  XCTAssertNotNil(nextMsgOnFIREvent);
}

- (void)testMessageCanHaveMixedTypeOfTriggers_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);
  [self.clientCache setMessageData:@[ m5 ]];

  FIRIAMMessageDefinition *nextMsgOnFIREvent =
      [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"test_event"];
  XCTAssertNotNil(nextMsgOnFIREvent);

  // in the meanwhile, retrieving an app-foreground message should be successful
  FIRIAMMessageDefinition *nextMsgOnAppForeground = [self.clientCache nextOnAppOpenDisplayMsg];
  XCTAssertNotNil(nextMsgOnAppForeground);
}

- (void)testNextOnFirebaseAnalyticsEventDisplayMsg_handleStartEndTimeCorrectly {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);

  FIRIAMDisplayTriggerDefinition *appOpentriggerDefinition =
      [[FIRIAMDisplayTriggerDefinition alloc] initForAppForegroundTrigger];

  FIRIAMMessageContentDataWithImageURL *msgContentData =
      [[FIRIAMMessageContentDataWithImageURL alloc]
               initWithMessageTitle:@"title"
                        messageBody:@"message body"
                   actionButtonText:nil
          secondaryActionButtonText:nil
                          actionURL:[NSURL URLWithString:@"http://google.com"]
                 secondaryActionURL:nil
                           imageURL:[NSURL URLWithString:@"https://unsplash.it/300/300"]
                  landscapeImageURL:nil
                    usingURLSession:nil];

  FIRIAMRenderingEffectSetting *renderSetting =
      [FIRIAMRenderingEffectSetting getDefaultRenderingEffectSetting];
  renderSetting.viewMode = FIRIAMRenderAsBannerView;

  FIRIAMMessageRenderData *renderData1 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m1"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  // m1 has not started yet
  FIRIAMMessageDefinition *unstartedMessage = [[FIRIAMMessageDefinition alloc]
      initWithRenderData:renderData1
               startTime:[[NSDate date] timeIntervalSince1970] + 10000
                 endTime:[[NSDate date] timeIntervalSince1970] + 20000
       triggerDefinition:@[ appOpentriggerDefinition ]];

  FIRIAMMessageRenderData *renderData2 =
      [[FIRIAMMessageRenderData alloc] initWithMessageID:@"m2"
                                             messageName:@"name"
                                             contentData:msgContentData
                                         renderingEffect:renderSetting];

  // m2 has ended
  FIRIAMMessageDefinition *endedMessage = [[FIRIAMMessageDefinition alloc]
      initWithRenderData:renderData2
               startTime:[[NSDate date] timeIntervalSince1970] - 20000
                 endTime:[[NSDate date] timeIntervalSince1970] - 10000
       triggerDefinition:@[ appOpentriggerDefinition ]];

  // m3, m4 are campaigns with good start/end time
  [self.clientCache setMessageData:@[ unstartedMessage, endedMessage, m3, m4 ]];

  FIRIAMMessageDefinition *nextMsgOnAppOpen = [self.clientCache nextOnAppOpenDisplayMsg];
  FIRIAMMessageDefinition *nextMsgOnFIREvent =
      [self.clientCache nextOnFirebaseAnalyticEventDisplayMsg:@"test_event"];
  XCTAssertEqual(nextMsgOnAppOpen.renderData.messageID, @"m3");
  XCTAssertEqual(nextMsgOnFIREvent.renderData.messageID, @"m4");

  // no more on app open display message
  [self.clientCache removeMessageWithId:@"m3"];
  nextMsgOnAppOpen = [self.clientCache nextOnAppOpenDisplayMsg];
  XCTAssertNil(nextMsgOnAppOpen);
}

- (void)testCallingStartAnalyticsEventListenFlow_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);

  FIRIAMDisplayCheckOnAnalyticEventsFlow *mockAnalyticsEventFlow =
      OCMClassMock(FIRIAMDisplayCheckOnAnalyticEventsFlow.class);
  self.clientCache.analyticsEventDisplayCheckFlow = mockAnalyticsEventFlow;

  // m2 and m4 are messages rendered on 'test_event' Firebase Analytics event
  // so we expect the analytics event listening flow to be started
  OCMExpect([mockAnalyticsEventFlow start]);
  [self.clientCache setMessageData:@[ m1, m2, m3, m4 ]];
  OCMVerifyAll((id)mockAnalyticsEventFlow);
}

- (void)testCallingStopAnalyticsEventListenFlow_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);

  FIRIAMDisplayCheckOnAnalyticEventsFlow *mockAnalyticsEventFlow =
      OCMClassMock(FIRIAMDisplayCheckOnAnalyticEventsFlow.class);
  self.clientCache.analyticsEventDisplayCheckFlow = mockAnalyticsEventFlow;

  // m1 and m3 are messages rendered on app foreground triggers
  OCMExpect([mockAnalyticsEventFlow stop]);
  [self.clientCache setMessageData:@[ m1, m3 ]];
  OCMVerifyAll((id)mockAnalyticsEventFlow);
}

- (void)testCallingStartAndThenStopAnalyticsEventListenFlow_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);

  FIRIAMDisplayCheckOnAnalyticEventsFlow *mockAnalyticsEventFlow =
      OCMClassMock(FIRIAMDisplayCheckOnAnalyticEventsFlow.class);
  self.clientCache.analyticsEventDisplayCheckFlow = mockAnalyticsEventFlow;

  // start is triggered on the setMessageData: call
  OCMExpect([mockAnalyticsEventFlow start]);
  // stop is triggered on removeMessageWithId: call since m2 is the only message
  // using contextual triggers
  OCMExpect([mockAnalyticsEventFlow stop]);

  [self.clientCache setMessageData:@[ m1, m2, m3 ]];
  [self.clientCache removeMessageWithId:m2.renderData.messageID];
  OCMVerifyAll((id)mockAnalyticsEventFlow);
}

- (void)testFetchTestMessageFirstOnNextOnAppOpenDisplayMsg_ok {
  OCMStub([self.mockBookkeeper getImpressions]).andReturn(@[]);

  FIRIAMMessageDefinition *testMessage =
      [[FIRIAMMessageDefinition alloc] initTestMessageWithRenderData:m2.renderData
                                                             appData:nil
                                                   experimentPayload:nil];

  // m1 and m3 are messages rendered on app open
  [self.clientCache setMessageData:@[ m1, m2, testMessage, m3, m4 ]];

  // we are fetching test message back
  FIRIAMMessageDefinition *nextMsgOnAppOpen = [self.clientCache nextOnAppOpenDisplayMsg];
  XCTAssertEqual(testMessage.renderData.messageID, nextMsgOnAppOpen.renderData.messageID);

  // we still have 4 regular messages after the first fetch
  XCTAssertEqual(4, self.clientCache.allRegularMessages.count);
}
@end
