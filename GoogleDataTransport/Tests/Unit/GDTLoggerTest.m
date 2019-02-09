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

#import "GDTTestCase.h"

#import <GoogleDataTransport/GDTLogEvent.h>
#import <GoogleDataTransport/GDTLogger.h>

#import "GDTLogger_Private.h"

#import "GDTLogExtensionTesterClasses.h"
#import "GDTLogWriterFake.h"

@interface GDTLoggerTest : GDTTestCase

@end

@implementation GDTLoggerTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTLogger alloc] initWithLogMapID:@"1" logTransformers:nil logTarget:1]);
  XCTAssertThrows([[GDTLogger alloc] initWithLogMapID:@"" logTransformers:nil logTarget:1]);
}

/** Tests logging a telemetry event. */
- (void)testLogTelemetryEvent {
  GDTLogger *logger = [[GDTLogger alloc] initWithLogMapID:@"1" logTransformers:nil logTarget:1];
  logger.logWriterInstance = [[GDTLogWriterFake alloc] init];
  GDTLogEvent *event = [logger newEvent];
  event.extension = [[GDTLogExtensionTesterSimple alloc] init];
  XCTAssertNoThrow([logger logTelemetryEvent:event]);
}

/** Tests logging a data event. */
- (void)testLogDataEvent {
  GDTLogger *logger = [[GDTLogger alloc] initWithLogMapID:@"1" logTransformers:nil logTarget:1];
  logger.logWriterInstance = [[GDTLogWriterFake alloc] init];
  GDTLogEvent *event = [logger newEvent];
  event.extension = [[GDTLogExtensionTesterSimple alloc] init];
  XCTAssertNoThrow([logger logDataEvent:event]);
}

@end
