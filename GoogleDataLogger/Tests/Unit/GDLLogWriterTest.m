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

#import <GoogleDataLogger/GDLLogTransformer.h>

#import "GDLLogEvent.h"
#import "GDLLogExtensionTesterClasses.h"
#import "GDLLogStorage.h"
#import "GDLLogWriter.h"
#import "GDLLogWriter_Private.h"

#import "GDLAssertHelper.h"
#import "GDLLogStorageFake.h"

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

@interface GDLLogWriterTest : GDLTestCase

@end

@implementation GDLLogWriterTest

- (void)setUp {
  [super setUp];
  dispatch_sync([GDLLogWriter sharedInstance].logWritingQueue, ^{
    [GDLLogWriter sharedInstance].storageInstance = [[GDLLogStorageFake alloc] init];
  });
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDLLogWriter sharedInstance].logWritingQueue, ^{
    [GDLLogWriter sharedInstance].storageInstance = [GDLLogStorage sharedInstance];
  });
}

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
  log.extension = [[GDLLogExtensionTesterSimple alloc] init];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:nil]);
}

/** Tests writing a log with a transformer that nils out the log. */
- (void)testWriteLogWithTransformersThatNilTheLog {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  log.extension = [[GDLLogExtensionTesterSimple alloc] init];
  NSArray<id<GDLLogTransformer>> *transformers =
      @[ [[GDLLogWriterTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
}

/** Tests writing a log with a transformer that creates a new log. */
- (void)testWriteLogWithTransformersThatCreateANewLog {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  log.extension = [[GDLLogExtensionTesterSimple alloc] init];
  NSArray<id<GDLLogTransformer>> *transformers =
      @[ [[GDLLogWriterTestNewLogTransformer alloc] init] ];
  XCTAssertNoThrow([writer writeLog:log afterApplyingTransformers:transformers]);
}

/** Tests that using a transformer without transform: implemented throws. */
- (void)testWriteLogWithBadTransformer {
  GDLLogWriter *writer = [GDLLogWriter sharedInstance];
  GDLLogEvent *log = [[GDLLogEvent alloc] initWithLogMapID:@"2" logTarget:1];
  log.extension = [[GDLLogExtensionTesterSimple alloc] init];
  NSArray *transformers = @[ [[NSObject alloc] init] ];

  XCTestExpectation *errorExpectation = [self expectationWithDescription:@"transform: is missing"];
  [GDLAssertHelper setAssertionBlock:^{
    [errorExpectation fulfill];
  }];
  [writer writeLog:log afterApplyingTransformers:transformers];
  [self waitForExpectations:@[ errorExpectation ] timeout:5.0];
}

@end
