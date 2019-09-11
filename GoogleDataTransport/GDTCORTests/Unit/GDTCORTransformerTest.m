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

#import "GDTCORTests/Unit/GDTCORTestCase.h"

#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCOREventTransformer.h>

#import "GDTCORLibrary/Private/GDTCORStorage.h"
#import "GDTCORLibrary/Private/GDTCORTransformer.h"
#import "GDTCORLibrary/Private/GDTCORTransformer_Private.h"

#import "GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

#import "GDTCORTests/Common/Fakes/GDTCORStorageFake.h"

@interface GDTCORTransformerTestNilingTransformer : NSObject <GDTCOREventTransformer>

@end

@implementation GDTCORTransformerTestNilingTransformer

- (GDTCOREvent *)transform:(GDTCOREvent *)eventEvent {
  return nil;
}

@end

@interface GDTCORTransformerTestNewEventTransformer : NSObject <GDTCOREventTransformer>

@end

@implementation GDTCORTransformerTestNewEventTransformer

- (GDTCOREvent *)transform:(GDTCOREvent *)eventEvent {
  return [[GDTCOREvent alloc] initWithMappingID:@"new" target:1];
}

@end

@interface GDTCORTransformerTest : GDTCORTestCase

@end

@implementation GDTCORTransformerTest

- (void)setUp {
  [super setUp];
  dispatch_sync([GDTCORTransformer sharedInstance].eventWritingQueue, ^{
    [GDTCORTransformer sharedInstance].storageInstance = [[GDTCORStorageFake alloc] init];
  });
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTCORTransformer sharedInstance].eventWritingQueue, ^{
    [GDTCORTransformer sharedInstance].storageInstance = [GDTCORStorage sharedInstance];
  });
}

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTCORTransformer alloc] init]);
}

/** Tests the pointer equality of result of the -sharedInstance method. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTCORTransformer sharedInstance], [GDTCORTransformer sharedInstance]);
}

/** Tests writing a event without a transformer. */
- (void)testWriteEventWithoutTransformers {
  GDTCORTransformer *transformer = [GDTCORTransformer sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1" target:1];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transformer transformEvent:event withTransformers:nil]);
}

/** Tests writing a event with a transformer that nils out the event. */
- (void)testWriteEventWithTransformersThatNilTheEvent {
  GDTCORTransformer *transformer = [GDTCORTransformer sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"2" target:1];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  NSArray<id<GDTCOREventTransformer>> *transformers =
      @[ [[GDTCORTransformerTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event withTransformers:transformers]);
}

/** Tests writing a event with a transformer that creates a new event. */
- (void)testWriteEventWithTransformersThatCreateANewEvent {
  GDTCORTransformer *transformer = [GDTCORTransformer sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"2" target:1];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  NSArray<id<GDTCOREventTransformer>> *transformers =
      @[ [[GDTCORTransformerTestNewEventTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event withTransformers:transformers]);
}

@end
