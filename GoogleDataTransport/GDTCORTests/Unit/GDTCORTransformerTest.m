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

#import "GDTCORLibrary/Private/GDTCORFlatFileStorage.h"
#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GDTCORLibrary/Private/GDTCORTransformer.h"
#import "GDTCORLibrary/Private/GDTCORTransformer_Private.h"

#import "GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

#import "GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

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
  return [[GDTCOREvent alloc] initWithMappingID:@"new" target:kGDTCORTargetTest];
}

@end

@interface GDTCORTransformerTest : GDTCORTestCase

@end

@implementation GDTCORTransformerTest

- (void)setUp {
  [super setUp];
  dispatch_sync([GDTCORTransformer sharedInstance].eventWritingQueue, ^{
    [[GDTCORRegistrar sharedInstance] registerStorage:[[GDTCORStorageFake alloc] init]
                                               target:kGDTCORTargetTest];
  });
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTCORTransformer sharedInstance].eventWritingQueue, ^{
    [[GDTCORRegistrar sharedInstance] reset];
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
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transformer transformEvent:event
                              withTransformers:nil
                                    onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                      XCTAssertTrue(wasWritten);
                                    }]);
}

/** Tests writing a event with a transformer that nils out the event. */
- (void)testWriteEventWithTransformersThatNilTheEvent {
  GDTCORTransformer *transformer = [GDTCORTransformer sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"2" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  NSArray<id<GDTCOREventTransformer>> *transformers =
      @[ [[GDTCORTransformerTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event
                              withTransformers:transformers
                                    onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                      XCTAssertFalse(wasWritten);
                                    }]);
}

/** Tests writing a event with a transformer that creates a new event. */
- (void)testWriteEventWithTransformersThatCreateANewEvent {
  GDTCORTransformer *transformer = [GDTCORTransformer sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"2" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  NSArray<id<GDTCOREventTransformer>> *transformers =
      @[ [[GDTCORTransformerTestNewEventTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event
                              withTransformers:transformers
                                    onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                      XCTAssertTrue(wasWritten);
                                      XCTAssertNil(error);
                                    }]);
}

@end
