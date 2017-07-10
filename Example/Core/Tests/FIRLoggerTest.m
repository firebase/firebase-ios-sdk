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

#import "FirebaseCommunity/FIRLogger.h"
#import "FIRTestCase.h"

#import <asl.h>

// The following constants are exposed from FIRLogger for unit tests.
extern NSString *const kFIRDisableDebugModeApplicationArgument;
extern NSString *const kFIREnableDebugModeApplicationArgument;

extern NSString *const kFIRPersistedDebugModeKey;

extern const char *kFIRLoggerASLClientFacilityName;

extern const char *kFIRLoggerCustomASLMessageFormat;

extern void FIRResetLogger();

extern aslclient getFIRLoggerClient();

extern dispatch_queue_t getFIRClientQueue();

extern BOOL getFIRLoggerDebugMode();

// Define the message format again to make sure the format doesn't accidentally change.
static NSString *const kCorrectASLMessageFormat =
    @"$((Time)(J.3)) $(Sender)[$(PID)] <$((Level)(str))> $Message";

static NSString *const kMessageCode = @"I-COR000001";

@interface FIRLoggerTest : FIRTestCase

@property(nonatomic) NSString *randomLogString;

@end

@implementation FIRLoggerTest

- (void)setUp {
  [super setUp];
  FIRResetLogger();
}

// Test some stable variables to make sure they weren't accidently changed.
- (void)testStableVariables {
  // kFIRLoggerCustomASLMessageFormat.
  XCTAssertEqualObjects(kCorrectASLMessageFormat,
                        [NSString stringWithUTF8String:kFIRLoggerCustomASLMessageFormat]);

  // Strings of type FIRLoggerServices.
  XCTAssertEqualObjects(kFIRLoggerABTesting, @"[Firebase/ABTesting]");
  XCTAssertEqualObjects(kFIRLoggerAdMob, @"[Firebase/AdMob]");
  XCTAssertEqualObjects(kFIRLoggerAnalytics, @"[Firebase/Analytics]");
  XCTAssertEqualObjects(kFIRLoggerAuth, @"[Firebase/Auth]");
  XCTAssertEqualObjects(kFIRLoggerCore, @"[Firebase/Core]");
  XCTAssertEqualObjects(kFIRLoggerCrash, @"[Firebase/Crash]");
  XCTAssertEqualObjects(kFIRLoggerDatabase, @"[Firebase/Database]");
  XCTAssertEqualObjects(kFIRLoggerDynamicLinks, @"[Firebase/DynamicLinks]");
  XCTAssertEqualObjects(kFIRLoggerInstanceID, @"[Firebase/InstanceID]");
  XCTAssertEqualObjects(kFIRLoggerInvites, @"[Firebase/Invites]");
  XCTAssertEqualObjects(kFIRLoggerMessaging, @"[Firebase/Messaging]");
  XCTAssertEqualObjects(kFIRLoggerRemoteConfig, @"[Firebase/RemoteConfig]");
  XCTAssertEqualObjects(kFIRLoggerStorage, @"[Firebase/Storage]");
}

- (void)testInitializeASLForNonDebugMode {
  // Stub.
  id processInfoMock = [OCMockObject partialMockForObject:[NSProcessInfo processInfo]];
  NSArray *arguments = @[ kFIRDisableDebugModeApplicationArgument ];
  [[[processInfoMock stub] andReturn:arguments] arguments];

  // Test.
  FIRLogError(kFIRLoggerCore, kMessageCode, @"Some error.");

  // Assert.
  NSNumber *debugMode =
      [[NSUserDefaults standardUserDefaults] objectForKey:kFIRPersistedDebugModeKey];
  XCTAssertNil(debugMode);
  XCTAssertFalse(getFIRLoggerDebugMode());

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

  // Assert.
  NSNumber *debugMode =
      [[NSUserDefaults standardUserDefaults] objectForKey:kFIRPersistedDebugModeKey];
  XCTAssertTrue(debugMode.boolValue);
  XCTAssertTrue(getFIRLoggerDebugMode());

  // Stop.
  [processInfoMock stopMocking];
}

- (void)testInitializeASLForDebugModeWithUserDefaults {
  // Stub.
  id userDefaultsMock = [OCMockObject partialMockForObject:[NSUserDefaults standardUserDefaults]];
  NSNumber *debugMode = @YES;
  [[[userDefaultsMock stub] andReturnValue:debugMode] boolForKey:kFIRPersistedDebugModeKey];

  // Test.
  FIRLogError(kFIRLoggerCore, kMessageCode, @"Some error.");

  // Assert.
  debugMode = [[NSUserDefaults standardUserDefaults] objectForKey:kFIRPersistedDebugModeKey];
  XCTAssertTrue(debugMode.boolValue);
  XCTAssertTrue(getFIRLoggerDebugMode());

  // Stop.
  [userDefaultsMock stopMocking];
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
  XCTAssertThrows(FIRLogError(kFIRLoggerCore, nil, @"Message."));
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
#if !(BUG128) // Disable until https://github.com/firebase/firebase-ios-sdk/issues/128 is fixed
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
  NSString *correctMsg = [NSString stringWithFormat:@"%@[%@] %@", kFIRLoggerCore, kMessageCode,
      self.randomLogString];
  return [self messageWasLogged:correctMsg];
}


- (void)drainFIRClientQueue {
  dispatch_semaphore_t workerSemaphore = dispatch_semaphore_create(0);
  dispatch_async(getFIRClientQueue(), ^{
    dispatch_semaphore_signal(workerSemaphore);
  });
  dispatch_semaphore_wait(workerSemaphore, DISPATCH_TIME_FOREVER);
}

- (BOOL)messageWasLogged:(NSString *)message {
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  asl_set_query(query, ASL_KEY_FACILITY, kFIRLoggerASLClientFacilityName, ASL_QUERY_OP_EQUAL);
  aslresponse r = asl_search(getFIRLoggerClient(), query);
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
}

@end
