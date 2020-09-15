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

#import "GoogleDataTransport/GDTCORTests/Unit/GDTCORTestCase.h"

#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREventTransformer.h"

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORFlatFileStorage.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORTransformer.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORTransformer_Private.h"

#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORApplicationFake.h"
#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORStorageFake.h"

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

@property(nonatomic) GDTCORApplicationFake *fakeApplication;
@property(nonatomic) GDTCORTransformer *transformer;

@end

@implementation GDTCORTransformerTest

- (void)setUp {
  [super setUp];

  self.fakeApplication = [[GDTCORApplicationFake alloc] init];

  self.transformer = [[GDTCORTransformer alloc] initWithApplication:self.fakeApplication];
  dispatch_sync(self.transformer.eventWritingQueue, ^{
    [[GDTCORRegistrar sharedInstance] registerStorage:[[GDTCORStorageFake alloc] init]
                                               target:kGDTCORTargetTest];
  });
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync(self.transformer.eventWritingQueue, ^{
    [[GDTCORRegistrar sharedInstance] reset];
  });
  self.transformer = nil;

  self.fakeApplication.beginTaskHandler = nil;
  self.fakeApplication = nil;
}

/** Tests the default initializer. */
- (void)testInit {
  GDTCORTransformer *transformer = [[GDTCORTransformer alloc] init];
  XCTAssertNotNil(transformer);
  XCTAssertEqualObjects(transformer.application, [GDTCORApplication sharedApplication]);
}

/** Tests the pointer equality of result of the -sharedInstance method. */
- (void)testSharedInstance {
  XCTAssertEqual([GDTCORTransformer sharedInstance], [GDTCORTransformer sharedInstance]);
  XCTAssertEqualObjects([GDTCORTransformer sharedInstance].application,
                        [GDTCORApplication sharedApplication]);
}

/** Tests writing a event without a transformer. */
- (void)testWriteEventWithoutTransformers {
  __auto_type bgTaskExpectations =
      [self expectationsBackgroundTaskBeginAndEndWithName:@"GDTTransformer"];

  GDTCORTransformer *transformer = self.transformer;
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"1" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  XCTAssertNoThrow([transformer transformEvent:event
                              withTransformers:nil
                                    onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                      XCTAssertTrue(wasWritten);
                                    }]);

  [self waitForExpectations:bgTaskExpectations timeout:0.5];
}

/** Tests writing a event with a transformer that nils out the event. */
- (void)testWriteEventWithTransformersThatNilTheEvent {
  __auto_type bgTaskExpectations =
      [self expectationsBackgroundTaskBeginAndEndWithName:@"GDTTransformer"];

  GDTCORTransformer *transformer = self.transformer;
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"2" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] init];
  NSArray<id<GDTCOREventTransformer>> *transformers =
      @[ [[GDTCORTransformerTestNilingTransformer alloc] init] ];
  XCTAssertNoThrow([transformer transformEvent:event
                              withTransformers:transformers
                                    onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                      XCTAssertFalse(wasWritten);
                                    }]);

  [self waitForExpectations:bgTaskExpectations timeout:0.5];
}

/** Tests writing a event with a transformer that creates a new event. */
- (void)testWriteEventWithTransformersThatCreateANewEvent {
  __auto_type bgTaskExpectations =
      [self expectationsBackgroundTaskBeginAndEndWithName:@"GDTTransformer"];

  GDTCORTransformer *transformer = self.transformer;
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

  [self waitForExpectations:bgTaskExpectations timeout:0.5];
}

#pragma mark - Helpers

/** Sets  GDTCORApplicationFake handlers to expect the begin and the end of a background task with
 * the specified name.
 *  @return An array with the task begin and end XCTestExpectation.
 */
- (NSArray<XCTestExpectation *> *)expectationsBackgroundTaskBeginAndEndWithName:
    (NSString *)expectedName {
  XCTestExpectation *beginExpectation = [self expectationWithDescription:@"Background task begin"];
  XCTestExpectation *endExpectation = [self expectationWithDescription:@"Background task end"];

  GDTCORBackgroundIdentifier taskID = arc4random();

  __auto_type __weak weakSelf = self;

  self.fakeApplication.beginTaskHandler =
      ^GDTCORBackgroundIdentifier(NSString *_Nonnull name, dispatch_block_t _Nonnull handler) {
        __unused __auto_type self = weakSelf;
        XCTAssertEqualObjects(expectedName, name);

        [beginExpectation fulfill];
        return taskID;
      };

  self.fakeApplication.endTaskHandler = ^(GDTCORBackgroundIdentifier endTaskID) {
    __unused __auto_type self = weakSelf;
    XCTAssert(endTaskID == taskID);
    [endExpectation fulfill];
  };

  return @[ beginExpectation, endExpectation ];
}

@end
