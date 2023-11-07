/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import <AppCheckCore/AppCheckCore.h>

@interface FIRAppCheckLoggerTests : XCTestCase
@end

@implementation FIRAppCheckLoggerTests

- (void)testGetGACAppCheckLogLevel_Error {
  FIRSetLoggerLevel(FIRLoggerLevelError);

  GACAppCheckLogLevel logLevel = FIRGetGACAppCheckLogLevel();

  XCTAssertEqual(logLevel, GACAppCheckLogLevelError);
}

- (void)testGetGACAppCheckLogLevel_Warning {
  FIRSetLoggerLevel(FIRLoggerLevelWarning);

  GACAppCheckLogLevel logLevel = FIRGetGACAppCheckLogLevel();

  XCTAssertEqual(logLevel, GACAppCheckLogLevelWarning);
}

- (void)testGetGACAppCheckLogLevel_Notice {
  FIRSetLoggerLevel(FIRLoggerLevelNotice);

  GACAppCheckLogLevel logLevel = FIRGetGACAppCheckLogLevel();

  XCTAssertEqual(logLevel, GACAppCheckLogLevelWarning);
}

- (void)testGetGACAppCheckLogLevel_Info {
  FIRSetLoggerLevel(FIRLoggerLevelInfo);

  GACAppCheckLogLevel logLevel = FIRGetGACAppCheckLogLevel();

  XCTAssertEqual(logLevel, GACAppCheckLogLevelInfo);
}

- (void)testGetGACAppCheckLogLevel_Debug {
  FIRSetLoggerLevel(FIRLoggerLevelDebug);

  GACAppCheckLogLevel logLevel = FIRGetGACAppCheckLogLevel();

  XCTAssertEqual(logLevel, GACAppCheckLogLevelDebug);
}

@end
