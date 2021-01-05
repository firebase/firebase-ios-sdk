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

#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutHttpRequestSender.h"
#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutLogStorage.h"
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClearcutLogger.h"
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClearcutUploader.h"

@interface FIRIAMClearcutLoggerTests : XCTestCase
@property(nonatomic) FIRIAMClientInfoFetcher *mockClientInfoFetcher;
@property(nonatomic) id<FIRIAMTimeFetcher> mockTimeFetcher;
@property(nonatomic) FIRIAMClearcutHttpRequestSender *mockRequestSender;
@property(nonatomic) FIRIAMClearcutUploader *mockCtUploader;

@end

NSString *iid = @"my iid";
NSString *osVersion = @"iOS version";
NSString *sdkVersion = @"SDK version";

// we need to access the some internal things in FIRIAMClearcutLogger in our unit tests
// verifications
@interface FIRIAMClearcutLogger (UnitTestAccess)
@property(readonly, nonatomic) FIRIAMClearcutLogStorage *retryStorage;
@property(nonatomic) FIRIAMClearcutHttpRequestSender *requestSender;
@property(nonatomic) id<FIRIAMTimeFetcher> timeFetcher;
- (void)checkAndRetryClearcutLogs;
@end
@interface FIRIAMClearcutLogStorage (UnitTestAccess)
@property(nonatomic) NSMutableArray<FIRIAMClearcutLogRecord *> *records;
@end

@implementation FIRIAMClearcutLoggerTests
- (void)setUp {
  [super setUp];

  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.mockClientInfoFetcher = OCMClassMock(FIRIAMClientInfoFetcher.class);
  self.mockRequestSender = OCMClassMock(FIRIAMClearcutHttpRequestSender.class);
  self.mockCtUploader = OCMClassMock(FIRIAMClearcutUploader.class);

  OCMStub([self.mockClientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:[OCMArg any]
                                      withCompletion:([OCMArg invokeBlockWithArgs:iid, @"token",
                                                                                  [NSNull null],
                                                                                  nil])]);

  OCMStub([self.mockClientInfoFetcher getIAMSDKVersion]).andReturn(sdkVersion);
  OCMStub([self.mockClientInfoFetcher getOSVersion]).andReturn(osVersion);
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

// verify that the produced FIRIAMClearcutLogRecord record has expected content for
// the event extension json string
- (void)testEventLogBodyContent_Expected {
  NSString *fbProjectNumber = @"clearcutserver";
  NSString *fbAppId = @"test Firebase app";

  FIRIAMClearcutLogger *logger =
      [[FIRIAMClearcutLogger alloc] initWithFBProjectNumber:fbProjectNumber
                                                    fbAppId:fbAppId
                                          clientInfoFetcher:self.mockClientInfoFetcher
                                           usingTimeFetcher:self.mockTimeFetcher
                                              usingUploader:self.mockCtUploader];

  NSTimeInterval eventMoment = 10000;
  __block NSDictionary *capturedEventDict;

  OCMExpect([self.mockCtUploader
      addNewLogRecord:[OCMArg checkWithBlock:^BOOL(FIRIAMClearcutLogRecord *newLogRecord) {
        NSString *jsonString = newLogRecord.eventExtensionJsonString;

        capturedEventDict = [NSJSONSerialization
            JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]
                       options:kNilOptions
                         error:nil];
        return (int)newLogRecord.eventTimestampInSeconds == (int)eventMoment;
      }]]);

  NSString *campaignID = @"test campaign";
  [logger logAnalyticsEventForType:FIRIAMAnalyticsEventActionURLFollow
                     forCampaignID:campaignID
                  withCampaignName:@"name"
                     eventTimeInMs:[NSNumber numberWithInteger:eventMoment * 1000]
                        completion:^(BOOL success){
                        }];

  OCMVerifyAll((id)self.mockCtUploader);

  XCTAssertEqualObjects(@"CLICK_EVENT_TYPE", capturedEventDict[@"event_type"]);
  XCTAssertEqualObjects(fbProjectNumber, capturedEventDict[@"project_number"]);
  XCTAssertEqualObjects(campaignID, capturedEventDict[@"campaign_id"]);
  XCTAssertEqualObjects(fbAppId, capturedEventDict[@"client_app"][@"google_app_id"]);
  XCTAssertEqualObjects(iid, capturedEventDict[@"client_app"][@"firebase_instance_id"]);
  XCTAssertEqualObjects(sdkVersion, capturedEventDict[@"fiam_sdk_version"]);
}

// calling logAnalyticsEventForType with event time set to nil
- (void)testNilEventTimestamp {
  FIRIAMClearcutLogger *logger =
      [[FIRIAMClearcutLogger alloc] initWithFBProjectNumber:@"clearcutserver"
                                                    fbAppId:@"test Firebase app"
                                          clientInfoFetcher:self.mockClientInfoFetcher
                                           usingTimeFetcher:self.mockTimeFetcher
                                              usingUploader:self.mockCtUploader];

  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  OCMExpect([self.mockCtUploader
      addNewLogRecord:[OCMArg checkWithBlock:^BOOL(FIRIAMClearcutLogRecord *newLogRecord) {
        return (int)newLogRecord.eventTimestampInSeconds == (int)currentMoment;
      }]]);

  [logger logAnalyticsEventForType:FIRIAMAnalyticsEventActionURLFollow
                     forCampaignID:@"test campaign"
                  withCampaignName:@"name"
                     eventTimeInMs:nil
                        completion:^(BOOL success){
                        }];

  OCMVerifyAll((id)self.mockCtUploader);
}
@end
