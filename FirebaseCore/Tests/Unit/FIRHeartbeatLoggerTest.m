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

#if SWIFT_PACKAGE
@import HeartbeatLoggingTestUtils;
#else
#import <HeartbeatLoggingTestUtils/HeartbeatLoggingTestUtils-Swift.h>
#endif  // SWIFT_PACKAGE

#import "FirebaseCore/Sources/Private/FIRHeartbeatLogger.h"

@interface FIRHeartbeatLogger (Internal)
- (instancetype)initWithAppID:(NSString *)appID
            userAgentProvider:(NSString * (^)(void))userAgentProvider;
@end

@interface FIRHeartbeatLoggerTest : XCTestCase
@property(nonatomic) FIRHeartbeatLogger *heartbeatLogger;
@end

@implementation FIRHeartbeatLoggerTest

+ (NSString *)dummyAppID {
  return NSStringFromClass([self class]);
}

+ (NSString * (^)(void))dummyUserAgentProvider {
  return ^NSString * {
    return @"dummy_agent";
  };
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

  // When
  [heartbeatLogger log];
  [heartbeatLogger log];

  // Then
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];

  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ @"2021-12-22" ]} ]
              }];
}

- (void)testDoNotLogMoreThanOnceToday_AfterFlushing {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  [heartbeatLogger log];
  FIRHeartbeatsPayload *firstHeartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  [heartbeatLogger log];
  FIRHeartbeatsPayload *secondHeartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(firstHeartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ @"2021-12-22" ]} ]
              }];

  [self assertHeartbeatsPayloadIsEmpty:secondHeartbeatsPayload];
}

- (void)testFlushing_UsingV1API_WhenHeartbeatsAreStored_ReturnsFIRHeartbeatInfoCodeGlobal {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  [heartbeatLogger log];
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCode];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeGlobal);
}

- (void)testFlushing_UsingV1API_WhenNoHeartbeatsAreStored_ReturnsFIRHeartbeatInfoCodeNone {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCode];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeNone);
}

- (void)testFlushing_UsingV2API_WhenHeartbeatsAreStored_ReturnsNonEmptyPayload {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  // When
  [heartbeatLogger log];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ @"2021-12-22" ]} ]
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
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCode];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // Then
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeGlobal);
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

- (void)testLogAndFlushUsingV2API_AndThenFlushAgainUsingV1API_FlushesHeartbeatInTheFirstFlush {
  // Given
  FIRHeartbeatLogger *heartbeatLogger = self.heartbeatLogger;
  [heartbeatLogger log];
  // When
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  FIRHeartbeatInfoCode heartbeatInfoCode = [heartbeatLogger heartbeatCode];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ @"2021-12-22" ]} ]
              }];
  XCTAssertEqual(heartbeatInfoCode, FIRHeartbeatInfoCodeNone);
}

- (void)testHeartbeatLoggersWithSameIDShareTheSameStorage {
  // Given
  FIRHeartbeatLogger *heartbeatLogger1 =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  FIRHeartbeatLogger *heartbeatLogger2 =
      [[FIRHeartbeatLogger alloc] initWithAppID:[[self class] dummyAppID]
                              userAgentProvider:[[self class] dummyUserAgentProvider]];
  // When
  [heartbeatLogger1 log];
  // Then
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger2 flushHeartbeatsIntoPayload];
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent", @"dates" : @[ @"2021-12-22" ]} ]
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
  [heartbeatLogger log];
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  // When
  dummyUserAgent = @"dummy_agent_2";
  [heartbeatLogger log];
  // Then
  [self assertEncodedPayloadHeader:FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload)
              isEqualToPayloadJSON:@{
                @"version" : @2,
                @"heartbeats" : @[ @{@"agent" : @"dummy_agent_1", @"dates" : @[ @"2021-12-22" ]} ]
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
  XCTAssertEqualObjects(FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload), @"");
}

- (void)assertHeartbeatLoggerFlushesEmptyPayload:(FIRHeartbeatLogger *)heartbeatLogger {
  FIRHeartbeatsPayload *heartbeatsPayload = [heartbeatLogger flushHeartbeatsIntoPayload];
  [self assertHeartbeatsPayloadIsEmpty:heartbeatsPayload];
}

@end
