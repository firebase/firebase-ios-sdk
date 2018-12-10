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

#import <XCTest/XCTest.h>

#import <GoogleDataLogger/GDLLogTransformer.h>

#import "GDLLogEvent.h"
#import "GDLLogWriter.h"

@interface GDLLogWriterTestNilingTransformer : NSObject <GDLLogTransformer>

@end

@implementation GDLLogWriterTestNilingTransformer

- (GDLLogEvent *)transform:(GDLLogEvent *)logEvent {
  return nil;
}

@end

@interface GDLLogWriterTest : XCTestCase

@end

@implementation GDLLogWriterTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDLLogWriter alloc] init]);
}

/** Tests the pointer equality of result of the -sharedInstance method. */
- (void)testSharedInstance {
  XCTAssertEqual([GDLLogWriter sharedInstance], [GDLLogWriter sharedInstance]);
}

- (void)testWriteLogWithoutTransformers {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"1"];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:nil]);
  // TODO(mikehaney24): Assert that storage contains the log.
}

- (void)testWriteLogWithTransformersThatNilTheLog {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2"];
  NSArray<id<GDLLogTransformer>> *transformers =
      @[ [[GDLLogWriterTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
  // TODO(mikehaney24): Assert that storage does not contain the log.
}

@end
