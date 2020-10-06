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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

// TODO - FIRLoggerTest should be split into a separate FIRLoggerTest and GULLoggerTest.
// No test should include both includes.
#import <GoogleUtilities/GULLogger.h>
#import "FirebaseCore/Sources/Private/FIRLogger.h"

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
  XCTAssertEqualObjects(kFIRLoggerAnalytics, @"[Firebase/Analytics]");
  XCTAssertEqualObjects(kFIRLoggerCore, @"[Firebase/Core]");
  XCTAssertEqualObjects(kFIRLoggerMLKit, @"[Firebase/MLKit]");
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

@end
#endif
