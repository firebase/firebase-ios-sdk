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

#import <GoogleDataTransport/GDTLogTransformer.h>

#import "GDTLogEvent.h"
#import "GDTLogExtensionTesterClasses.h"
#import "GDTLogStorage.h"
#import "GDTLogWriter.h"
#import "GDTLogWriter_Private.h"

#import "GDTAssertHelper.h"
#import "GDTLogStorageFake.h"

@interface GDTLogWriterTestNilingTransformer : NSObject <GDTLogTransformer>

@end

@implementation GDTLogWriterTestNilingTransformer

- (GDTLogEvent *)transform:(GDTLogEvent *)logEvent {
  return nil;
}

@end

@interface GDTLogWriterTestNewLogTransformer : NSObject <GDTLogTransformer>

@end

@implementation GDTLogWriterTestNewLogTransformer

- (GDTLogEvent *)transform:(GDTLogEvent *)logEvent {
  return [[GDTLogEvent alloc] initWithLogMapID:@"new" logTarget:1];
}

@end

@interface GDTLogWriterTest : GDTTestCase

@end

@implementation GDTLogWriterTest

- (void)setUp {
  [super setUp];
  dispatch_sync([GDTLogWriter sharedInstance].logWritingQueue, ^{
    [GDTLogWriter sharedInstance].storageInstance = [[GDTLogStorageFake alloc] init];
  });
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTLogWriter sharedInstance].logWritingQueue, ^{
    [GDTLogWriter sharedInstance].storageInstance = [GDTLogStorage sharedInstance];
  });
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTLogWriter alloc] init]);
}

/** Tests the pointer equality of result of the -sharedInstance method. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTLogWriter sharedInstance], [GDTLogWriter sharedInstance]);
}

/** Tests writing a log without a transformer. */
- (void)testWriteLogWithoutTransformers {
  GDTLogWriter *writer = [GDTLogWriter sharedInstance];
  GDTLogEvent *log = [[GDTLogEvent alloc] initWithLogMapID:@"1" logTarget:1];
  log.extension = [[GDTLogExtensionTesterSimple alloc] init];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:nil]);
}

/** Tests writing a log with a transformer that nils out the log. */
- (void)testWriteLogWithTransformersThatNilTheLog {
  GDTLogWriter *writer = [GDTLogWriter sharedInstance];
  GDTLogEvent *log = [[GDTLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  log.extension = [[GDTLogExtensionTesterSimple alloc] init];
  NSArray<id<GDTLogTransformer>> *transformers =
      @[ [[GDTLogWriterTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
}

/** Tests writing a log with a transformer that creates a new log. */
- (void)testWriteLogWithTransformersThatCreateANewLog {
  GDTLogWriter *writer = [GDTLogWriter sharedInstance];
  GDTLogEvent *log = [[GDTLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  log.extension = [[GDTLogExtensionTesterSimple alloc] init];
  NSArray<id<GDTLogTransformer>> *transformers =
      @[ [[GDTLogWriterTestNewLogTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
}

/** Tests that using a transformer without transform: implemented throws. */
- (void)testWriteLogWithBadTransformer {
  GDTLogWriter *writer = [GDTLogWriter sharedInstance];
  GDTLogEvent *log = [[GDTLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  log.extension = [[GDTLogExtensionTesterSimple alloc] init];
  NSArray *transformers = @[ [[NSObject alloc] init] ];

  XCTestExpectation *errorExpectation = [self expectationWithDescription:@"transform: is missing"];
  [GDTAssertHelper setAssertionBlock:^{
    [errorExpectation fulfill];
  }];
  [writer writeLog:log afterApplyingTransformers:transformers];
  [self waitForExpectations:@[ errorExpectation ] timeout:5.0];
}

@end
