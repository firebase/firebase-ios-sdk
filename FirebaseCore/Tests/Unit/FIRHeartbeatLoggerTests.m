// Copyright 2021 Google LLC
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

#import <XCTest/XCTest.h>

@import FirebaseCoreInternal;

#import "FirebaseCore/Extension/FIRHeartbeatLogger.h"

@interface FIRHeartbeatLogger (Internal)
- (instancetype)initWithAppID:(NSString *)appID
            userAgentProvider:(NSString * (^)(void))userAgentProvider;
@end

@interface FIRHeartbeatLoggerTests : XCTestCase
@property(nonatomic) FIRHeartbeatLogger *heartbeatLogger;
@end

@implementation FIRHeartbeatLoggerTests

+ (NSString *)dummyAppID {
  return NSStringFromClass([self class]);
}

+ (NSString * (^)(void))dummyUserAgentProvider {
  return ^NSString * {
    return @"dummy_agent";
  };
}

+ (NSString *)formattedStringForDate:(NSDate *)date {
  return [[FIRHeartbeatLoggingTestUtils dateFormatter] stringFromDate:date];
}

- (void)setUp {
  _heartbeatLogger =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  [FIRHeartbeatLoggingTestUtils removeUnderlyingHeartbeatStorageContainersAndReturnError:nil];
}

- (void)tearDown {
  [FIRHeartbeatLoggingTestUtils removeUnderlyingHeartbeatStorageContainersAndReturnError:nil];
}

- (void)testDoNotLogMoreThanOnceToday {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger log];
  [heartbeatLogger log];

  // Then
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];

  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
}

- (void)testDoNotLogMoreThanOnceToday_AfterFlushing {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger log];
  FIRHeartbeatsPayload *firstHeartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  [heartbeatLogger log];
  FIRHeartbeatsPayload *secondHeartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(firstHeartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];

  [self assertHeartbeatsPayloadIsEmpty:secondHeartbeatsPayload];
}

- (void)testFlushing_UsingV1API_WhenHeartbeatsAreStored_ReturnsFIRDailyHeartbeatCodeSome {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  [heartbeatLogger log];
  FIRDailyHeartbeatCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRDailyHeartbeatCodeSome);
}

- (void)testFlushing_UsingV1API_WhenNoHeartbeatsAreStored_ReturnsFIRDailyHeartbeatCodeNone {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  FIRDailyHeartbeatCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRDailyHeartbeatCodeNone);
}

- (void)testFlushing_UsingV2API_WhenHeartbeatsAreStored_ReturnsNonEmptyPayload {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger log];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
}

- (void)testFlushing_UsingV2API_WhenNoHeartbeatsAreStored_ReturnsEmptyPayload {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

- (void)testLogAndFlushUsingV1API_AndThenFlushAgainUsingV2API_FlushesHeartbeatInTheFirstFlush {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  [heartbeatLogger log];
  // When
  FIRDailyHeartbeatCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRDailyHeartbeatCodeSome);
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

- (void)testLogAndFlushUsingV2API_AndThenFlushAgainUsingV1API_FlushesHeartbeatInTheFirstFlush {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  [heartbeatLogger log];
  // When
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  FIRDailyHeartbeatCode heartbeatInfoCode = [heartbeatLogger heartbeatCodeForToday];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
  XCTAssertEqual(heartbeatInfoCode, FIRDailyHeartbeatCodeNone);
}

- (void)testHeartbeatLoggersWithSameIDShareTheSameStorage {
  // Given
  FIRHeartbeatLogger *heartbeatLogger1 =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  FIRHeartbeatLogger *heartbeatLogger2 =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  // When
  [heartbeatLogger1 log];
  // Then
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger2 flushHeartbeatsIntoPayload];
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ expectedDate ]} ]
              }];
  [self assertHeartbeatLoggerFlushesEmptyPayload:heartbeatLogger1];
}

- (void)testLoggingAHeartbeatDoesNotDependOnUserAgent {
  // Given
  __block NSString *dummyUserAgent = @"dummy_agent_1";
  __auto_type dummyUserAgentProvider = ^NSString * {
    return dummyUserAgent;
  };
  FIRHeartbeatLogger *heartbeatLogger =
      [[FIRHeartbeatLogger alloc] initWithAppID:@"testLoggingAHeartbeatDoesNotDependOnUserAgent"
                              userAgentProvider:dummyUserAgentProvider];
  NSString *expectedDate = [[self class] formattedStringForDate:[NSDate date]];
  [heartbeatLogger log];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // When
  dummyUserAgent = @"dummy_agent_2";
  [heartbeatLogger log];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent_1", @"dates" : @[ expectedDate ]} ]
              }];
  [self assertHeartbeatLoggerFlushesEmptyPayload:heartbeatLogger];
}

#pragma mark - Assertions

- (void)assertEncodedPayloadHeader:(NSString *)payloadHeader
              isEqualToPayloadJSON:(NSDictionary *)payloadJSON {
  NSData *payloadJSONData = [NSJSONSerialization dataWithJSONObject:payloadJSON
                                                            options:NSJSONWritingPrettyPrinted
                                                              error:nil];
  NSString *payloadJSONString = [[NSString alloc] initWithData:payloadJSONData
                                                      encoding:NSUTF8StringEncoding];
  [FIRHeartbeatLoggingTestUtils assertEncodedPayloadString:payloadHeader
                                    isEqualToLiteralString:payloadJSONString
                                                 withError:nil];
}

- (void)assertHeartbeatsPayloadIsEmpty:(FIRHeartbeatsPayload *)heartbeatsPayload {
  XCTAssertNil(FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload));
}

- (void)assertHeartbeatLoggerFlushesEmptyPayload:(FIRHeartbeatLogger *)heartbeatLogger {
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

@end
