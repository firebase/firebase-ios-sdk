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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULLogger.h>

static GULLoggerLevel kLogLevel = GULLoggerLevelError;
static NSString *const kService = @"Test Service";
static NSString *const kCode = @"I-COR000001";
static NSString *const kLogMessage = @"Log Message";
static NSString *const kVersionString = @"2";
static char *const kVersionChar = "2";

// Redefine class property as readwrite for testing.
@interface GULLogger (ForTesting)
@property(nonatomic, class, readwrite) id<GULLoggerSystem> logger;
@end

#pragma mark -

@interface GULLoggerTest : XCTestCase
@property(nonatomic) id loggerSystemMock;
@end

@implementation GULLoggerTest

- (void)setUp {
  [super setUp];
  self.loggerSystemMock = OCMProtocolMock(@protocol(GULLoggerSystem));
  GULLogger.logger = self.loggerSystemMock;
}

- (void)tearDown {
  GULLogger.logger = nil;
  [self.loggerSystemMock stopMocking];
  self.loggerSystemMock = nil;
  [super tearDown];
}

#pragma mark Initialization Tests

- (void)testInitializeEmpty {
  [[self.loggerSystemMock expect] initializeLogger];
  GULLoggerInitialize();
  [self.loggerSystemMock verify];
}

- (void)testInitializeTwice {
  [[self.loggerSystemMock expect] initializeLogger];
  GULLoggerInitialize();
  GULLoggerInitialize();
  [self.loggerSystemMock verify];
}

#pragma mark Forwarded Call Tests

- (void)testForceDebug {
  [[self.loggerSystemMock expect] setForcedDebug:YES];
  GULLoggerForceDebug();
  [self.loggerSystemMock verify];
}

- (void)testEnableSTDERR {
  [[self.loggerSystemMock expect] printToSTDERR];
  GULLoggerEnableSTDERR();
  [self.loggerSystemMock verify];
}

- (void)testSetLoggerLevel {
  [[self.loggerSystemMock expect] setLogLevel:kLogLevel];
  GULSetLoggerLevel(kLogLevel);
  [self.loggerSystemMock verify];
}

- (void)testIsLoggableLevel {
  [[self.loggerSystemMock expect] isLoggableLevel:kLogLevel];
  GULIsLoggableLevel(kLogLevel);
  [self.loggerSystemMock verify];
}

- (void)testRegisterVersion {
  [[self.loggerSystemMock expect] setVersion:kVersionString];
  GULLoggerRegisterVersion(kVersionChar);
  [self.loggerSystemMock verify];
}

// TODO(bstpierre): Test that LogBasic calls are piped through. OCMock does not currently support
// the mocking of methods with variadic parameters: https://github.com/erikdoe/ocmock/issues/191

@end
