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

#import "FirebaseMessaging/Tests/UnitTests/FIRTestsAssertionHandler.h"
#import "FirebaseMessaging/Tests/UnitTests/XCTestCase+FIRMessagingRmqManagerTests.h"

#import "FirebaseMessaging/Sources/FIRMessagingPersistentSyncMessage.h"
#import "FirebaseMessaging/Sources/FIRMessagingRmqManager.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"

static NSString *const kRmqDatabaseName = @"rmq-test-db";

@interface FIRMessagingRmqManager (ExposedForTest)

- (void)removeDatabase;
- (dispatch_queue_t)databaseOperationQueue;

@end

@interface FIRMessagingRmqManagerTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingRmqManager *rmqManager;
@property(nonatomic, strong) id assertionHandlerMock;
@property(nonatomic, strong) FIRTestsAssertionHandler *testAssertionHandler;

@end

@implementation FIRMessagingRmqManagerTest

- (void)setUp {
  [super setUp];

  self.testAssertionHandler = [[FIRTestsAssertionHandler alloc] init];
  self.assertionHandlerMock = OCMClassMock([NSAssertionHandler class]);
  OCMStub([self.assertionHandlerMock currentHandler]).andReturn(self.testAssertionHandler);

  // Make sure we start off with a clean state each time
  _rmqManager = [[FIRMessagingRmqManager alloc] initWithDatabaseName:kRmqDatabaseName];
}

- (void)tearDown {
  [self.rmqManager removeDatabase];
  [self waitForDrainDatabaseQueueForRmqManager:self.rmqManager];

  [self.assertionHandlerMock stopMocking];
  self.assertionHandlerMock = nil;
  self.testAssertionHandler = nil;

  [super tearDown];
}

/**
 *  Test saving a sync message to SYNC_RMQ.
 */
- (void)testSavingSyncMessage {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  [self.rmqManager saveSyncMessageWithRmqID:rmqID expirationTime:expirationTime];

  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertEqual(persistentMessage.expirationTime, expirationTime);
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertFalse(persistentMessage.mcsReceived);
}

/**
 *  Test updating a sync message initially received via MCS, now being received via APNS.
 */
- (void)testUpdateMessageReceivedViaAPNS {
  NSString *rmqID = @"fake-rmq-id-1";
  int64_t expirationTime = FIRMessagingCurrentTimestampInSeconds() + 1;
  [self.rmqManager saveSyncMessageWithRmqID:rmqID expirationTime:expirationTime];

  // Message was now received via APNS
  [self.rmqManager updateSyncMessageViaAPNSWithRmqID:rmqID];

  FIRMessagingPersistentSyncMessage *persistentMessage =
      [self.rmqManager querySyncMessageWithRmqID:rmqID];
  XCTAssertTrue(persistentMessage.apnsReceived);
  XCTAssertFalse(persistentMessage.mcsReceived);
}

- (void)testInitWhenDatabaseIsBrokenThenDatabaseIsDeleted {
  NSString *databaseName = @"invalid-database-file";
  NSString *databasePath = [self createBrokenDatabaseWithName:databaseName];
  XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:databasePath]);

  // Expect for at least one assertion.
  XCTestExpectation *assertionFailureExpectation =
      [self expectationWithDescription:@"assertionFailureExpectation"];
  assertionFailureExpectation.assertForOverFulfill = NO;

// The flag FIR_MESSAGING_ASSERTIONS_BLOCKED can be set by blaze when running tests from google3.
#ifndef FIR_MESSAGING_ASSERTIONS_BLOCKED
  [self.testAssertionHandler
      setMethodFailureHandlerForClass:[FIRMessagingRmqManager class]
                              handler:^(id object, NSString *fileName, NSInteger lineNumber) {
                                [assertionFailureExpectation fulfill];
                              }];
#else
  // If FIR_MESSAGING_ASSERTIONS_BLOCKED is defined, then no assertion handlers will be called,
  // so don't wait for it.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [assertionFailureExpectation fulfill];
                 });
#endif  // FIR_MESSAGING_ASSERTIONS_BLOCKED

  // Create `FIRMessagingRmqManager` instance with a broken database.
  FIRMessagingRmqManager *manager =
      [[FIRMessagingRmqManager alloc] initWithDatabaseName:databaseName];

  [self waitForExpectations:@[ assertionFailureExpectation ] timeout:0.5];

  [self waitForDrainDatabaseQueueForRmqManager:manager];

  // Check that the file was deleted.
  XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:databasePath]);
}

#pragma mark - Private Helpers

- (NSString *)createBrokenDatabaseWithName:(NSString *)name {
  NSString *databasePath = [FIRMessagingRmqManager pathForDatabaseWithName:name];
  NSMutableArray *pathComponents = [[databasePath pathComponents] mutableCopy];
  [pathComponents removeLastObject];
  NSString *directoryPath = [NSString pathWithComponents:pathComponents];

  // Create directory if doesn't exist.
  [[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
  // Remove the file if exists.
  [[NSFileManager defaultManager] removeItemAtPath:databasePath error:NULL];

  NSData *brokenDBFileContent = [@"not a valid DB" dataUsingEncoding:NSUTF8StringEncoding];
  [brokenDBFileContent writeToFile:databasePath atomically:YES];

  XCTAssertEqualObjects([NSData dataWithContentsOfFile:databasePath], brokenDBFileContent);
  return databasePath;
}

@end
