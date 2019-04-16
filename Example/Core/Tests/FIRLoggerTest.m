// Copyright 2017 Google
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

#import "FIRTestCase.h"

// TODO - FIRLoggerTest should be split into a separate FIRLoggerTest and GULLoggerTest.
// No test should include both includes.
#import <FirebaseCore/FIRLogger.h>
#import <GoogleUtilities/GULLogger.h>

#import <asl.h>

// The following constants are exposed from FIRLogger for unit tests.
extern NSString *const kFIRDisableDebugModeApplicationArgument;
extern NSString *const kFIREnableDebugModeApplicationArgument;

/// Key for the debug mode bit in NSUserDefaults.
extern NSString *const kFIRPersistedDebugModeKey;

extern const char *kGULLoggerASLClientFacilityName;

extern void FIRResetLogger(void);

extern void FIRSetLoggerUserDefaults(NSUserDefaults *defaults);

extern aslclient getGULLoggerClient(void);

extern dispatch_queue_t getGULClientQueue(void);

extern BOOL getGULLoggerDebugMode(void);

static NSString *const kMessageCode = @"I-COR000001";

@interface FIRLoggerTest : FIRTestCase

@property(nonatomic) NSString *randomLogString;

@property(nonatomic, strong) NSUserDefaults *defaults;

@end

@implementation FIRLoggerTest

- (void)setUp {
  [super setUp];
  FIRResetLogger();

  // Stub NSUserDefaults for cleaner testing.
  _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.firebase.logger_test"];
  FIRSetLoggerUserDefaults(_defaults);
}

- (void)tearDown {
  [super tearDown];

  _defaults = nil;
}

// Test some stable variables to make sure they weren't accidently changed.
- (void)testStableVariables {
  // Strings of type FIRLoggerServices.
  XCTAssertEqualObjects(kFIRLoggerABTesting, @"[Firebase/ABTesting]");
  XCTAssertEqualObjects(kFIRLoggerAdMob, @"[Firebase/AdMob]");
  XCTAssertEqualObjects(kFIRLoggerAnalytics, @"[Firebase/Analytics]");
  XCTAssertEqualObjects(kFIRLoggerCore, @"[Firebase/Core]");
  XCTAssertEqualObjects(kFIRLoggerMLKit, @"[Firebase/MLKit]");
  XCTAssertEqualObjects(kFIRLoggerRemoteConfig, @"[Firebase/RemoteConfig]");
}

- (void)testInitializeASLForNonDebugMode {
  // Stub.
  id processInfoMock = [OCMockObject partialMockForObject:[NSProcessInfo processInfo]];
  NSArray *arguments = @[ kFIRDisableDebugModeApplicationArgument ];
  [[[processInfoMock stub] andReturn:arguments] arguments];

  // Test.
  FIRLogError(kFIRLoggerCore, kMessageCode, @"Some error.");

  // Assert.
#if MAKE_THREAD_SAFE
  NSNumber *debugMode = [self.defaults objectForKey:kFIRPersistedDebugModeKey];
  XCTAssertNil(debugMode);
  XCTAssertFalse(getGULLoggerDebugMode());
#endif

  // Stop.
  [processInfoMock stopMocking];
}

- (void)testInitializeASLForDebugModeWithArgument {
  // Stub.
  id processInfoMock = [OCMockObject partialMockForObject:[NSProcessInfo processInfo]];
  NSArray *arguments = @[ kFIREnableDebugModeApplicationArgument ];
  [[[processInfoMock stub] andReturn:arguments] arguments];

  // Test.
  FIRLogError(kFIRLoggerCore, kMessageCode, @"Some error.");

#ifdef MAKE_THREAD_SAFE
  // Assert.
  NSNumber *debugMode = [self.defaults objectForKey:kGULPersistedDebugModeKey];
  XCTAssertTrue(debugMode.boolValue);
  XCTAssertTrue(getGULLoggerDebugMode());
#endif

  // Stop.
  [processInfoMock stopMocking];
}

- (void)testInitializeASLForDebugModeWithUserDefaults {
  // Stub.
  NSNumber *debugMode = @YES;
  [self.defaults setBool:debugMode.boolValue forKey:kFIRPersistedDebugModeKey];

  // Test.
  GULLogError(@"my service", NO, kMessageCode, @"Some error.");

  // Assert.
  debugMode = [self.defaults objectForKey:kFIRPersistedDebugModeKey];
  XCTAssertTrue(debugMode.boolValue);
}

- (void)testMessageCodeFormat {
  // Valid case.
  XCTAssertNoThrow(FIRLogError(kFIRLoggerCore, @"I-APP000001", @"Message."));

  // An extra dash or missing dash should fail.
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"I-APP-000001", @"Message."));
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"IAPP000001", @"Message."));

  // Wrong number of digits should fail.
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"I-APP00001", @"Message."));
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"I-APP0000001", @"Message."));

  // Lowercase should fail.
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"I-app000001", @"Message."));

// nil or empty message code should fail.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, nil, @"Message."));
#pragma clang diagnostic pop

  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"", @"Message."));

  // Android message code should fail.
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, @"A-APP000001", @"Message."));
}

- (void)testLoggerInterface {
  XCTAssertNoThrow(FIRLogError(kFIRLoggerCore, kMessageCode, @"Message."));
  XCTAssertNoThrow(FIRLogError(kFIRLoggerCore, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(FIRLogWarning(kFIRLoggerCore, kMessageCode, @"Message."));
  XCTAssertNoThrow(FIRLogWarning(kFIRLoggerCore, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(FIRLogNotice(kFIRLoggerCore, kMessageCode, @"Message."));
  XCTAssertNoThrow(FIRLogNotice(kFIRLoggerCore, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(FIRLogInfo(kFIRLoggerCore, kMessageCode, @"Message."));
  XCTAssertNoThrow(FIRLogInfo(kFIRLoggerCore, kMessageCode, @"Configure %@.", @"blah"));

  XCTAssertNoThrow(FIRLogDebug(kFIRLoggerCore, kMessageCode, @"Message."));
  XCTAssertNoThrow(FIRLogDebug(kFIRLoggerCore, kMessageCode, @"Configure %@.", @"blah"));
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
  FIRLogError(kFIRLoggerCore, kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertTrue([self logExists]);

  self.randomLogString = [NSUUID UUID].UUIDString;
  FIRLogWarning(kFIRLoggerCore, kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertTrue([self logExists]);

  self.randomLogString = [NSUUID UUID].UUIDString;
  FIRLogNotice(kFIRLoggerCore, kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertTrue([self logExists]);

  // Log messages with Info level and above should NOT be logged to system/device by default.
  self.randomLogString = [NSUUID UUID].UUIDString;
  FIRLogInfo(kFIRLoggerCore, kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertFalse([self logExists]);

  self.randomLogString = [NSUUID UUID].UUIDString;
  FIRLogDebug(kFIRLoggerCore, kMessageCode, @"%@", self.randomLogString);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval]];
  XCTAssertFalse([self logExists]);
#endif
}

// The FIRLoggerLevel enum must match the ASL_LEVEL_* constants, but we manually redefine
// them in FIRLoggerLevel.h since we cannot include <asl.h> (see b/34976089 for more details).
// This test ensures the constants match.
- (void)testFIRLoggerLevelValues {
  XCTAssertEqual(FIRLoggerLevelError, ASL_LEVEL_ERR);
  XCTAssertEqual(FIRLoggerLevelWarning, ASL_LEVEL_WARNING);
  XCTAssertEqual(FIRLoggerLevelNotice, ASL_LEVEL_NOTICE);
  XCTAssertEqual(FIRLoggerLevelInfo, ASL_LEVEL_INFO);
  XCTAssertEqual(FIRLoggerLevelDebug, ASL_LEVEL_DEBUG);
}

// Helper functions.
- (BOOL)logExists {
  [self drainFIRClientQueue];
  NSString *correctMsg =
      [NSString stringWithFormat:@"%@[%@] %@", kFIRLoggerCore, kMessageCode, self.randomLogString];
  return [self messageWasLogged:correctMsg];
}

- (void)drainFIRClientQueue {
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
