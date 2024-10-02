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

#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutHttpRequestSender.h"
#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutLogStorage.h"
#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClearcutUploader.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"

@interface FIRIAMClearcutUploaderTests : XCTestCase
@property(nonatomic) id<FIRIAMTimeFetcher> mockTimeFetcher;
@property(nonatomic) FIRIAMClearcutHttpRequestSender *mockRequestSender;
@property(nonatomic) FIRIAMClearcutLogStorage *mockLogStorage;
@property(nonatomic) FIRIAMClearcutStrategy *defaultStrategy;
@property(nonatomic) GULUserDefaults *mockUserDefaults;
@property(nonatomic) NSString *cachePath;
@end

// Expose certain internal things to help with unit testing.
@interface FIRIAMClearcutUploader (UnitTest)
@property(nonatomic, assign) int64_t nextValidSendTimeInMills;
@end

@implementation FIRIAMClearcutUploaderTests

// Helper function to avoid conflicts between tests with the singleton cache path.
- (NSString *)generatedCachePath {
  // Filter out any invalid filesystem characters.
  NSCharacterSet *invalidCharacters = [[NSCharacterSet alphanumericCharacterSet] invertedSet];

  // This will result in a string with the class name, a space, and the test name. We only care
  // about the test name so split it into components and return the last item.
  NSString *friendlyTestName = [self.name stringByTrimmingCharactersInSet:invalidCharacters];
  NSArray<NSString *> *components = [friendlyTestName componentsSeparatedByString:@" "];
  NSString *testName = [components lastObject];

  NSString *cacheDirPath =
      NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
  return [NSString stringWithFormat:@"%@/%@", cacheDirPath, testName];
}

- (void)setUp {
  [super setUp];
  self.mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  self.mockRequestSender = OCMClassMock(FIRIAMClearcutHttpRequestSender.class);
  self.mockLogStorage = OCMClassMock(FIRIAMClearcutLogStorage.class);

  self.defaultStrategy = [[FIRIAMClearcutStrategy alloc] initWithMinWaitTimeInMills:1000
                                                                 maxWaitTimeInMills:2000
                                                          failureBackoffTimeInMills:1000
                                                                      batchSendSize:10];

  self.mockUserDefaults = OCMClassMock(GULUserDefaults.class);
  self.cachePath = [self generatedCachePath];
  OCMStub([self.mockUserDefaults integerForKey:[OCMArg any]]).andReturn(0);
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:NULL];
  [super tearDown];
}

- (void)testUploadTriggeredWhenWaitTimeConditionSatisfied {
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  // using a real storage in this case
  FIRIAMClearcutLogStorage *logStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:1000
                                                     withTimeFetcher:self.mockTimeFetcher
                                                           cachePath:self.cachePath];

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:logStorage
                                              usingStrategy:self.defaultStrategy
                                          usingUserDefaults:self.mockUserDefaults];

  // Upload right away: nextValidSendTimeInMills < current time
  uploader.nextValidSendTimeInMills = (int64_t)(currentMoment - 1) * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];

  OCMStub([self.mockRequestSender sendClearcutHttpRequestForLogs:[OCMArg any]
                                                  withCompletion:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
      });

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];

  [uploader addNewLogRecord:newRecord];

  // We expect expectation to be fulfilled right away since the upload can be carried out without
  // delay.
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUploadNotTriggeredWhenWaitTimeConditionNotSatisfied {
  // using a real storage in this case
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  FIRIAMClearcutLogStorage *logStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:1000
                                                     withTimeFetcher:self.mockTimeFetcher
                                                           cachePath:self.cachePath];

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:logStorage
                                              usingStrategy:self.defaultStrategy
                                          usingUserDefaults:self.mockUserDefaults];

  // Forces uploading to be at least 5 seconds later.
  uploader.nextValidSendTimeInMills = (int64_t)(currentMoment + 5) * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];

  __block BOOL sendingAttempted = NO;
  // We don't expect sendClearcutHttpRequestForLogs:withCompletion: to be triggered
  // after wait for 2.0 seconds below. We have a BOOL flag to be used for that kind verification
  // checking.
  OCMStub([self.mockRequestSender sendClearcutHttpRequestForLogs:[OCMArg any]
                                                  withCompletion:[OCMArg any]])
      .andDo(^(NSInvocation *invocation) {
        sendingAttempted = YES;
      });
  [uploader addNewLogRecord:newRecord];

  // We wait for 2 seconds and we expect nothing should happen to self.mockRequestSender right after
  // 2 seconds: the upload will eventually be attempted in after 10 seconds based on the setup
  // in this unit test.
  double delayInSeconds = 2.0;
  dispatch_time_t popTime =
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
    [expectation fulfill];
  });

  // We expect expectation to be fulfilled right away since the upload can be carried out without
  // delay.
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  XCTAssertFalse(sendingAttempted);
}

- (void)testUploadBatchSizeIsBasedOnStrategySetting {
  int batchSendSize = 5;

  // using a strategy with batch send size as 5
  FIRIAMClearcutStrategy *strategy =
      [[FIRIAMClearcutStrategy alloc] initWithMinWaitTimeInMills:1000
                                              maxWaitTimeInMills:2000
                                       failureBackoffTimeInMills:1000
                                                   batchSendSize:batchSendSize];

  // Next upload is now.
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:self.mockLogStorage
                                              usingStrategy:strategy
                                          usingUserDefaults:self.mockUserDefaults];

  uploader.nextValidSendTimeInMills = (int64_t)currentMoment * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];
  OCMExpect([self.mockLogStorage popStillValidRecordsForUpTo:batchSendSize]);

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];
  [uploader addNewLogRecord:newRecord];

  // we wait for 2 seconds to ensure that the next send is attempted and then verify its
  // interacton with the underlying storage
  double delayInSeconds = 2.0;
  dispatch_time_t popTime =
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
    [expectation fulfill];
  });

  // we expect expectation to be fulfilled right away since the upload can be carried out without
  // delay
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  OCMVerifyAll((id)self.mockLogStorage);
}

- (void)testRespectingWaitTimeFromRequestSender {
  // The next upload is now.
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  // using a real storage in this case
  FIRIAMClearcutLogStorage *logStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:1000
                                                     withTimeFetcher:self.mockTimeFetcher
                                                           cachePath:self.cachePath];

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:logStorage
                                              usingStrategy:self.defaultStrategy
                                          usingUserDefaults:self.mockUserDefaults];

  uploader.nextValidSendTimeInMills = (int64_t)currentMoment * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];

  // notice that waitTime is between minWaitTimeInMills and maxWaitTimeInMills in the default
  // strategy
  NSNumber *waitTime = [NSNumber numberWithLongLong:1500];
  // set up request sender which triggers the callback with a wait time interval to be 1000
  // milliseconds
  OCMStub(
      [self.mockRequestSender
          sendClearcutHttpRequestForLogs:[OCMArg any]
                          withCompletion:([OCMArg invokeBlockWithArgs:@YES, @NO, waitTime, nil])])
      .andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
      });

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];
  [uploader addNewLogRecord:newRecord];

  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  // verify the update to nextValidSendTimeInMills is expected
  XCTAssertEqual(currentMoment * 1000 + 1500, uploader.nextValidSendTimeInMills);
}

- (void)disable_testWaitTimeFromRequestSenderAdjustedByMinWaitTimeInStrategy {
  // The next upload is now.
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  // using a real storage in this case
  FIRIAMClearcutLogStorage *logStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:1000
                                                     withTimeFetcher:self.mockTimeFetcher
                                                           cachePath:self.cachePath];

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:logStorage
                                              usingStrategy:self.defaultStrategy
                                          usingUserDefaults:self.mockUserDefaults];

  uploader.nextValidSendTimeInMills = (int64_t)currentMoment * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];

  // notice that waitTime is below minWaitTimeInMills in the default strategy
  NSNumber *waitTime =
      [NSNumber numberWithLongLong:self.defaultStrategy.minimalWaitTimeInMills - 200];
  // set up request sender which triggers the callback with a wait time interval to be 1000
  // milliseconds
  OCMStub(
      [self.mockRequestSender
          sendClearcutHttpRequestForLogs:[OCMArg any]
                          withCompletion:([OCMArg invokeBlockWithArgs:@YES, @NO, waitTime, nil])])
      .andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
      });

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];
  [uploader addNewLogRecord:newRecord];

  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  // verify the update to nextValidSendTimeInMills is expected
  XCTAssertEqual(currentMoment * 1000 + self.defaultStrategy.minimalWaitTimeInMills,
                 uploader.nextValidSendTimeInMills);
}

- (void)testWaitTimeFromRequestSenderAdjustedByMaxWaitTimeInStrategy {
  // The next upload is now.
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  // using a real storage in this case
  FIRIAMClearcutLogStorage *logStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:1000
                                                     withTimeFetcher:self.mockTimeFetcher
                                                           cachePath:self.cachePath];

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:logStorage
                                              usingStrategy:self.defaultStrategy
                                          usingUserDefaults:self.mockUserDefaults];

  uploader.nextValidSendTimeInMills = (int64_t)currentMoment * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];

  // notice that waitTime is larger than maximumWaitTimeInMills in the default strategy
  NSNumber *waitTime =
      [NSNumber numberWithLongLong:self.defaultStrategy.maximumWaitTimeInMills + 200];
  // set up request sender which triggers the callback with a wait time interval to be 1000
  // milliseconds
  OCMStub(
      [self.mockRequestSender
          sendClearcutHttpRequestForLogs:[OCMArg any]
                          withCompletion:([OCMArg invokeBlockWithArgs:@YES, @NO, waitTime, nil])])
      .andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
      });

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];
  [uploader addNewLogRecord:newRecord];

  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  // verify the update to nextValidSendTimeInMills is expected
  XCTAssertEqual(currentMoment * 1000 + self.defaultStrategy.maximumWaitTimeInMills,
                 uploader.nextValidSendTimeInMills);
}

- (void)testRepushLogsIfRequestSenderSaysSo {
  // The next upload is now.
  NSTimeInterval currentMoment = 10000;
  OCMStub([self.mockTimeFetcher currentTimestampInSeconds]).andReturn(currentMoment);

  // using a real storage in this case
  FIRIAMClearcutLogStorage *logStorage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:1000
                                                     withTimeFetcher:self.mockTimeFetcher
                                                           cachePath:self.cachePath];

  FIRIAMClearcutUploader *uploader =
      [[FIRIAMClearcutUploader alloc] initWithRequestSender:self.mockRequestSender
                                                timeFetcher:self.mockTimeFetcher
                                                 logStorage:logStorage
                                              usingStrategy:self.defaultStrategy
                                          usingUserDefaults:self.mockUserDefaults];

  uploader.nextValidSendTimeInMills = (int64_t)currentMoment * 1000;

  XCTestExpectation *expectation = [self expectationWithDescription:@"Triggers send on sender"];

  // notice that waitTime is larger than maximumWaitTimeInMills in the default strategy
  NSNumber *waitTime =
      [NSNumber numberWithLongLong:self.defaultStrategy.maximumWaitTimeInMills + 200];

  // Notice that it's invoking completion with failure flag and a flag to re-push those logs
  OCMStub(
      [self.mockRequestSender
          sendClearcutHttpRequestForLogs:[OCMArg any]
                          withCompletion:([OCMArg invokeBlockWithArgs:@NO, @YES, waitTime, nil])])
      .andDo(^(NSInvocation *invocation) {
        [expectation fulfill];
      });

  FIRIAMClearcutLogRecord *newRecord =
      [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"string"
                                           eventTimestampInSeconds:currentMoment];
  [uploader addNewLogRecord:newRecord];

  [self waitForExpectationsWithTimeout:10.0 handler:nil];

  // we should still be able to fetch one log record from storage since it's re-pushed due
  // to send failure
  XCTAssertEqual([logStorage popStillValidRecordsForUpTo:10].count, 1);
}
@end
