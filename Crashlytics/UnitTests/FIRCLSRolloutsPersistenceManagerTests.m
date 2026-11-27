// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSRolloutsPersistenceManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"
#if SWIFT_PACKAGE
@import FirebaseCrashlyticsSwift;
#else  // Swift Package Manager
#import <FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>
#endif  // CocoaPods

NSString *reportId = @"1234567";

@interface FIRCLSRolloutsPersistenceManagerTests : XCTestCase
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;
@property(nonatomic, strong) dispatch_queue_t loggingQueue;
@property(nonatomic, strong) FIRCLSRolloutsPersistenceManager *rolloutsPersistenceManager;
@end

@implementation FIRCLSRolloutsPersistenceManagerTests
- (void)setUp {
  [super setUp];
  FIRCLSContextBaseInit();
  self.fileManager = [[FIRCLSTempMockFileManager alloc] init];
  [self.fileManager createReportDirectories];
  [self.fileManager setupNewPathForExecutionIdentifier:reportId];

  self.loggingQueue =
      dispatch_queue_create("com.google.firebase.FIRCLSRolloutsPersistence", DISPATCH_QUEUE_SERIAL);
  self.rolloutsPersistenceManager =
      [[FIRCLSRolloutsPersistenceManager alloc] initWithFileManager:self.fileManager
                                                           andQueue:self.loggingQueue];
}

- (void)tearDown {
  [self.fileManager removeItemAtPath:_fileManager.rootPath];
  FIRCLSContextBaseDeinit();
  [super tearDown];
}

- (void)testUpdateRolloutsStateToPersistenceWithRollouts {
  XCTestExpectation *expectation = [[XCTestExpectation alloc]
      initWithDescription:@"Expect updating rollouts to finish writing."];

  NSString *encodedStateString =
      @"{rollouts:[{\"parameter_key\":\"6d795f66656174757265\",\"parameter_value\":"
      @"\"e8bf99e698af7468656d6973e79a84e6b58be8af95e695b0e68daeefbc8ce8be93e585a5e4b8ade69687\","
      @"\"rollout_id\":\"726f6c6c6f75745f31\",\"template_version\":1,\"variant_id\":"
      @"\"636f6e74726f6c\"}]}";

  NSData *data = [encodedStateString dataUsingEncoding:NSUTF8StringEncoding];
  NSString *rolloutsFilePath =
      [[[self.fileManager activePath] stringByAppendingPathComponent:reportId]
          stringByAppendingPathComponent:FIRCLSReportRolloutsFile];
  [self.rolloutsPersistenceManager updateRolloutsStateToPersistenceWithRollouts:data
                                                                       reportID:reportId];
  XCTAssertNotNil(self.loggingQueue);
  // Wait for the logging queue to finish.
  dispatch_async(self.loggingQueue, ^{
    [expectation fulfill];
  });

  [self waitForExpectations:@[ expectation ] timeout:10];

  XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:rolloutsFilePath]);

  NSFileHandle *rolloutsFile = [NSFileHandle fileHandleForUpdatingAtPath:rolloutsFilePath];
  NSData *fileData = [rolloutsFile readDataToEndOfFile];
  NSString *fileString = [[NSString alloc] initWithData:fileData encoding:NSUTF8StringEncoding];
  XCTAssertTrue([fileString isEqualToString:[encodedStateString stringByAppendingString:@"\n"]]);
}

- (void)testUpdateRolloutsStateToPersistenceEnsureNoHang {
  dispatch_queue_t testQueue = dispatch_queue_create("TestQueue", DISPATCH_QUEUE_SERIAL);
  XCTestExpectation *expectation =
      [[XCTestExpectation alloc] initWithDescription:@"Expect updating rollouts to return."];
  NSString *encodedStateString =
      @"{rollouts:[{\"parameter_key\":\"6d795f66656174757265\",\"parameter_value\":"
      @"\"e8bf99e698af7468656d6973e79a84e6b58be8af95e695b0e68daeefbc8ce8be93e585a5e4b8ade69687\","
      @"\"rollout_id\":\"726f6c6c6f75745f31\",\"template_version\":1,\"variant_id\":"
      @"\"636f6e74726f6c\"}]}";

  NSData *data = [encodedStateString dataUsingEncoding:NSUTF8StringEncoding];
  NSString *rolloutsFilePath =
      [[[self.fileManager activePath] stringByAppendingPathComponent:reportId]
          stringByAppendingPathComponent:FIRCLSReportRolloutsFile];

  // Block the logging queue until the test verifies that calling
  // updateRolloutsStateToPersistenceWithRollouts:reportID: returns without hanging.
  dispatch_semaphore_t queueBlockedSemaphore = dispatch_semaphore_create(0);
  dispatch_async(self.loggingQueue, ^{
    dispatch_semaphore_wait(queueBlockedSemaphore,
                            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)));
  });

  dispatch_async(testQueue, ^{
    // Ensure that calling this returns quickly and does not perform synchronous file creation on
    // the calling thread while the logging queue is blocked.
    [self.rolloutsPersistenceManager updateRolloutsStateToPersistenceWithRollouts:data
                                                                         reportID:reportId];
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:rolloutsFilePath]);
    [expectation fulfill];
  });

  [self waitForExpectations:@[ expectation ] timeout:10];
  dispatch_semaphore_signal(queueBlockedSemaphore);
  // Let the pending write finish before tearDown removes the report directory.
  dispatch_sync(self.loggingQueue, ^{
                });
}

@end
