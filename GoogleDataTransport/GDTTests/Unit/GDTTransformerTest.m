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

#import "GDTTests/Unit/GDTTestCase.h"

#import <GoogleDataTransport/GDTEvent.h>
#import <GoogleDataTransport/GDTEventTransformer.h>

#import "GDTLibrary/Private/GDTStorage.h"
#import "GDTLibrary/Private/GDTTransformer.h"
#import "GDTLibrary/Private/GDTTransformer_Private.h"

#import "GDTTests/Unit/Helpers/GDTAssertHelper.h"
#import "GDTTests/Unit/Helpers/GDTDataObjectTesterClasses.h"

#import "GDTTests/Common/Fakes/GDTStorageFake.h"

@interface GDTTransformerTestNilingTransformer : NSObject <GDTEventTransformer>

@end

@implementation GDTTransformerTestNilingTransformer

- (GDTEvent *)transform:(GDTEvent *)eventEvent {
  return nil;
}

@end

@interface GDTTransformerTestNewEventTransformer : NSObject <GDTEventTransformer>

@end

@implementation GDTTransformerTestNewEventTransformer

- (GDTEvent *)transform:(GDTEvent *)eventEvent {
  return [[GDTEvent alloc] initWithMappingID:@"new" target:1];
}

@end

@interface GDTTransformerTest : GDTTestCase

@end

@implementation GDTTransformerTest

- (void)setUp {
  [super setUp];
  dispatch_sync([GDTTransformer sharedInstance].eventWritingQueue, ^{
    [GDTTransformer sharedInstance].storageInstance = [[GDTStorageFake alloc] init];
  });
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTTransformer sharedInstance].eventWritingQueue, ^{
    [GDTTransformer sharedInstance].storageInstance = [GDTStorage sharedInstance];
  });
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTTransformer alloc] init]);
}

/** Tests the pointer equality of result of the -sharedInstance method. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTTransformer sharedInstance], [GDTTransformer sharedInstance]);
}

/** Tests writing a event without a transformer. */
- (void)testWriteEventWithoutTransformers {
  GDTTransformer *transformer = [GDTTransformer sharedInstance];
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"1" target:1];
  event.dataObject = [[GDTDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transformer transformEvent:event withTransformers:nil]);
}

/** Tests writing a event with a transformer that nils out the event. */
- (void)testWriteEventWithTransformersThatNilTheEvent {
  GDTTransformer *transformer = [GDTTransformer sharedInstance];
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"2" target:1];
  event.dataObject = [[GDTDataObjectTesterSimple alloc] init];
  NSArray<id<GDTEventTransformer>> *transformers =
      @[ [[GDTTransformerTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event withTransformers:transformers]);
}

/** Tests writing a event with a transformer that creates a new event. */
- (void)testWriteEventWithTransformersThatCreateANewEvent {
  GDTTransformer *transformer = [GDTTransformer sharedInstance];
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"2" target:1];
  event.dataObject = [[GDTDataObjectTesterSimple alloc] init];
  NSArray<id<GDTEventTransformer>> *transformers =
      @[ [[GDTTransformerTestNewEventTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event withTransformers:transformers]);
}

/** Tests that using a transformer without transform: implemented throws. */
- (void)testWriteEventWithBadTransformer {
  GDTTransformer *transformer = [GDTTransformer sharedInstance];
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"2" target:1];
  event.dataObject = [[GDTDataObjectTesterSimple alloc] init];
  NSArray *transformers = @[ [[NSObject alloc] init] ];

  XCTestExpectation *errorExpectation = [self expectationWithDescription:@"transform: is missing"];
  [GDTAssertHelper setAssertionBlock:^{
    [errorExpectation fulfill];
  }];
  [transformer transformEvent:event withTransformers:transformers];
  [self waitForExpectations:@[ errorExpectation ] timeout:5.0];
}

@end
