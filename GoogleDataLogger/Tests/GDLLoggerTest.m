/*
 * Copyright 2018 Google
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

#import "GDLTestCase.h"

#import <GoogleDataLogger/GDLLogEvent.h>
#import <GoogleDataLogger/GDLLogger.h>

#import "GDLLogger_Private.h"

#import "GDLLogExtensionTesterClasses.h"
#import "GDLLogWriterFake.h"

@interface GDLLoggerTest : GDLTestCase

@end

@implementation GDLLoggerTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDLLogger alloc] initWithLogMapID:@"1" logTransformers:nil logTarget:1]);
  XCTAssertThrows([[GDLLogger alloc] initWithLogMapID:@"" logTransformers:nil logTarget:1]);
}

/** Tests logging a telemetry event. */
- (void)testLogTelemetryEvent {
  GDLLogger *logger = [[GDLLogger alloc] initWithLogMapID:@"1" logTransformers:nil logTarget:1];
  logger.logWriterInstance = [[GDLLogWriterFake alloc] init];
  GDLLogEvent *event = [logger newEvent];
  event.extension = [[GDLLogExtensionTesterSimple alloc] init];
  XCTAssertNoThrow([logger logTelemetryEvent:event]);
}

/** Tests logging a data event. */
- (void)testLogDataEvent {
  GDLLogger *logger = [[GDLLogger alloc] initWithLogMapID:@"1" logTransformers:nil logTarget:1];
  logger.logWriterInstance = [[GDLLogWriterFake alloc] init];
  GDLLogEvent *event = [logger newEvent];
  event.extension = [[GDLLogExtensionTesterSimple alloc] init];
  XCTAssertNoThrow([logger logDataEvent:event]);
}

@end
