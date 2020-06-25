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

#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORFlatFileStorage.h"
#import "GoogleDataTransport/GDTCORLibrary/Private/GDTCORRegistrar_Private.h"

#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCOREvent.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GDTCORRegistrar.h"

#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCOREventGenerator.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORUploadCoordinatorFake.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

/** A category that adds finding a random element to NSSet. NSSet's -anyObject isn't random. */
@interface NSSet (GDTCORRandomElement)

/** Returns a random element of the set.
 *
 * @return A random element of the set.
 */
- (id)randomElement;

@end

@implementation NSSet (GDTCORRandomElement)

- (id)randomElement {
  if (self.count) {
    NSArray *elements = [self allObjects];
    return elements[arc4random_uniform((uint32_t)self.count)];
  }
  return nil;
}

@end

@interface GDTCORFlatFileStorageTest : GDTCORTestCase

/** The test backend implementation. */
@property(nullable, nonatomic) GDTCORTestUploader *testBackend;

/** The uploader fake. */
@property(nonatomic) GDTCORUploadCoordinatorFake *uploaderFake;

@end

@implementation GDTCORFlatFileStorageTest

- (void)setUp {
  [super setUp];
  self.testBackend = [[GDTCORTestUploader alloc] init];
  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORFlatFileStorage sharedInstance] reset];
  [[GDTCORRegistrar sharedInstance] registerUploader:_testBackend target:kGDTCORTargetTest];
  [[GDTCORRegistrar sharedInstance] registerUploader:_testBackend target:kGDTCORTargetFLL];
  self.uploaderFake = [[GDTCORUploadCoordinatorFake alloc] init];
  [GDTCORFlatFileStorage sharedInstance].uploadCoordinator = self.uploaderFake;
  [[GDTCORFlatFileStorage sharedInstance] reset];
  [[NSFileManager defaultManager] fileExistsAtPath:[GDTCORFlatFileStorage eventDataStoragePath]];
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
                });
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  [GDTCORFlatFileStorage sharedInstance].uploadCoordinator =
      [GDTCORUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Generates and returns a set of events that are generated randomly and stored.
 *
 * @return A set of randomly generated and stored events.
 */
- (NSSet<GDTCOREvent *> *)generateEventsForStorageTesting {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSMutableSet<GDTCOREvent *> *generatedEvents = [[NSMutableSet alloc] init];
  // Generate 100 test target events
  for (int i = 0; i < 100; i++) {
    GDTCOREvent *event = [GDTCOREventGenerator generateEventForTarget:kGDTCORTargetTest
                                                              qosTier:nil
                                                            mappingID:nil];
    [generatedEvents addObject:event];
    [storage storeEvent:event onComplete:nil];
  }

  // Generate 50 FLL target events.
  for (int i = 0; i < 50; i++) {
    GDTCOREvent *event = [GDTCOREventGenerator generateEventForTarget:kGDTCORTargetFLL
                                                              qosTier:nil
                                                            mappingID:nil];
    [generatedEvents addObject:event];
    [storage storeEvent:event onComplete:nil];
  }
  return generatedEvents;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDTCORFlatFileStorage sharedInstance], [GDTCORFlatFileStorage sharedInstance]);
}

/** Tests storing an event. */
- (void)testStoreEvent {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvents completion called"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertFalse(hasEvents);
                     [expectation fulfill];
                   }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([storage storeEvent:event
                            onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                              XCTAssertTrue(wasWritten);
                              XCTAssertNotEqualObjects(event.eventID, @0);
                              XCTAssertNil(error);
                              [writtenExpectation fulfill];
                            }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  expectation = [self expectationWithDescription:@"hasEvents completion called"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertTrue(hasEvents);
                     [expectation fulfill];
                   }];
  [self waitForExpectations:@[ expectation ] timeout:10];

  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
  expectation = [self expectationWithDescription:@"batch fetched"];
  [storage batchWithEventSelector:eventSelector
                  batchExpiration:[NSDate dateWithTimeIntervalSinceNow:60]
                       onComplete:^(NSNumber *_Nullable batchID,
                                    NSSet<GDTCOREvent *> *_Nullable events) {
                         XCTAssertEqual(events.count, 1);
                         XCTAssertEqualObjects(event.eventID, [events anyObject].eventID);
                         [expectation fulfill];
                       }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests storing an event whose mappingID contains path components. */
- (void)testStoreEventWithPathComponentsInMappingID {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"this/messes/up/things"
                                                       target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvents completion called"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertFalse(hasEvents);
                     [expectation fulfill];
                   }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([storage storeEvent:event
                            onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                              XCTAssertTrue(wasWritten);
                              XCTAssertNotEqualObjects(event.eventID, @0);
                              XCTAssertNil(error);
                              [writtenExpectation fulfill];
                            }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  expectation = [self expectationWithDescription:@"hasEvents completion called"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertTrue(hasEvents);
                     [expectation fulfill];
                   }];
  [self waitForExpectations:@[ expectation ] timeout:10];

  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
  expectation = [self expectationWithDescription:@"batch fetched"];
  [storage batchWithEventSelector:eventSelector
                  batchExpiration:[NSDate dateWithTimeIntervalSinceNow:60]
                       onComplete:^(NSNumber *_Nullable batchID,
                                    NSSet<GDTCOREvent *> *_Nullable events) {
                         XCTAssertEqual(events.count, 1);
                         XCTAssertEqualObjects(event.eventID, [events anyObject].eventID);
                         [expectation fulfill];
                       }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests storing a few different events. */
- (void)testStoreMultipleEvents {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  GDTCOREvent *event1 = [[GDTCOREvent alloc] initWithMappingID:@"404" target:kGDTCORTargetTest];
  event1.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString1"];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([storage storeEvent:event1
                            onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                              XCTAssertNotEqualObjects(event1.eventID, @0);
                              XCTAssertNil(error);
                              [writtenExpectation fulfill];
                            }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  GDTCOREvent *event2 = [[GDTCOREvent alloc] initWithMappingID:@"100" target:kGDTCORTargetTest];
  event2.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString2"];
  writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([storage storeEvent:event2
                            onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                              XCTAssertNotEqualObjects(event2.eventID, @0);
                              XCTAssertNil(error);
                              [writtenExpectation fulfill];
                            }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  GDTCOREvent *event3 = [[GDTCOREvent alloc] initWithMappingID:@"404" target:kGDTCORTargetTest];
  event3.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString3"];
  writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([storage storeEvent:event3
                            onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                              XCTAssertNotEqualObjects(event3.eventID, @0);
                              XCTAssertNil(error);
                              [writtenExpectation fulfill];
                            }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  XCTestExpectation *expectation = [self expectationWithDescription:@"batch created"];
  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
  [storage batchWithEventSelector:eventSelector
                  batchExpiration:[NSDate dateWithTimeIntervalSinceNow:60]
                       onComplete:^(NSNumber *_Nullable batchID,
                                    NSSet<GDTCOREvent *> *_Nullable events) {
                         XCTAssertEqual(events.count, 3);
                         [expectation fulfill];
                       }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests sending a fast priority event causes an upload attempt. */
- (void)testQoSTierFast {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.qosTier = GDTCOREventQoSFast;
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTAssertFalse(self.uploaderFake.forceUploadCalled);
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([storage storeEvent:event
                            onComplete:^(BOOL wasWritten, NSError *error) {
                              XCTAssertNotEqualObjects(event.eventID, @0);
                              XCTAssertNil(error);
                              [writtenExpectation fulfill];
                            }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  dispatch_sync(storage.storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
  });
}

/** Fuzz tests the storing of events at the same time as a terminate lifecycle notification. This
 * test can fail if there's simultaneous access to ivars of GDTCORFlatFileStorage with one access
 * being off the storage's queue. The terminate lifecycle event should operate on and flush the
 * queue.
 */
- (void)testStoringEventsDuringTerminate {
  BOOL originalValueOfContinueAfterFailure = self.continueAfterFailure;
  self.continueAfterFailure = NO;
  int numberOfIterations = 1000;
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  for (int i = 0; i < numberOfIterations; i++) {
    NSString *testString = [NSString stringWithFormat:@"testString %d", i];
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:kGDTCORTargetTest];
    event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:testString];
    event.clockSnapshot = [GDTCORClock snapshot];
    XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
    XCTAssertNoThrow([storage storeEvent:event
                              onComplete:^(BOOL wasWritten, NSError *error) {
                                XCTAssertNotEqualObjects(event.eventID, @0);
                                [writtenExpectation fulfill];
                              }]);
    [self waitForExpectationsWithTimeout:10 handler:nil];
    if (i % 5 == 0) {
      GDTCORStorageEventSelector *eventSelector =
          [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
      [storage batchWithEventSelector:eventSelector
                      batchExpiration:[NSDate dateWithTimeIntervalSinceNow:60]
                           onComplete:^(NSNumber *_Nullable batchID,
                                        NSSet<GDTCOREvent *> *_Nullable events) {
                             [storage removeBatchWithID:batchID deleteEvents:YES onComplete:nil];
                           }];
    }
    [NSNotificationCenter.defaultCenter
        postNotificationName:kGDTCORApplicationWillTerminateNotification
                      object:nil];
  }
  self.continueAfterFailure = originalValueOfContinueAfterFailure;
}

- (void)testSaveAndLoadLibraryData {
  __weak NSData *weakData;
  NSString *dataKey = NSStringFromSelector(_cmd);
  @autoreleasepool {
    NSData *data = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    weakData = data;
    XCTestExpectation *expectation = [self expectationWithDescription:@"storage completion called"];
    [[GDTCORFlatFileStorage sharedInstance] storeLibraryData:data
                                                      forKey:dataKey
                                                  onComplete:^(NSError *_Nullable error) {
                                                    XCTAssertNil(error);
                                                    [expectation fulfill];
                                                  }];
    [self waitForExpectations:@[ expectation ] timeout:10.0];
  }
  XCTAssertNil(weakData);
  XCTestExpectation *expectation = [self expectationWithDescription:@"retrieval completion called"];
  [[GDTCORFlatFileStorage sharedInstance]
      libraryDataForKey:dataKey
        onFetchComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
          [expectation fulfill];
          XCTAssertNil(error);
          XCTAssertEqualObjects(@"test data", [[NSString alloc] initWithData:data
                                                                    encoding:NSUTF8StringEncoding]);
        }
            setNewValue:nil];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
}

- (void)testSavingNilLibraryData {
  XCTestExpectation *expectation = [self expectationWithDescription:@"storage completion called"];
  [[GDTCORFlatFileStorage sharedInstance] storeLibraryData:[NSData data]
                                                    forKey:@"test data key"
                                                onComplete:^(NSError *_Nullable error) {
                                                  XCTAssertNotNil(error);
                                                  [expectation fulfill];
                                                }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
}

- (void)testSaveAndRemoveLibraryData {
  NSString *dataKey = NSStringFromSelector(_cmd);
  NSData *data = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
  XCTestExpectation *expectation = [self expectationWithDescription:@"storage completion called"];
  [[GDTCORFlatFileStorage sharedInstance] storeLibraryData:data
                                                    forKey:dataKey
                                                onComplete:^(NSError *_Nullable error) {
                                                  XCTAssertNil(error);
                                                  [expectation fulfill];
                                                }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
  expectation = [self expectationWithDescription:@"retrieval completion called"];
  [[GDTCORFlatFileStorage sharedInstance] libraryDataForKey:dataKey
      onFetchComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(@"test data", [[NSString alloc] initWithData:data
                                                                  encoding:NSUTF8StringEncoding]);
        [expectation fulfill];
      }
      setNewValue:^NSData *_Nullable {
        return nil;
      }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
  expectation = [self expectationWithDescription:@"removal completion called"];
  [[GDTCORFlatFileStorage sharedInstance] removeLibraryDataForKey:dataKey
                                                       onComplete:^(NSError *error) {
                                                         [expectation fulfill];
                                                         XCTAssertNil(error);
                                                       }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
  expectation = [self expectationWithDescription:@"retrieval completion called"];
  [[GDTCORFlatFileStorage sharedInstance]
      libraryDataForKey:dataKey
        onFetchComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
          XCTAssertNotNil(error);
          XCTAssertNil(data);
          [expectation fulfill];
        }
            setNewValue:nil];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by target. */
- (void)testSearchingPathsByTarget {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  NSSet<GDTCOREvent *> *expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return event.target == kGDTCORTargetTest;
      }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:kGDTCORTargetTest
                 eventIDs:nil
                 qosTiers:nil
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by eventID. */
- (void)testSearchingPathWithEventID {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  GDTCOREvent *anyEvent = [generatedEvents randomElement];
  NSSet<GDTCOREvent *> *expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return anyEvent.target == event.target && [event.eventID isEqualToString:anyEvent.eventID];
      }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:anyEvent.target
                 eventIDs:[NSSet setWithObject:anyEvent.eventID]
                 qosTiers:nil
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];

  GDTCOREvent *anotherEvent;
  do {
    anotherEvent = [generatedEvents randomElement];
  } while (anotherEvent == anyEvent || anotherEvent.target != anyEvent.target);

  expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return (anyEvent.target == event.target &&
                [event.eventID isEqualToString:anyEvent.eventID]) ||
               (anotherEvent.target == event.target &&
                [event.eventID isEqualToString:anotherEvent.eventID]);
      }]];

  expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:anyEvent.target
                 eventIDs:[NSSet setWithObjects:anyEvent.eventID, anotherEvent.eventID, nil]
                 qosTiers:nil
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by qosTier. */
- (void)testSearchingPathWithQoSTier {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  GDTCOREvent *anyEvent = [generatedEvents randomElement];
  NSSet<GDTCOREvent *> *expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return event.target == anyEvent.target && event.qosTier == anyEvent.qosTier;
      }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:anyEvent.target
                 eventIDs:nil
                 qosTiers:[NSSet setWithObject:@(anyEvent.qosTier)]
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by mappingID. */
- (void)testSearchingPathWithMappingID {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  GDTCOREvent *anyEvent = [generatedEvents randomElement];
  NSSet<GDTCOREvent *> *expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return event.target == anyEvent.target &&
               [event.mappingID isEqualToString:anyEvent.mappingID];
      }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:anyEvent.target
                 eventIDs:nil
                 qosTiers:nil
               mappingIDs:[NSSet setWithObject:anyEvent.mappingID]
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by mappingID that contains path components. */
- (void)testSearchingPathWithMappingIDThatHasPathComponents {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"this/messes/up/things"
                                                       target:kGDTCORTargetTest];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.clockSnapshot = [GDTCORClock snapshot];
  [storage storeEvent:event onComplete:nil];
  NSSet<GDTCOREvent *> *expectedEvents = [NSSet setWithObject:event];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:event.target
                 eventIDs:nil
                 qosTiers:nil
               mappingIDs:[NSSet setWithObject:event.mappingID]
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by eventID and qosTier. */
- (void)testSearchingPathWithEventIDAndQoSTier {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  GDTCOREvent *anyEvent = [generatedEvents randomElement];
  NSSet<GDTCOREvent *> *expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return event.target == anyEvent.target &&
               [event.eventID isEqualToString:anyEvent.eventID] &&
               event.qosTier == anyEvent.qosTier;
      }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:anyEvent.target
                 eventIDs:[NSSet setWithObject:anyEvent.eventID]
                 qosTiers:[NSSet setWithObject:@(anyEvent.qosTier)]
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by eventID and qosTier without results. */
- (void)testSearchingPathWithEventIDAndQoSTierNoResults {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  XCTAssertGreaterThan(generatedEvents.count, 0);
  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:kGDTCORTargetFLL
                 eventIDs:[NSSet setWithObject:@"made up"]
                 qosTiers:nil
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, 0);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests -pathForTarget:qosTier:mappingID: searching by qosTier and mappingID. */
- (void)testSearchingPathWithQoSTierAndMappingID {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  GDTCOREvent *anyEvent = [generatedEvents randomElement];
  NSSet<GDTCOREvent *> *expectedEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return event.target == anyEvent.target && event.qosTier == anyEvent.qosTier &&
               [event.mappingID isEqualToString:anyEvent.mappingID];
      }]];

  XCTestExpectation *expectation = [self expectationWithDescription:@"paths found"];
  [storage pathsForTarget:anyEvent.target
                 eventIDs:nil
                 qosTiers:[NSSet setWithObject:@(anyEvent.qosTier)]
               mappingIDs:[NSSet setWithObject:anyEvent.mappingID]
               onComplete:^(NSSet<NSString *> *paths) {
                 XCTAssertEqual(paths.count, expectedEvents.count);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
}

/** Tests hasEventsForTarget: returns YES when events are stored and NO otherwise. */
- (void)testHasEventsForTarget {
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertFalse(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];

  GDTCOREvent *event = [GDTCOREventGenerator generateEventForTarget:kGDTCORTargetTest
                                                            qosTier:nil
                                                          mappingID:nil];
  [[GDTCORFlatFileStorage sharedInstance] storeEvent:event onComplete:nil];
  expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertTrue(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests that the size of the storage is returned accurately. */
- (void)testStorageSizeWithCallback {
  NSUInteger ongoingSize = 0;
  XCTestExpectation *expectation = [self expectationWithDescription:@"storageSize complete"];
  [[GDTCORFlatFileStorage sharedInstance] storageSizeWithCallback:^(uint64_t storageSize) {
    XCTAssertEqual(storageSize, 0);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];

  expectation = [self expectationWithDescription:@"storageSize complete"];
  NSData *data = [@"this is a test" dataUsingEncoding:NSUTF8StringEncoding];
  ongoingSize += data.length;
  [[GDTCORFlatFileStorage sharedInstance] storeLibraryData:data forKey:@"testKey" onComplete:nil];
  [[GDTCORFlatFileStorage sharedInstance] storageSizeWithCallback:^(uint64_t storageSize) {
    XCTAssertEqual(storageSize, ongoingSize);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];

  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  for (GDTCOREvent *event in generatedEvents) {
    NSError *error;
    NSData *serializedEventData = GDTCOREncodeArchive(event, nil, &error);
    XCTAssertNil(error);
    ongoingSize += serializedEventData.length;
  }
  expectation = [self expectationWithDescription:@"storageSize complete"];
  [[GDTCORFlatFileStorage sharedInstance] storageSizeWithCallback:^(uint64_t storageSize) {
    // TODO(mikehaney24): Figure out why storageSize is ~2% higher than ongoingSize.
    XCTAssertGreaterThanOrEqual(storageSize, ongoingSize);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
}

/** Tests generating the next batchID. */
- (void)testNextBatchID {
  BOOL originalContinueAfterFailure = self.continueAfterFailure;
  self.continueAfterFailure = NO;
  NSNumber *expectedBatchID = @0;
  XCTestExpectation *expectation = [self expectationWithDescription:@"nextBatchID completion"];
  [[GDTCORFlatFileStorage sharedInstance] nextBatchID:^(NSNumber *_Nonnull batchID) {
    XCTAssertNotNil(batchID);
    XCTAssertEqualObjects(batchID, expectedBatchID);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];

  expectedBatchID = @1;
  expectation = [self expectationWithDescription:@"nextBatchID completion"];
  [[GDTCORFlatFileStorage sharedInstance] nextBatchID:^(NSNumber *_Nonnull batchID) {
    XCTAssertNotNil(batchID);
    XCTAssertEqualObjects(batchID, expectedBatchID);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];

  for (int i = 0; i < 1000; i++) {
    XCTestExpectation *expectation = [self expectationWithDescription:@"nextBatchID completion"];
    [[GDTCORFlatFileStorage sharedInstance] nextBatchID:^(NSNumber *_Nonnull batchID) {
      NSNumber *expectedBatchID = @(i + 2);  // 2 because of the 2 we generated.
      XCTAssertEqualObjects(batchID, expectedBatchID);
      [expectation fulfill];
    }];
    [self waitForExpectations:@[ expectation ] timeout:10.0];
  }
  self.continueAfterFailure = originalContinueAfterFailure;
}

/** Tests the thread safety of nextBatchID by making a lot of simultaneous calls to it. */
- (void)testNextBatchIDThreadSafety {
  NSUInteger numberOfIterations = 1000;
  NSUInteger expectedBatchID = 2 * numberOfIterations - 1;
  __block NSNumber *batchID;
  NSMutableArray *expectations = [[NSMutableArray alloc] init];
  for (NSUInteger i = 0; i < numberOfIterations; i++) {
    XCTestExpectation *firstExpectation = [self expectationWithDescription:@"first block run"];
    [expectations addObject:firstExpectation];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      [[GDTCORFlatFileStorage sharedInstance] nextBatchID:^(NSNumber *_Nonnull newBatchID) {
        batchID = newBatchID;
        [firstExpectation fulfill];
      }];
    });
    XCTestExpectation *secondExpectation = [self expectationWithDescription:@"first block run"];
    [expectations addObject:secondExpectation];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UNSPECIFIED, 0), ^{
      [[GDTCORFlatFileStorage sharedInstance] nextBatchID:^(NSNumber *_Nonnull newBatchID) {
        batchID = newBatchID;
        [secondExpectation fulfill];
      }];
    });
  }
  [self waitForExpectations:expectations timeout:30];
  XCTAssertEqualObjects(batchID, @(expectedBatchID));
}

/** Tests basic batch creation and removal. */
- (void)testBatchIDWithTarget {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  NSSet<GDTCOREvent *> *testTargetEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return event.target == kGDTCORTargetTest;
      }]];
  XCTAssertNotNil(testTargetEvents);
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch callback invoked"];
  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
  __block NSNumber *batchID;
  [storage batchWithEventSelector:eventSelector
                  batchExpiration:[NSDate dateWithTimeIntervalSinceNow:600]
                       onComplete:^(NSNumber *_Nullable newBatchID,
                                    NSSet<GDTCOREvent *> *_Nullable events) {
                         batchID = newBatchID;
                         XCTAssertNotNil(batchID);
                         XCTAssertEqual(events.count, testTargetEvents.count);
                         [expectation fulfill];
                       }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  XCTAssertNotNil(batchID);
  expectation = [self expectationWithDescription:@"pathsForTarget completion invoked"];
  [storage pathsForTarget:kGDTCORTargetTest
                 eventIDs:nil
                 qosTiers:nil
               mappingIDs:nil
               onComplete:^(NSSet<NSString *> *_Nonnull paths) {
                 XCTAssertEqual(paths.count, 0);
                 [expectation fulfill];
               }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests creating a batch and then deleting the files. */
- (void)testRemoveBatchWithIDDeletingEvents {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  __block NSUInteger testTargetSize = 0;
  NSSet<GDTCOREvent *> *testTargetEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        NSError *error;
        testTargetSize +=
            event.target == kGDTCORTargetTest ? GDTCOREncodeArchive(event, nil, &error).length : 0;
        XCTAssertNil(error);
        return event.target == kGDTCORTargetTest;
      }]];
  XCTAssertNotNil(testTargetEvents);

  __block uint64_t totalSize;
  [storage storageSizeWithCallback:^(uint64_t storageSize) {
    totalSize = storageSize;
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"batch callback invoked"];
  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
  __block NSNumber *batchID;
  [storage batchWithEventSelector:eventSelector
                  batchExpiration:[NSDate dateWithTimeIntervalSinceNow:600]
                       onComplete:^(NSNumber *_Nullable newBatchID,
                                    NSSet<GDTCOREvent *> *_Nullable events) {
                         batchID = newBatchID;
                         XCTAssertNotNil(batchID);
                         XCTAssertEqual(events.count, testTargetEvents.count);
                         [expectation fulfill];
                       }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  expectation = [self expectationWithDescription:@"batch removal completion invoked"];
  [storage removeBatchWithID:batchID
                deleteEvents:YES
                  onComplete:^{
                    [expectation fulfill];
                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  expectation = [self expectationWithDescription:@"storageSize callback invoked"];
  [storage storageSizeWithCallback:^(uint64_t storageSize) {
    XCTAssertLessThan(storageSize * .95, totalSize - testTargetSize);  // .95 to allow overhead
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests creating a batch and then deleting the files. */
- (void)testRemoveBatchWithID {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  __block NSUInteger testTargetSize = 0;
  NSSet<GDTCOREvent *> *testTargetEvents = [generatedEvents
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 GDTCOREvent *_Nullable event,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        NSError *error;
        testTargetSize +=
            event.target == kGDTCORTargetTest ? GDTCOREncodeArchive(event, nil, &error).length : 0;
        XCTAssertNil(error);
        return event.target == kGDTCORTargetTest;
      }]];
  XCTAssertNotNil(testTargetEvents);

  __block uint64_t totalSize;
  [storage storageSizeWithCallback:^(uint64_t storageSize) {
    totalSize = storageSize;
  }];

  XCTestExpectation *expectation = [self expectationWithDescription:@"batch callback invoked"];
  GDTCORStorageEventSelector *eventSelector =
      [GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest];
  __block NSNumber *batchID;
  [storage batchWithEventSelector:eventSelector
                  batchExpiration:[NSDate dateWithTimeIntervalSinceNow:600]
                       onComplete:^(NSNumber *_Nullable newBatchID,
                                    NSSet<GDTCOREvent *> *_Nullable events) {
                         batchID = newBatchID;
                         XCTAssertNotNil(batchID);
                         XCTAssertEqual(events.count, testTargetEvents.count);
                         [expectation fulfill];
                       }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  expectation = [self expectationWithDescription:@"batch removal completion invoked"];
  [storage removeBatchWithID:batchID
                deleteEvents:YES
                  onComplete:^{
                    [expectation fulfill];
                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  expectation = [self expectationWithDescription:@"storageSize callback invoked"];
  [storage storageSizeWithCallback:^(uint64_t storageSize) {
    XCTAssertLessThan(storageSize * .95, totalSize - testTargetSize);  // .95 to allow overhead
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests events expiring at a given time. */
- (void)testCheckEventExpiration {
  NSTimeInterval delay = 10.0;
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertFalse(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"testing" target:kGDTCORTargetTest];
  event.expirationDate = [NSDate dateWithTimeIntervalSinceNow:delay];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  expectation = [self expectationWithDescription:@"storeEvent completion"];
  [[GDTCORFlatFileStorage sharedInstance] storeEvent:event
                                          onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
                                            XCTAssertTrue(wasWritten);
                                            XCTAssertNil(error);
                                            [expectation fulfill];
                                          }];
  [self waitForExpectations:@[ expectation ] timeout:5.0];
  expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertTrue(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:delay]];
  [[GDTCORFlatFileStorage sharedInstance] checkForExpirations];
  expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [[GDTCORFlatFileStorage sharedInstance] hasEventsForTarget:kGDTCORTargetTest
                                                  onComplete:^(BOOL hasEvents) {
                                                    XCTAssertFalse(hasEvents);
                                                    [expectation fulfill];
                                                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

/** Tests batch expiring at a given time. */
- (void)testCheckBatchExpiration {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSTimeInterval delay = 10.0;
  [self generateEventsForStorageTesting];
  XCTestExpectation *expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertTrue(hasEvents);
                     [expectation fulfill];
                   }];
  [self waitForExpectations:@[ expectation ] timeout:10];

  expectation = [self expectationWithDescription:@"no batches exist"];
  [storage batchIDsForTarget:kGDTCORTargetTest
                  onComplete:^(NSSet<NSNumber *> *_Nonnull newBatchIDs) {
                    XCTAssertEqual(newBatchIDs.count, 0);
                    [expectation fulfill];
                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  expectation = [self expectationWithDescription:@"batch created"];
  __block NSNumber *batchID;
  [storage
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:delay]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable events) {
                    batchID = newBatchID;
                    XCTAssertGreaterThan(events.count, 0);
                    [expectation fulfill];
                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  expectation = [self expectationWithDescription:@"a batch now exists"];
  [storage batchIDsForTarget:kGDTCORTargetTest
                  onComplete:^(NSSet<NSNumber *> *_Nonnull newBatchIDs) {
                    XCTAssertEqual(newBatchIDs.count, 1);
                    [expectation fulfill];
                  }];
  [self waitForExpectations:@[ expectation ] timeout:10];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:delay]];
  [[GDTCORFlatFileStorage sharedInstance] checkForExpirations];
  expectation = [self expectationWithDescription:@"no batch exists after expiration"];
  [storage batchIDsForTarget:kGDTCORTargetTest
                  onComplete:^(NSSet<NSNumber *> *_Nonnull newBatchIDs) {
                    XCTAssertEqual(newBatchIDs.count, 0);
                    [expectation fulfill];
                  }];
  [self waitForExpectations:@[ expectation ] timeout:30];
  expectation = [self expectationWithDescription:@"hasEvent completion called"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertFalse(hasEvents);
                     [expectation fulfill];
                   }];
  [self waitForExpectations:@[ expectation ] timeout:10];
}

@end
