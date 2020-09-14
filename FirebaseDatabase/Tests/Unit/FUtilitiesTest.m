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
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseReference_Private.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabase_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/FClock.h"
#import "FirebaseDatabase/Sources/FIRDatabaseConfig_Private.h"
#import "FirebaseDatabase/Sources/Realtime/FWebSocketConnection.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FWebSocketConnection (Tests)
- (NSString *)userAgent;
@end

@interface FUtilitiesTest : XCTestCase

@end

@implementation FUtilitiesTest

- (void)testUrlWithSchema {
  FParsedUrl *parsedUrl = [FUtilities parseUrl:@"https://repo.firebaseio.com"];
  XCTAssertEqualObjects(parsedUrl.repoInfo.host, @"repo.firebaseio.com");
  XCTAssertEqualObjects(parsedUrl.repoInfo.namespace, @"repo");
  XCTAssertTrue(parsedUrl.repoInfo.secure);
  XCTAssertEqualObjects(parsedUrl.path, [FPath empty]);

  parsedUrl = [FUtilities parseUrl:@"wss://repo.firebaseio.com"];
  XCTAssertEqualObjects(parsedUrl.repoInfo.host, @"repo.firebaseio.com");
  XCTAssertEqualObjects(parsedUrl.repoInfo.namespace, @"repo");
  XCTAssertTrue(parsedUrl.repoInfo.secure);
  XCTAssertEqualObjects(parsedUrl.path, [FPath empty]);
}

- (void)testUrlParsedWithoutSchema {
  FParsedUrl *parsedUrl = [FUtilities parseUrl:@"repo.firebaseio.com"];
  XCTAssertEqualObjects(parsedUrl.repoInfo.host, @"repo.firebaseio.com");
  XCTAssertEqualObjects(parsedUrl.repoInfo.namespace, @"repo");
  XCTAssertTrue(parsedUrl.repoInfo.secure);
  XCTAssertEqualObjects(parsedUrl.path, [FPath empty]);
}

- (void)testUrlParsedUsesSpaceInsteadOfPlus {
  FParsedUrl *parsedUrl = [FUtilities parseUrl:@"repo.firebaseio.com/+"];
  XCTAssertEqualObjects(parsedUrl.path, [FPath pathWithString:@"/ "]);
}

- (void)testUrlParsedWithSpecialCharacters {
  FParsedUrl *parsedUrl = [FUtilities parseUrl:@"repo.firebaseio.com/a%b&c@d/space: /non-ascii:ø"];
  XCTAssertEqualObjects(parsedUrl.path, [FPath pathWithString:@"/a%b&c@d/space: /non-ascii:ø"]);
}

- (void)testUrlParsedWithNamespace {
  FParsedUrl *parsedUrl = [FUtilities parseUrl:@"localhost/?ns=mrschmidt"];
  XCTAssertEqualObjects(parsedUrl.repoInfo.namespace, @"mrschmidt");

  parsedUrl = [FUtilities parseUrl:@"127.0.0.1:9000/?ns=mrschmidt"];
  XCTAssertEqualObjects(parsedUrl.repoInfo.namespace, @"mrschmidt");
}

- (void)testUrlParsedWithSslDetection {
  // Hosts with custom ports are considered non-secure
  FParsedUrl *parsedUrl = [FUtilities parseUrl:@"repo.firebaseio.com:9000"];
  XCTAssertFalse(parsedUrl.repoInfo.secure);

  // Hosts with omitted ports are considered secure
  parsedUrl = [FUtilities parseUrl:@"repo.firebaseio.com"];
  XCTAssertTrue(parsedUrl.repoInfo.secure);
}

- (void)testDefaultCacheSizeIs10MB {
  XCTAssertEqual([FTestHelpers defaultConfig].persistenceCacheSizeBytes,
                 (NSUInteger)10 * 1024 * 1024);
  XCTAssertEqual([FTestHelpers configForName:@"test-config"].persistenceCacheSizeBytes,
                 (NSUInteger)10 * 1024 * 1024);
}

- (void)testSettingCacheSizeToHighOrToLowThrows {
  FIRDatabaseConfig *config = [FTestHelpers configForName:@"config-tests-config"];
  config.persistenceCacheSizeBytes = 5 * 1024 * 1024;  // Works fine
  XCTAssertThrows(config.persistenceCacheSizeBytes = (1024 * 1024 - 1));
  XCTAssertThrows(config.persistenceCacheSizeBytes = 100 * 1024 * 1024 + 1);
}

- (void)testSystemClockMatchesCurrentTime {
  NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
  // Accuracy within 10ms
  XCTAssertEqualWithAccuracy(currentTime, [[FSystemClock clock] currentTime], 0.010);
}

// This test is here for a lack of a better place to put it
- (void)testUserAgentString {
  FWebSocketConnection *conn = [[FWebSocketConnection alloc] init];

  NSString *agent = [conn performSelector:@selector(userAgent) withObject:nil];

  NSArray *parts = [agent componentsSeparatedByString:@"/"];
  XCTAssertEqual(parts.count, (NSUInteger)5);
  XCTAssertEqualObjects(parts[0], @"Firebase");
  XCTAssertEqualObjects(parts[1], kWebsocketProtocolVersion);   // Wire protocol version
  XCTAssertEqualObjects(parts[2], [FIRDatabase buildVersion]);  // Build version
#if TARGET_OS_IPHONE
  XCTAssertEqualObjects(parts[3], [[UIDevice currentDevice] systemVersion]);  // iOS Version
  NSString *deviceName = [UIDevice currentDevice].model;
  XCTAssertEqualObjects([parts[4] componentsSeparatedByString:@"_"][0], deviceName);
#endif
}

- (void)testKeyComparison {
  NSArray *order = @[
    @"-2147483648", @"0", @"1", @"2", @"10", @"2147483647",  // Treated as integers
    @"-2147483649", @"-2147483650", @"-a", @"2147483648", @"21474836480", @"2147483649",
    @"a"  // treated as strings
  ];
  for (NSInteger i = 0; i < order.count; i++) {
    for (NSInteger j = i + 1; j < order.count; j++) {
      NSString *first = order[i];
      NSString *second = order[j];
      XCTAssertEqual([FUtilities compareKey:first toKey:second], NSOrderedAscending,
                     @"Expected %@ < %@", first, second);
      XCTAssertEqual([FUtilities compareKey:first toKey:first], NSOrderedSame, @"Expected %@ == %@",
                     first, first);
      XCTAssertEqual([FUtilities compareKey:second toKey:first], NSOrderedDescending,
                     @"Expected %@ > %@", second, first);
    }
  }
}

// Enforce a > b, b < a, a != b, because this is apparently something that happens semi-regularly
- (void)testUnicodeKeyComparison {
  XCTAssertEqual([FUtilities compareKey:@"유주연" toKey:@"윤규완오빠"], NSOrderedAscending);
  XCTAssertEqual([FUtilities compareKey:@"윤규완오빠" toKey:@"유주연"], NSOrderedDescending);
  XCTAssertNotEqual([FUtilities compareKey:@"윤규완오빠" toKey:@"유주연"], NSOrderedSame);
}

@end
