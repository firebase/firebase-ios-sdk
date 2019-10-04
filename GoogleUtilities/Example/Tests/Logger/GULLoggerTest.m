// Copyright 2018 Google
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

#ifdef DEBUG
// The tests depend upon library methods only built with #ifdef DEBUG

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULLogger.h>

#import <asl.h>

extern const char *kGULLoggerASLClientFacilityName;

extern void GULResetLogger(void);

extern aslclient getGULLoggerClient(void);

extern dispatch_queue_t getGULClientQueue(void);

extern BOOL getGULLoggerDebugMode(void);

static NSString *const kMessageCode = @"I-COR000001";

@interface GULLoggerTest : XCTestCase

@property(nonatomic) NSString *randomLogString;

@property(nonatomic, strong) NSUserDefaults *defaults;

@end

@implementation GULLoggerTest

- (void)setUp {
  [super setUp];
  GULResetLogger();

  // Stub NSUserDefaults for cleaner testing.
  _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.google.logger_test"];
}

- (void)tearDown {
  [super tearDown];

  _defaults = nil;
}

- (void)testMessageCodeFormat {
  // Valid case.
  XCTAssertNoThrow(GULLogError(@"my service", NO, @"I-APP000001", @"Message."));

  // An extra dash or missing dash should fail.
  XCTAssertThrows(GULLogError(@"my service", NO, @"I-APP-000001", @"Message."));
  XCTAssertThrows(GULLogError(@"my service", NO, @"IAPP000001", @"Message."));

  // Wrong number of digits should fail.
  XCTAssertThrows(GULLogError(@"my service", NO, @"I-APP00001", @"Message."));
  XCTAssertThrows(GULLogError(@"my service", NO, @"I-APP0000001", @"Message."));

  // Lowercase should fail.
  XCTAssertThrows(GULLogError(@"my service", NO, @"I-app000001", @"Message."));

// nil or empty message code should fail.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows(GULLogError(@"my service", NO, nil, @"Message."));
#pragma clang diagnostic pop

  XCTAssertThrows(GULLogError(@"my service", NO, @"", @"Message."));

  // Android message code should fail.
  XCTAssertThrows(GULLogError(@"my service", NO, @"A-APP000001", @"Message."));
}

- (void)testLoggerInterface {
  XCTAssertNoThrow(GULLogError(@"my service", NO, kMessageCode, @"Message."));
  XCTAssertNoThrow(GULLogError(@"my service", NO, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogWarning(@"my service", NO, kMessageCode, @"Message."));
  XCTAssertNoThrow(GULLogWarning(@"my service", NO, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogNotice(@"my service", NO, kMessageCode, @"Message."));
  XCTAssertNoThrow(GULLogNotice(@"my service", NO, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogInfo(@"my service", NO, kMessageCode, @"Message."));
  XCTAssertNoThrow(GULLogInfo(@"my service", NO, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(GULLogDebug(@"my service", NO, kMessageCode, @"Message."));
  XCTAssertNoThrow(GULLogDebug(@"my service", NO, kMessageCode, @"Configure %@.", @"blah"));
}

// asl_set_filter does not perform as expected in unit test environment with simulator. The
// following test only checks whether the logs have been sent to system with the default settings in
// the unit test environment.
- (void)testSystemLogWithDefaultStatus {
#if !(BUG128)  // Disable until https://github.com/firebase/firebase-ios-sdk/issues/128 is fixed
  // Test fails on device and iOS 9 simulators - b/38130372
  return;
#else
  // Sets the time interval that we need to wait in order to fetch all the logs.
  NSTimeInterval timeInterval = 0.1f;
  // Generates a random string each time and check whether it has been logged.
  // Log messages with Notice level and below should be logged to system/device by default.
  self.randomLogString = [NSUUID UUID].UUIDString;
  GULLogError(@"my service", NO, kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertTrue([self logExists]);

  self.randomLogString = [NSUUID UUID].UUIDString;
  GULLogWarning(@"my service", kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertTrue([self logExists]);

  self.randomLogString = [NSUUID UUID].UUIDString;
  GULLogNotice(@"my service", kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertTrue([self logExists]);

  // Log messages with Info level and above should NOT be logged to system/device by default.
  self.randomLogString = [NSUUID UUID].UUIDString;
  GULLogInfo(@"my service", kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertFalse([self logExists]);

  self.randomLogString = [NSUUID UUID].UUIDString;
  GULLogDebug(@"my service", kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertFalse([self logExists]);
#endif
}

// The GULLoggerLevel enum must match the ASL_LEVEL_* constants, but we manually redefine
// them in GULLoggerLevel.h since we cannot include <asl.h> (see b/34976089 for more details).
// This test ensures the constants match.
- (void)testGULLoggerLevelValues {
  XCTAssertEqual(GULLoggerLevelError, ASL_LEVEL_ERR);
  XCTAssertEqual(GULLoggerLevelWarning, ASL_LEVEL_WARNING);
  XCTAssertEqual(GULLoggerLevelNotice, ASL_LEVEL_NOTICE);
  XCTAssertEqual(GULLoggerLevelInfo, ASL_LEVEL_INFO);
  XCTAssertEqual(GULLoggerLevelDebug, ASL_LEVEL_DEBUG);
}

// Helper functions.
- (BOOL)logExists {
  [self drainGULClientQueue];
  NSString *correctMsg =
      [NSString stringWithFormat:@"%@[%@] %@", @"my service", kMessageCode, self.randomLogString];
  return [self messageWasLogged:correctMsg];
}

- (void)drainGULClientQueue {
  dispatch_semaphore_t workerSemaphore = dispatch_semaphore_create(0);
  dispatch_async(getGULClientQueue(), ^{
    dispatch_semaphore_signal(workerSemaphore);
  });
  dispatch_semaphore_wait(workerSemaphore, DISPATCH_TIME_FOREVER);
}

- (BOOL)messageWasLogged:(NSString *)message {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  asl_set_query(query, ASL_KEY_FACILITY, kGULLoggerASLClientFacilityName, ASL_QUERY_OP_EQUAL);
  aslresponse r = asl_search(getGULLoggerClient(), query);
  asl_free(query);
  aslmsg m;
  const char *val;
  NSMutableArray *allMsg = [[NSMutableArray alloc] init];
  while ((m = asl_next(r)) != NULL) {
    val = asl_get(m, ASL_KEY_MSG);
    if (val) {
      [allMsg addObject:[NSString stringWithUTF8String:val]];
    }
  }
  asl_free(m);
  asl_release(r);
  return [allMsg containsObject:message];
#pragma clang pop
}

@end
#endif
