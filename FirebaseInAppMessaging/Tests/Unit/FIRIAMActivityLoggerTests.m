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

#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMActivityLogger.h"
@interface FIRIAMActivityLogger ()
- (void)loadFromCachePath:(NSString *)cacheFilePath;
- (BOOL)saveIntoCacheWithPath:(NSString *)cacheFilePath;
@end

@interface FIRIAMActivityLoggerTests : XCTestCase

@end

@implementation FIRIAMActivityLoggerTests

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

- (void)testNormalFlow {
  FIRIAMActivityLogger *logger = [[FIRIAMActivityLogger alloc] initWithMaxCountBeforeReduce:100
                                                                        withSizeAfterReduce:80
                                                                                verboseMode:YES
                                                                              loadFromCache:NO];

  FIRIAMActivityRecord *first =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeRenderMessage
                                            isSuccessful:NO
                                              withDetail:@"log detail"
                                               timestamp:nil];
  [logger addLogRecord:first];
  NSDate *now = [[NSDate alloc] init];
  FIRIAMActivityRecord *second =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForFetch
                                            isSuccessful:YES
                                              withDetail:@"log detail2"
                                               timestamp:now];
  [logger addLogRecord:second];

  // now read them back
  NSArray<FIRIAMActivityRecord *> *records = [logger readRecords];
  XCTAssertEqual(2, [records count]);

  // notice that log records read out would be [second, first] in LIFO order
  FIRIAMActivityRecord *firstFetched = records[0];
  XCTAssertEqualObjects(@"log detail2", firstFetched.detail);
  XCTAssertEqual(YES, firstFetched.success);
  XCTAssertEqual(FIRIAMActivityTypeCheckForFetch, firstFetched.activityType);
  // second's timestamp should be equal to now since it's used to construct that log record
  XCTAssertEqualWithAccuracy(now.timeIntervalSince1970,
                             firstFetched.timestamp.timeIntervalSince1970, 0.001);

  FIRIAMActivityRecord *secondFetched = records[1];
  XCTAssertEqualObjects(@"log detail", secondFetched.detail);
  XCTAssertEqual(NO, secondFetched.success);
  XCTAssertEqual(FIRIAMActivityTypeRenderMessage, secondFetched.activityType);
  // 60 seconds is large enough buffer for the timestamp comparison
  XCTAssertEqualWithAccuracy([[NSDate alloc] init].timeIntervalSince1970,
                             secondFetched.timestamp.timeIntervalSince1970, 60);
}

- (void)testReduceAfterReachingMaxCount {
  // expected behavior for logger regarding reducing is to come down to 1 after reaching size of 3
  FIRIAMActivityLogger *logger = [[FIRIAMActivityLogger alloc] initWithMaxCountBeforeReduce:3
                                                                        withSizeAfterReduce:1
                                                                                verboseMode:YES
                                                                              loadFromCache:NO];

  FIRIAMActivityRecord *first =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeRenderMessage
                                            isSuccessful:NO
                                              withDetail:@"log detail"
                                               timestamp:nil];
  [logger addLogRecord:first];
  FIRIAMActivityRecord *second =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForFetch
                                            isSuccessful:YES
                                              withDetail:@"log detail2"
                                               timestamp:nil];
  [logger addLogRecord:second];

  FIRIAMActivityRecord *third =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForFetch
                                            isSuccessful:YES
                                              withDetail:@"log detail3"
                                               timestamp:nil];
  [logger addLogRecord:third];
  NSArray<FIRIAMActivityRecord *> *records = [logger readRecords];
  XCTAssertEqual(1, [records count]);

  // and the remaining one would be the last one being inserted
  XCTAssertEqualObjects(@"log detail3", records[0].detail);
}

- (void)testNonVerboseMode {
  // certain types of messages would get dropped
  FIRIAMActivityLogger *logger = [[FIRIAMActivityLogger alloc] initWithMaxCountBeforeReduce:100
                                                                        withSizeAfterReduce:50
                                                                                verboseMode:NO
                                                                              loadFromCache:NO];

  // this one would be added
  FIRIAMActivityRecord *next =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeRenderMessage
                                            isSuccessful:NO
                                              withDetail:@"log detail"
                                               timestamp:nil];
  [logger addLogRecord:next];

  // this one would be dropped
  next = [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForOnOpenMessage
                                               isSuccessful:NO
                                                 withDetail:@"log detail"
                                                  timestamp:nil];
  [logger addLogRecord:next];

  // this one would be added
  next = [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeFetchMessage
                                               isSuccessful:NO
                                                 withDetail:@"log detail"
                                                  timestamp:nil];
  [logger addLogRecord:next];
  NSArray<FIRIAMActivityRecord *> *records = [logger readRecords];
  XCTAssertEqual(2, [records count]);
}

- (void)testReadingAndWritingCache {
  FIRIAMActivityLogger *logger = [[FIRIAMActivityLogger alloc] initWithMaxCountBeforeReduce:100
                                                                        withSizeAfterReduce:50
                                                                                verboseMode:YES
                                                                              loadFromCache:NO];

  FIRIAMActivityRecord *next =
      [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeRenderMessage
                                            isSuccessful:NO
                                              withDetail:@"log detail"
                                               timestamp:nil];
  [logger addLogRecord:next];
  next = [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForOnOpenMessage
                                               isSuccessful:NO
                                                 withDetail:@"log detail2"
                                                  timestamp:nil];
  [logger addLogRecord:next];
  next = [[FIRIAMActivityRecord alloc] initWithActivityType:FIRIAMActivityTypeCheckForOnOpenMessage
                                               isSuccessful:NO
                                                 withDetail:@"log detail3"
                                                  timestamp:nil];
  [logger addLogRecord:next];

  NSString *cacheFilePath = [NSString stringWithFormat:@"%@/temp-cache", NSTemporaryDirectory()];
  [logger saveIntoCacheWithPath:cacheFilePath];

  // read it back
  FIRIAMActivityLogger *logger2 = [[FIRIAMActivityLogger alloc] initWithMaxCountBeforeReduce:100
                                                                         withSizeAfterReduce:50
                                                                                 verboseMode:YES
                                                                               loadFromCache:NO];
  [logger2 loadFromCachePath:cacheFilePath];

  XCTAssertEqual(3, [[logger2 readRecords] count]);
}
@end
