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
#import "GDLLogWriter_Private.h"

@interface GDLLogWriterTestNilingTransformer : NSObject <GDLLogTransformer>

@end

@implementation GDLLogWriterTestNilingTransformer

- (GDLLogEvent *)transform:(GDLLogEvent *)logEvent {
  return nil;
}

@end

@interface GDLLogWriterTestNewLogTransformer : NSObject <GDLLogTransformer>

@end

@implementation GDLLogWriterTestNewLogTransformer

- (GDLLogEvent *)transform:(GDLLogEvent *)logEvent {
  return [[GDLLogEvent alloc] initWithLogMapID:@"new" logTarget:1];
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

/** Tests writing a log without a transformer. */
- (void)testWriteLogWithoutTransformers {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"1" logTarget:1];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:nil]);
  dispatch_sync(writer.logWritingQueue, ^{
                    // TODO(mikehaney24): Assert that storage contains the log.
                });
}

/** Tests writing a log with a transformer that nils out the log. */
- (void)testWriteLogWithTransformersThatNilTheLog {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  NSArray<id<GDLLogTransformer>> *transformers =
      @[ [[GDLLogWriterTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
  dispatch_sync(writer.logWritingQueue, ^{
                    // TODO(mikehaney24): Assert that storage does not contain the log.
                });
}

/** Tests writing a log with a transformer that creates a new log. */
- (void)testWriteLogWithTransformersThatCreateANewLog {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  NSArray<id<GDLLogTransformer>> *transformers =
      @[ [[GDLLogWriterTestNewLogTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
  dispatch_sync(writer.logWritingQueue, ^{
                    // TODO(mikehaney24): Assert that storage contains the new log.
                });
}

/** Tests that using a transformer without transform: implemented throws. */
- (void)testWriteLogWithBadTransformer {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  NSArray *transformers = @[ [[NSObject alloc] init] ];
  @try {
    dispatch_sync(writer.logWritingQueue, ^{
      // TODO(mikehaney24): Assert that storage contains the new log.
      [writer writeLog:log afterApplyingTransformers:transformers];
    });
  } @catch (NSException *exception) {
    NSLog(@"");
  }
}

@end
