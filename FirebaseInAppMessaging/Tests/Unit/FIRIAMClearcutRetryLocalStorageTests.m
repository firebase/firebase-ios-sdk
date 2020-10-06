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

#import "FirebaseInAppMessaging/Sources/Analytics/FIRIAMClearcutLogStorage.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"

@interface FIRIAMClearcutLogStorage (UnitTestAccess)
@property(nonatomic) NSMutableArray<FIRIAMClearcutLogRecord *> *records;
@end

@interface FIRIAMClearcutLogStorageTests : XCTestCase

@end

@implementation FIRIAMClearcutLogStorageTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testExpiringOldLogs {
  id<FIRIAMTimeFetcher> mockTimeFetcher = OCMProtocolMock(@protocol(FIRIAMTimeFetcher));
  NSInteger logExpiresInSeconds = 20;

  FIRIAMClearcutLogStorage *storage =
      [[FIRIAMClearcutLogStorage alloc] initWithExpireAfterInSeconds:logExpiresInSeconds
                                                     withTimeFetcher:mockTimeFetcher];

  NSInteger eventTimestamp = 1000;
  // insert 10 logs with event timestamp as eventTimestamp
  for (int i = 0; i < 10; i++) {
    FIRIAMClearcutLogRecord *nextRecord =
        [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"json string"
                                             eventTimestampInSeconds:eventTimestamp];
    [storage pushRecords:@[ nextRecord ]];
  }

  // insert 2 logs with event timestamp as eventTimestamp + 10
  for (int i = 0; i < 2; i++) {
    FIRIAMClearcutLogRecord *nextRecord =
        [[FIRIAMClearcutLogRecord alloc] initWithExtensionJsonString:@"json string"
                                             eventTimestampInSeconds:eventTimestamp + 10];
    [storage pushRecords:@[ nextRecord ]];
  }

  // with this stub, 10 out of the 12 the retry logs are going expired
  OCMStub([mockTimeFetcher currentTimestampInSeconds])
      .andReturn(eventTimestamp + logExpiresInSeconds + 1);

  NSArray<FIRIAMClearcutLogRecord *> *results = [storage popStillValidRecordsForUpTo:6];
  // only 2 out of 12 retry logs are still valid
  XCTAssertEqual(2, results.count);

  // all the messages should be gone here
  XCTAssertEqual(0, storage.records.count);
}
@end
