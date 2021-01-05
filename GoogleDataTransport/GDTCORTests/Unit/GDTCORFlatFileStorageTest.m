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

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORPlatform.h"
#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORRegistrar.h"
#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCOREvent.h"

#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCOREventGenerator.h"
#import "GoogleDataTransport/GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

#import "GoogleDataTransport/GDTCORTests/Common/Fakes/GDTCORUploadCoordinatorFake.h"

#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h"
#import "GoogleDataTransport/GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORDirectorySizeTracker.h"

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

/** The uploader fake. */
@property(nonatomic) GDTCORUploadCoordinatorFake *uploaderFake;

@end

@implementation GDTCORFlatFileStorageTest

- (void)setUp {
  [super setUp];
  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORFlatFileStorage sharedInstance] reset];
  self.uploaderFake = [[GDTCORUploadCoordinatorFake alloc] init];
  [GDTCORFlatFileStorage sharedInstance].uploadCoordinator = self.uploaderFake;
  [[GDTCORFlatFileStorage sharedInstance] reset];
  [[NSFileManager defaultManager] fileExistsAtPath:[GDTCORFlatFileStorage eventDataStoragePath]];
}

- (void)tearDown {
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
                });
  // Destroy these objects before the next test begins.
  [GDTCORFlatFileStorage sharedInstance].uploadCoordinator =
      [GDTCORUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
  [super tearDown];
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

- (void)testBatchIDsForTarget {
  __auto_type expectedBatch = [self generateAndBatchEvents];

  XCTestExpectation *batchIDsExpectation = [self expectationWithDescription:@"batchIDsExpectation"];

  [[GDTCORFlatFileStorage sharedInstance]
      batchIDsForTarget:kGDTCORTargetTest
             onComplete:^(NSSet<NSNumber *> *_Nullable batchIDs) {
               [batchIDsExpectation fulfill];

               XCTAssertEqual(batchIDs.count, 1);
               XCTAssertEqualObjects([expectedBatch.allKeys firstObject], [batchIDs anyObject]);
             }];

  [self waitForExpectations:@[ batchIDsExpectation ] timeout:5];
}

#pragma mark - Expiration tests

/** Tests events expiring at a given time. */
- (void)testCheckForExpirations_WhenEventsExpire {
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

- (void)testCheckForExpirations_WhenBatchWithNotExpiredEventsExpires {
  NSTimeInterval batchExpiresIn = 0.5;
  // 0.1. Generate and batch events
  __auto_type generatedBatch = [self generateAndBatchEventsExpiringIn:1000
                                                      batchExpiringIn:batchExpiresIn];
  NSNumber *generatedBatchID = [[generatedBatch allKeys] firstObject];
  NSSet<GDTCOREvent *> *generatedEvents = generatedBatch[generatedBatchID];
  // 0.2. Wait for batch expiration.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:batchExpiresIn]];

  // 1. Check for expiration.
  [[GDTCORFlatFileStorage sharedInstance] checkForExpirations];

  // 2. Check events.
  // 2.1. Expect no batches left.
  XCTestExpectation *getBatchesExpectation =
      [self expectationWithDescription:@"getBatchesExpectation"];
  [[GDTCORFlatFileStorage sharedInstance]
      batchIDsForTarget:kGDTCORTargetTest
             onComplete:^(NSSet<NSNumber *> *_Nullable batchIDs) {
               [getBatchesExpectation fulfill];
               XCTAssertEqual(batchIDs.count, 0);
             }];

  // 2.2. Expect the events back in the main storage.
  XCTestExpectation *getEventsExpectation =
      [self expectationWithDescription:@"getEventsExpectation"];
  [[GDTCORFlatFileStorage sharedInstance]
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:1000]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable batchEvents) {
                    [getEventsExpectation fulfill];
                    XCTAssertNotNil(newBatchID);
                    NSSet<NSString *> *batchEventsIDs = [batchEvents valueForKeyPath:@"eventID"];
                    NSSet<NSString *> *generatedEventsIDs =
                        [generatedEvents valueForKeyPath:@"eventID"];
                    XCTAssertEqualObjects(batchEventsIDs, generatedEventsIDs);
                  }];

  [self waitForExpectations:@[ getBatchesExpectation, getEventsExpectation ] timeout:0.5];
}

- (void)testCheckForExpirations_WhenBatchWithExpiredEventsExpires {
  NSTimeInterval batchExpiresIn = 0.5;
  NSTimeInterval eventsExpireIn = 0.5;
  // 0.1. Generate and batch events
  __unused __auto_type generatedBatch = [self generateAndBatchEventsExpiringIn:eventsExpireIn
                                                               batchExpiringIn:batchExpiresIn];
  // 0.2. Wait for batch expiration.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:batchExpiresIn]];

  // 1. Check for expiration.
  [[GDTCORFlatFileStorage sharedInstance] checkForExpirations];

  // 2. Check events.
  // 2.1. Expect no batches left.
  XCTestExpectation *getBatchesExpectation =
      [self expectationWithDescription:@"getBatchesExpectation"];
  [[GDTCORFlatFileStorage sharedInstance]
      batchIDsForTarget:kGDTCORTargetTest
             onComplete:^(NSSet<NSNumber *> *_Nullable batchIDs) {
               [getBatchesExpectation fulfill];
               XCTAssertEqual(batchIDs.count, 0);
             }];

  // 2.2. Expect events to be deleted.
  XCTestExpectation *getEventsExpectation =
      [self expectationWithDescription:@"getEventsExpectation"];
  [[GDTCORFlatFileStorage sharedInstance]
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:1000]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable batchEvents) {
                    [getEventsExpectation fulfill];
                    XCTAssertNil(newBatchID);
                    XCTAssertEqual(batchEvents.count, 0);
                  }];

  [self waitForExpectations:@[ getBatchesExpectation, getEventsExpectation ] timeout:0.5];
}

#pragma mark - Remove Batch tests

- (void)testRemoveBatchWithIDWithNoDeletingEvents {
  GDTCORFlatFileStorage *storage = [[GDTCORFlatFileStorage alloc] init];

  // 0. Prepare a batch to remove.
  __auto_type generatedBatch = [self generateAndBatchEvents];
  NSNumber *batchIDToRemove = [generatedBatch.allKeys firstObject];
  NSSet<GDTCOREvent *> *generatedEvents = generatedBatch[batchIDToRemove];

  // 2. Remove batch.
  XCTestExpectation *batchRemovedExpectation =
      [self expectationWithDescription:@"batchRemovedExpectation"];
  [storage removeBatchWithID:batchIDToRemove
                deleteEvents:NO
                  onComplete:^{
                    [batchRemovedExpectation fulfill];
                  }];
  [self waitForExpectations:@[ batchRemovedExpectation ] timeout:0.5];

  // 3. Validate no batches.
  [self assertBatchIDs:nil inStorage:storage];

  // 4. Validate events.
  GDTCORStorageEventSelector *testEventsSelector =
      [[GDTCORStorageEventSelector alloc] initWithTarget:kGDTCORTargetTest
                                                eventIDs:nil
                                              mappingIDs:nil
                                                qosTiers:nil];
  XCTestExpectation *eventsBatchedExpectation2 =
      [self expectationWithDescription:@"eventsBatchedExpectation1"];
  [storage batchWithEventSelector:testEventsSelector
                  batchExpiration:[NSDate distantFuture]
                       onComplete:^(NSNumber *_Nullable newBatchID,
                                    NSSet<GDTCOREvent *> *_Nullable batchEvents) {
                         [eventsBatchedExpectation2 fulfill];
                         XCTAssertNotNil(newBatchID);
                         XCTAssertEqual(generatedEvents.count, batchEvents.count);

                         NSSet<NSString *> *batchEventsIDs =
                             [batchEvents valueForKeyPath:@"eventID"];
                         NSSet<NSString *> *generatedEventsIDs =
                             [generatedEvents valueForKeyPath:@"eventID"];
                         XCTAssertEqualObjects(batchEventsIDs, generatedEventsIDs);
                       }];
  [self waitForExpectations:@[ eventsBatchedExpectation2 ] timeout:0.5];
}

- (void)testRemoveBatchWithIDWithNoDeletingEventsConflictingEvents {
  GDTCORFlatFileStorage *storage = [[GDTCORFlatFileStorage alloc] init];

  // 0.1. Prepare a batch to remove.
  __auto_type generatedBatch = [self generateAndBatchEvents];
  NSNumber *batchIDToRemove = [generatedBatch.allKeys firstObject];
  NSSet<GDTCOREvent *> *generatedEvents = generatedBatch[batchIDToRemove];

  // 0.2. Store an event with conflicting ID.
  [self storeEvent:[generatedEvents anyObject] inStorage:storage];

  // 0.3. Store another event.
  GDTCOREvent *differentEvent = [GDTCOREventGenerator generateEventForTarget:kGDTCORTargetTest
                                                                     qosTier:nil
                                                                   mappingID:nil];
  [self storeEvent:differentEvent inStorage:storage];

  NSMutableSet<GDTCOREvent *> *expectedEvents = [generatedEvents mutableCopy];
  [expectedEvents addObject:differentEvent];

  // 2. Remove batch.
  XCTestExpectation *batchRemovedExpectation =
      [self expectationWithDescription:@"batchRemovedExpectation"];
  [storage removeBatchWithID:batchIDToRemove
                deleteEvents:NO
                  onComplete:^{
                    [batchRemovedExpectation fulfill];
                  }];
  [self waitForExpectations:@[ batchRemovedExpectation ] timeout:0.5];

  // 3. Validate no batches.
  [self assertBatchIDs:nil inStorage:storage];

  // 4. Validate events.
  XCTestExpectation *eventsBatchedExpectation2 =
      [self expectationWithDescription:@"eventsBatchedExpectation1"];
  GDTCORStorageEventSelector *testEventsSelector =
      [[GDTCORStorageEventSelector alloc] initWithTarget:kGDTCORTargetTest
                                                eventIDs:nil
                                              mappingIDs:nil
                                                qosTiers:nil];
  [storage batchWithEventSelector:testEventsSelector
                  batchExpiration:[NSDate distantFuture]
                       onComplete:^(NSNumber *_Nullable newBatchID,
                                    NSSet<GDTCOREvent *> *_Nullable batchEvents) {
                         [eventsBatchedExpectation2 fulfill];
                         XCTAssertNotNil(newBatchID);
                         XCTAssertEqual(expectedEvents.count, batchEvents.count);

                         NSSet<NSString *> *batchEventsIDs =
                             [batchEvents valueForKeyPath:@"eventID"];
                         NSSet<NSString *> *expectedEventsIDs =
                             [expectedEvents valueForKeyPath:@"eventID"];
                         XCTAssertEqualObjects(batchEventsIDs, expectedEventsIDs);
                       }];
  [self waitForExpectations:@[ eventsBatchedExpectation2 ] timeout:0.5];
}

- (void)testRemoveBatchWithIDDeletingEvents {
  GDTCORFlatFileStorage *storage = [[GDTCORFlatFileStorage alloc] init];

  // 0. Prepare a batch to remove.
  __auto_type generatedBatch = [self generateAndBatchEvents];
  NSNumber *batchIDToRemove = [generatedBatch.allKeys firstObject];

  // 2. Remove batch.
  XCTestExpectation *batchRemovedExpectation =
      [self expectationWithDescription:@"batchRemovedExpectation"];
  [storage removeBatchWithID:batchIDToRemove
                deleteEvents:YES
                  onComplete:^{
                    [batchRemovedExpectation fulfill];
                  }];
  [self waitForExpectations:@[ batchRemovedExpectation ] timeout:0.5];

  // 3. Validate no batches.
  [self assertBatchIDs:nil inStorage:storage];

  // 4. Validate events.
  XCTestExpectation *eventsBatchedExpectation2 =
      [self expectationWithDescription:@"eventsBatchedExpectation1"];
  GDTCORStorageEventSelector *testEventsSelector =
      [[GDTCORStorageEventSelector alloc] initWithTarget:kGDTCORTargetTest
                                                eventIDs:nil
                                              mappingIDs:nil
                                                qosTiers:nil];
  [storage batchWithEventSelector:testEventsSelector
                  batchExpiration:[NSDate distantFuture]
                       onComplete:^(NSNumber *_Nullable newBatchID,
                                    NSSet<GDTCOREvent *> *_Nullable batchEvents) {
                         [eventsBatchedExpectation2 fulfill];
                         XCTAssertNil(newBatchID);
                         XCTAssertEqual(batchEvents.count, 0);
                       }];
  [self waitForExpectations:@[ eventsBatchedExpectation2 ] timeout:500];
}

/** Tests creating a batch and then deleting the files. */
- (void)testRemoveBatchWithIDDeletingEventsStorageSize {
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

#pragma mark - Storage Size Limit

/** Tests that the size of the storage is returned accurately. */
- (void)testStorageSizeWithCallback {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];

  NSUInteger ongoingSize = 0;
  XCTAssertEqual([self storageSize], 0);

  // 1. Check add library data.
  NSData *libData = [@"this is a test" dataUsingEncoding:NSUTF8StringEncoding];
  ongoingSize += libData.length;
  [storage storeLibraryData:libData forKey:@"testKey" onComplete:nil];
  XCTAssertEqual([self storageSize], ongoingSize);

  // 2. Check update library data.
  NSData *updatedLibData = [@"updated" dataUsingEncoding:NSUTF8StringEncoding];
  ongoingSize -= libData.length;
  ongoingSize += updatedLibData.length;
  [storage libraryDataForKey:@"testKey"
      onFetchComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
      }
      setNewValue:^NSData *_Nullable {
        return updatedLibData;
      }];
  XCTAssertEqual([self storageSize], ongoingSize);

  // 3. Check store events.
  NSSet<GDTCOREvent *> *generatedEvents = [self generateEventsForStorageTesting];
  ongoingSize += [self storageSizeOfEvents:generatedEvents];
  XCTAssertEqual([self storageSize], ongoingSize);

  // 4. Check remove lib data.
  ongoingSize -= updatedLibData.length;
  [storage removeLibraryDataForKey:@"testKey"
                        onComplete:^(NSError *_Nullable error){
                        }];
  XCTAssertEqual([self storageSize], ongoingSize);

  // 5. Check batch.
  XCTestExpectation *batchCreatedExpectation =
      [self expectationWithDescription:@"batchCreatedExpectation"];
  __block NSNumber *batchID;
  __block uint64_t batchedEventSize = 0;
  [storage
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:1000]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable events) {
                    batchID = newBatchID;
                    batchedEventSize = [self storageSizeOfEvents:events];
                    // 100 - kGDTCORTargetTest generated events count.
                    XCTAssertEqual(events.count, 100);
                    [batchCreatedExpectation fulfill];
                  }];
  [self waitForExpectations:@[ batchCreatedExpectation ] timeout:5];
  // Expect size increase due to the batch counter stored in lib data.
  ongoingSize += sizeof(int32_t);
  XCTAssertEqual([self storageSize], ongoingSize);

  // 6. Batch remove.
  [storage removeBatchWithID:batchID
                deleteEvents:YES
                  onComplete:^{
                  }];
  ongoingSize -= batchedEventSize;
  XCTAssertEqual([self storageSize], ongoingSize);
}

- (void)testStoreEvent_WhenSizeLimitReached_ThenNewEventIsSkipped {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];

  // 1. Generate and store maximum allowed amount of events.
  __auto_type generatedEvents =
      [self generateAndStoreEventsWithTotalSizeUpTo:kGDTCORFlatFileStorageSizeLimit];

  XCTAssertGreaterThan([self storageSizeOfEvents:generatedEvents] +
                           [self storageEventSize:[generatedEvents anyObject]],
                       kGDTCORFlatFileStorageSizeLimit);

  // 2. Check storage size.
  uint64_t storageSize = [self storageSize];
  XCTAssertEqual(storageSize, [self storageSizeOfEvents:generatedEvents]);

  // 3. Try to add another event.
  GDTCOREvent *event = [GDTCOREventGenerator generateEventForTarget:kGDTCORTargetTest
                                                            qosTier:nil
                                                          mappingID:nil];
  event.expirationDate = [NSDate dateWithTimeIntervalSinceNow:1000];

  XCTestExpectation *storeExpectation1 = [self expectationWithDescription:@"storeExpectation1"];
  [storage storeEvent:event
           onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
             XCTAssertFalse(wasWritten);
             XCTAssertNotNil(error);
             XCTAssertEqualObjects(error.domain, GDTCORFlatFileStorageErrorDomain);
             XCTAssertEqual(error.code, GDTCORFlatFileStorageErrorSizeLimitReached);
             [storeExpectation1 fulfill];
           }];
  [self waitForExpectations:@[ storeExpectation1 ] timeout:5];

  // 4. Check the storage size didn't change.
  XCTAssertEqual([self storageSize], storageSize);

  // 5. Batch and remove events
  XCTestExpectation *batchCreatedExpectation =
      [self expectationWithDescription:@"batchCreatedExpectation"];
  __block NSNumber *batchID;
  [storage
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:1000]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable events) {
                    batchID = newBatchID;
                    XCTAssertGreaterThan(events.count, 0);
                    [batchCreatedExpectation fulfill];
                  }];
  [self waitForExpectations:@[ batchCreatedExpectation ] timeout:generatedEvents.count * 0.1];

  XCTestExpectation *removeBatchExpectation = [self expectationWithDescription:@"removeBatch"];
  [storage removeBatchWithID:batchID
                deleteEvents:YES
                  onComplete:^{
                    [removeBatchExpectation fulfill];
                  }];
  [self waitForExpectations:@[ removeBatchExpectation ] timeout:generatedEvents.count * 0.1];

  // 6. Try to add another event.
  XCTestExpectation *storeExpectation2 = [self expectationWithDescription:@"storeExpectation2"];
  [storage storeEvent:event
           onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
             XCTAssertTrue(wasWritten);
             XCTAssertNil(error);
             [storeExpectation2 fulfill];
           }];
  [self waitForExpectations:@[ storeExpectation2 ] timeout:5];

  GDTCORStorageSizeBytes lastBatchIDSize = sizeof(int32_t);
  XCTAssertEqual([self storageSize], [self storageEventSize:event] + lastBatchIDSize);
}

#pragma mark - Helpers

/** Generates and returns a set of events that are generated randomly and stored.
 *
 * @return A set of randomly generated and stored events.
 */
- (NSSet<GDTCOREvent *> *)generateEventsForStorageTesting {
  NSMutableSet<GDTCOREvent *> *generatedEvents = [[NSMutableSet alloc] init];
  // Generate 100 test target events
  [generatedEvents unionSet:[self generateEventsForTarget:kGDTCORTargetTest
                                               expiringIn:1000
                                                    count:100]];

  // Generate 50 FLL target events.
  [generatedEvents unionSet:[self generateEventsForTarget:kGDTCORTargetFLL
                                               expiringIn:1000
                                                    count:50]];

  return generatedEvents;
}

/** Generates and stores events with specified parameters.
 *  @return Generated events.
 */
- (NSSet<GDTCOREvent *> *)generateEventsForTarget:(GDTCORTarget)target
                                       expiringIn:(NSTimeInterval)eventsExpireIn
                                            count:(NSInteger)count {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSMutableSet<GDTCOREvent *> *generatedEvents = [[NSMutableSet alloc] init];

  XCTestExpectation *generatedEventsStoredExpectation =
      [self expectationWithDescription:@"generatedEventsStoredExpectation"];
  generatedEventsStoredExpectation.expectedFulfillmentCount = count;

  for (int i = 0; i < count; i++) {
    GDTCOREvent *event = [GDTCOREventGenerator generateEventForTarget:target
                                                              qosTier:nil
                                                            mappingID:nil];
    event.expirationDate = [NSDate dateWithTimeIntervalSinceNow:eventsExpireIn];
    [generatedEvents addObject:event];
    [storage storeEvent:event
             onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
               XCTAssertTrue(wasWritten);
               XCTAssertNil(error);
               [generatedEventsStoredExpectation fulfill];
             }];
  }

  [self waitForExpectations:@[ generatedEventsStoredExpectation ] timeout:1 * count];

  return generatedEvents;
}

/** Generates and stores events to fill up the storage up the the specified size.
 *  @return Generated events.
 */
- (NSSet<GDTCOREvent *> *)generateAndStoreEventsWithTotalSizeUpTo:
    (GDTCORStorageSizeBytes)totalSize {
  GDTCORTarget target = kGDTCORTargetTest;
  GDTCORStorageSizeBytes eventsSize = 0;

  NSMutableSet<GDTCOREvent *> *generatedEvents = [[NSMutableSet alloc] init];
  GDTCOREvent *generatedEvent = [GDTCOREventGenerator generateEventForTarget:target
                                                                     qosTier:nil
                                                                   mappingID:nil];

  do {
    XCTestExpectation *eventStoredExpectation = [self expectationWithDescription:@"eventStored"];
    [[GDTCORFlatFileStorage sharedInstance]
        storeEvent:generatedEvent
        onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
          XCTAssertTrue(wasWritten);
          XCTAssertNil(error);
          [eventStoredExpectation fulfill];
        }];

    [self waitForExpectations:@[ eventStoredExpectation ] timeout:1];

    [generatedEvents addObject:generatedEvent];
    eventsSize += [self storageEventSize:generatedEvent];

    generatedEvent = [GDTCOREventGenerator generateEventForTarget:target qosTier:nil mappingID:nil];

  } while (eventsSize + [self storageEventSize:generatedEvent] <= totalSize);

  return generatedEvents;
}

/** Generates, stores and batches 100 events.
 *  @return A dictionary with the generated events by the batch ID.
 */
- (NSDictionary<NSNumber *, NSSet<GDTCOREvent *> *> *)generateAndBatchEvents {
  return [self generateAndBatchEventsExpiringIn:1000 batchExpiringIn:1000];
}

/** Generates, stores and batches 100 events with specified parameters.
 *  @return A dictionary with the generated events by the batch ID.
 */
- (NSDictionary<NSNumber *, NSSet<GDTCOREvent *> *> *)
    generateAndBatchEventsExpiringIn:(NSTimeInterval)eventsExpireIn
                     batchExpiringIn:(NSTimeInterval)batchExpiresIn {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];
  NSSet<GDTCOREvent *> *events = [self generateEventsForTarget:kGDTCORTargetTest
                                                    expiringIn:eventsExpireIn
                                                         count:100];
  XCTestExpectation *eventsGeneratedExpectation =
      [self expectationWithDescription:@"eventsGeneratedExpectation"];
  [storage hasEventsForTarget:kGDTCORTargetTest
                   onComplete:^(BOOL hasEvents) {
                     XCTAssertTrue(hasEvents);
                     [eventsGeneratedExpectation fulfill];
                   }];
  [self waitForExpectations:@[ eventsGeneratedExpectation ] timeout:5];

  // Batch generated events.
  XCTestExpectation *batchCreatedExpectation =
      [self expectationWithDescription:@"batchCreatedExpectation"];
  __block NSNumber *batchID;
  [storage
      batchWithEventSelector:[GDTCORStorageEventSelector eventSelectorForTarget:kGDTCORTargetTest]
             batchExpiration:[NSDate dateWithTimeIntervalSinceNow:batchExpiresIn]
                  onComplete:^(NSNumber *_Nullable newBatchID,
                               NSSet<GDTCOREvent *> *_Nullable events) {
                    batchID = newBatchID;
                    XCTAssertGreaterThan(events.count, 0);
                    [batchCreatedExpectation fulfill];
                  }];
  [self waitForExpectations:@[ batchCreatedExpectation ] timeout:5];

  return @{batchID : events};
}

/** Calls `[GDTCORFlatFileStorage batchIDsForTarget:onComplete:]`, waits for the completion and
 * asserts the result. */
- (void)assertBatchIDs:(NSSet<NSNumber *> *)expectedBatchIDs
             inStorage:(GDTCORFlatFileStorage *)storage {
  XCTestExpectation *batchIDsFetchedExpectation =
      [self expectationWithDescription:@"batchIDsFetchedExpectation"];

  [storage batchIDsForTarget:kGDTCORTargetTest
                  onComplete:^(NSSet<NSNumber *> *_Nullable batchIDs) {
                    [batchIDsFetchedExpectation fulfill];
                    XCTAssertEqualObjects(batchIDs, expectedBatchIDs);
                  }];

  [self waitForExpectations:@[ batchIDsFetchedExpectation ] timeout:0.5];
}

/** Calls `[GDTCORFlatFileStorage storeEvent:onComplete:]` and waits for the completion.  */
- (void)storeEvent:(GDTCOREvent *)event inStorage:(GDTCORFlatFileStorage *)storage {
  XCTestExpectation *eventStoredExpectation =
      [self expectationWithDescription:@"eventStoredExpectation"];
  [storage storeEvent:event
           onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
             [eventStoredExpectation fulfill];
             XCTAssertTrue(wasWritten);
             XCTAssertNil(error);
           }];
  [self waitForExpectations:@[ eventStoredExpectation ] timeout:0.5];
}

/** Calls  `[GDTCORFlatFileStorage storageSizeWithCallback]`, waits for completion and returns the
 * result. */
- (uint64_t)storageSize {
  __block uint64_t storageSize = 0;
  XCTestExpectation *expectation = [self expectationWithDescription:@"storageSize complete"];
  [[GDTCORFlatFileStorage sharedInstance] storageSizeWithCallback:^(uint64_t aStorageSize) {
    storageSize = aStorageSize;
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:1.0];
  return storageSize;
}

/** Returns an expected size taken by the events in the storage. */
- (GDTCORStorageSizeBytes)storageSizeOfEvents:(NSSet<GDTCOREvent *> *)events {
  uint64_t eventsSize = 0;
  for (GDTCOREvent *event in events) {
    eventsSize += [self storageEventSize:event];
  }
  return eventsSize;
}

/** Returns an expected size taken by the event in the storage. */
- (GDTCORStorageSizeBytes)storageEventSize:(GDTCOREvent *)event {
  NSError *error;
  NSData *serializedEventData = GDTCOREncodeArchive(event, nil, &error);
  XCTAssertNil(error);
  return serializedEventData.length;
}

@end
