// Copyright 2019 Google
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

#import "GULOSLogger.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULLogger.h>
#import <GoogleUtilities/GULSwizzler.h>

#import <os/log.h>

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const kService = @"my service";
static NSString *const kCode = @"I-COR000001";
static NSTimeInterval const kTimeout = 1.0;

// Expectation that contains the information needed to see if the correct parameters were used in an
// os_log_with_type call.
@interface GULOSLoggerExpectation : XCTestExpectation

@property(nonatomic, nullable) os_log_t log;
@property(nonatomic) os_log_type_t type;
@property(nonatomic) NSString *message;

- (instancetype)initWithLog:(nullable os_log_t)log
                       type:(os_log_type_t)type
                    message:(NSString *)message;
@end

@implementation GULOSLoggerExpectation
- (instancetype)initWithLog:(nullable os_log_t)log
                       type:(os_log_type_t)type
                    message:(NSString *)message {
  self = [super
      initWithDescription:[NSString
                              stringWithFormat:@"os_log_with_type(%@, %iu, %@) was not called.",
                                               log, type, message]];
  if (self) {
    _log = log;
    _type = type;
    _message = message;
  }
  return self;
}
@end

// List of expectations that may be fulfilled in the current test.
static NSMutableArray<GULOSLoggerExpectation *> *sExpectations;

// Function that will be called by GULOSLogger instead of os_log_with_type.
void GULTestOSLogWithType(os_log_t log, os_log_type_t type, char *s, ...) {
  // Grab the first variable argument.
  va_list args;
  va_start(args, s);
  NSString *message = [NSString stringWithUTF8String:va_arg(args, char *)];
  va_end(args);

  // Look for an expectation that meets these parameters.
  for (GULOSLoggerExpectation *expectation in sExpectations) {
    if ((expectation.log == nil || expectation.log == log) && expectation.type == type &&
        [message containsString:expectation.message]) {
      [expectation fulfill];
      return;  // Only fulfill one expectation per call.
    }
  }
}

#pragma mark -

// Redefine class property as readwrite for testing.
@interface GULLogger (ForTesting)
@property(nonatomic, nullable, class, readwrite) id<GULLoggerSystem> logger;
@end

// Surface osLog and dispatchQueues for tests.
@interface GULOSLogger (ForTesting)
@property(nonatomic) NSMutableDictionary<NSString *, os_log_t> *categoryLoggers;
@property(nonatomic) dispatch_queue_t dispatchQueue;
@property(nonatomic, unsafe_unretained) void (*logFunction)(os_log_t, os_log_type_t, char *, ...);
@end

#pragma mark -

@interface GULOSLoggerTest : XCTestCase
@property(nonatomic, nullable) GULOSLogger *osLogger;
@property(nonatomic, nullable) id mock;
@property(nonatomic) BOOL appStoreWasSwizzled;
@end

@implementation GULOSLoggerTest

- (void)setAppStoreTo:(BOOL)fromAppStore {
  [GULSwizzler swizzleClass:[GULAppEnvironmentUtil class]
                   selector:@selector(isFromAppStore)
            isClassSelector:YES
                  withBlock:^BOOL() {
                    return fromAppStore;
                  }];
  self.appStoreWasSwizzled = YES;
}

- (void)partialMockLogger {
  // Add the ability to intercept calls to the instance under test
  self.mock = OCMPartialMock(self.osLogger);
  GULLogger.logger = self.mock;
}

- (void)setUp {
  [super setUp];
  // Setup globals and create the instance under test.
  sExpectations = [[NSMutableArray<GULOSLoggerExpectation *> alloc] init];
  self.osLogger = [[GULOSLogger alloc] init];
  self.osLogger.logFunction = &GULTestOSLogWithType;
}

- (void)tearDown {
  // Clear globals
  sExpectations = nil;
  GULLogger.logger = nil;
  [self.mock stopMocking];
  self.mock = nil;
  if (self.appStoreWasSwizzled) {
    [GULSwizzler unswizzleClass:[GULAppEnvironmentUtil class]
                       selector:@selector(isFromAppStore)
                isClassSelector:YES];
    self.appStoreWasSwizzled = NO;
  }
  [super tearDown];
}

#pragma mark Tests

- (void)testInit {
  // First, there are no loggers created.
  XCTAssertNil(self.osLogger.categoryLoggers);

  // After initializeLogger, there should be an empty dictionary ready, for loggers.
  [self.osLogger initializeLogger];
  NSDictionary *loggers = self.osLogger.categoryLoggers;
  XCTAssertNotNil(loggers);

  // Calling initializeLogger logger again, should change the dictionary instance.
  [self.osLogger initializeLogger];
  XCTAssertEqual(loggers, self.osLogger.categoryLoggers);
}

- (void)testSetLogLevelValid {
  // Setting the log level to something valid should not result in an error message.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-security"
  OCMReject([self.mock logWithLevel:GULLoggerLevelError
                        withService:OCMOCK_ANY
                           isForced:NO
                           withCode:OCMOCK_ANY
                        withMessage:OCMOCK_ANY]);
#pragma clang diagnostic pop
  self.osLogger.logLevel = GULLoggerLevelWarning;
  OCMVerifyAll(self.mock);
}

- (void)testSetLogLevelInvalid {
  // The logger should log an error for invalid levels.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-security"
  OCMExpect([[self.mock stub] logWithLevel:GULLoggerLevelError
                               withService:OCMOCK_ANY
                                  isForced:YES
                                  withCode:OCMOCK_ANY
                               withMessage:OCMOCK_ANY]);
  self.osLogger.logLevel = GULLoggerLevelMin - 1;

  OCMExpect([[self.mock stub] logWithLevel:GULLoggerLevelError
                               withService:OCMOCK_ANY
                                  isForced:YES
                                  withCode:OCMOCK_ANY
                               withMessage:OCMOCK_ANY]);
#pragma clang diagnostic push
  self.osLogger.logLevel = GULLoggerLevelMax + 1;
  OCMVerifyAll(self.mock);
}

- (void)testLogLevelAppStore {
  // When not from the App Store, all log levels should be allowed.
  [self setAppStoreTo:NO];
  self.osLogger.logLevel = GULLoggerLevelMin;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelMin);
  self.osLogger.logLevel = GULLoggerLevelMax;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelMax);

  // When from the App store, levels that are Notice or above, should be silently ignored.
  [self setAppStoreTo:YES];
  self.osLogger.logLevel = GULLoggerLevelError;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelError);
  self.osLogger.logLevel = GULLoggerLevelWarning;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelWarning);
  self.osLogger.logLevel = GULLoggerLevelNotice;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelWarning);
  self.osLogger.logLevel = GULLoggerLevelInfo;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelWarning);
  self.osLogger.logLevel = GULLoggerLevelDebug;
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelWarning);
}

- (void)testForceDebug {
  [self partialMockLogger];
  [self setAppStoreTo:NO];
  XCTAssertFalse(self.osLogger.forcedDebug);
  GULLoggerForceDebug();
  XCTAssertTrue(self.osLogger.forcedDebug);
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelDebug);
}

- (void)testForceDebugAppStore {
  [self partialMockLogger];
  [self setAppStoreTo:YES];
  self.osLogger.logLevel = GULLoggerLevelWarning;
  XCTAssertFalse(self.osLogger.forcedDebug);
  GULLoggerForceDebug();
  XCTAssertFalse(self.osLogger.forcedDebug);
  XCTAssertEqual(self.osLogger.logLevel, GULLoggerLevelWarning);
}

- (void)testLoggingValidNoVarArgs {
  [self.osLogger initializeLogger];
  XCTAssert(self.osLogger.categoryLoggers.count == 0);
  NSString *message = [NSUUID UUID].UUIDString;
  GULOSLoggerExpectation *expectation =
      [[GULOSLoggerExpectation alloc] initWithLog:nil type:OS_LOG_TYPE_DEFAULT message:message];
  [sExpectations addObject:expectation];
  [self.osLogger logWithLevel:GULLoggerLevelNotice
                  withService:kService
                     isForced:NO
                     withCode:kCode
                  withMessage:message];
  [self waitForExpectations:sExpectations timeout:kTimeout];
}

- (void)testLoggingValidWithVarArgs {
  [self.osLogger initializeLogger];
  XCTAssert(self.osLogger.categoryLoggers.count == 0);
  NSString *message = [NSUUID UUID].UUIDString;
  GULOSLoggerExpectation *expectation =
      [[GULOSLoggerExpectation alloc] initWithLog:nil type:OS_LOG_TYPE_DEFAULT message:message];
  [sExpectations addObject:expectation];
  [self.osLogger logWithLevel:GULLoggerLevelNotice
                  withService:kService
                     isForced:NO
                     withCode:kCode
                  withMessage:message];
  [self waitForExpectations:sExpectations timeout:kTimeout];
}

@end

NS_ASSUME_NONNULL_END
