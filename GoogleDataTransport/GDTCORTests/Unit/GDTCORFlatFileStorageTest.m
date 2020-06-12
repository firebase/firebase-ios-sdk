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

#import "GDTCORLibrary/Private/GDTCORFlatFileStorage.h"
#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"

#import "GDTCORLibrary/Public/GDTCOREvent.h"
#import "GDTCORLibrary/Public/GDTCORPlatform.h"
#import "GDTCORLibrary/Public/GDTCORRegistrar.h"

#import "GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GDTCORTests/Unit/Helpers/GDTCORDataObjectTesterClasses.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestPrioritizer.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

#import "GDTCORTests/Common/Fakes/GDTCORUploadCoordinatorFake.h"

#import "GDTCORTests/Common/Categories/GDTCORFlatFileStorage+Testing.h"
#import "GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"

static NSInteger target = kGDTCORTargetCCT;

@interface GDTCORFlatFileStorageTest : GDTCORTestCase

/** The test backend implementation. */
@property(nullable, nonatomic) GDTCORTestUploader *testBackend;

/** The test prioritizer implementation. */
@property(nullable, nonatomic) GDTCORTestPrioritizer *testPrioritizer;

/** The uploader fake. */
@property(nonatomic) GDTCORUploadCoordinatorFake *uploaderFake;

@end

@implementation GDTCORFlatFileStorageTest

- (void)setUp {
  [super setUp];
  self.testBackend = [[GDTCORTestUploader alloc] init];
  self.testPrioritizer = [[GDTCORTestPrioritizer alloc] init];
  [[GDTCORRegistrar sharedInstance] registerUploader:_testBackend target:target];
  [[GDTCORRegistrar sharedInstance] registerPrioritizer:_testPrioritizer target:target];
  self.uploaderFake = [[GDTCORUploadCoordinatorFake alloc] init];
  [GDTCORFlatFileStorage sharedInstance].uploadCoordinator = self.uploaderFake;
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
                });
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  self.testPrioritizer = nil;
  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORFlatFileStorage sharedInstance] reset];
  [GDTCORFlatFileStorage sharedInstance].uploadCoordinator =
      [GDTCORUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDTCORFlatFileStorage sharedInstance], [GDTCORFlatFileStorage sharedInstance]);
}

/** Tests storing an event. */
- (void)testStoreEvent {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 1);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].targetToEventSet[@(target)].count, 1);
    NSURL *eventFile = event.fileURL;
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:eventFile.path error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests removing an event. */
- (void)testRemoveEvent {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  __block NSURL *eventFile;
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    eventFile = event.fileURL;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });
  NSSet *eventIDs =
      [NSSet setWithArray:[[GDTCORFlatFileStorage sharedInstance].storedEvents allKeys]];
  [[GDTCORFlatFileStorage sharedInstance] removeEvents:eventIDs];
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 0);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].targetToEventSet[@(target)].count, 0);
  });
}

/** Tests removing a set of events. */
- (void)testRemoveEvents {
  GDTCORFlatFileStorage *storage = [GDTCORFlatFileStorage sharedInstance];

  GDTCOREvent *event1 = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event1.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString1"];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event1
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event1.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  GDTCOREvent *event2 = [[GDTCOREvent alloc] initWithMappingID:@"100" target:target];
  event2.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString2"];
  writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event2
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event2.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  GDTCOREvent *event3 = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event3.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString3"];
  writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event3
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event3.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  NSSet<NSNumber *> *eventIDSet =
      [NSSet setWithObjects:event1.eventID, event2.eventID, event3.eventID, nil];
  [storage removeEvents:eventIDSet];
  NSSet<GDTCOREvent *> *eventSet = [NSSet setWithObjects:event1, event2, event3, nil];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertNil(storage.storedEvents[event1.eventID]);
    XCTAssertNil(storage.storedEvents[event2.eventID]);
    XCTAssertNil(storage.storedEvents[event3.eventID]);
    XCTAssertEqual(storage.targetToEventSet[@(target)].count, 0);
    for (GDTCOREvent *event in eventSet) {
      XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:event.fileURL.path]);
    }
  });
}

/** Tests storing a few different events. */
- (void)testStoreMultipleEvents {
  GDTCOREvent *event1 = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event1.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString1"];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event1
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event1.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  XCTAssertNotNil(event1.fileURL);

  GDTCOREvent *event2 = [[GDTCOREvent alloc] initWithMappingID:@"100" target:target];
  event2.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString2"];
  writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event2
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event2.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  XCTAssertNotNil(event2.fileURL);

  GDTCOREvent *event3 = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event3.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString3"];
  writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event3
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event3.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  XCTAssertNotNil(event3.fileURL);

  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 3);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].targetToEventSet[@(target)].count, 3);

    NSURL *event1File = event1.fileURL;
    XCTAssertNotNil(event1File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event1File.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:event1File.path error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);

    NSURL *event2File = event2.fileURL;
    XCTAssertNotNil(event2File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event2File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:event2File.path error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);

    NSURL *event3File = event3.fileURL;
    XCTAssertNotNil(event3File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event3File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:event3File.path error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests enforcing that a prioritizer does not retain the DataObjectTransportBytes of an event in
 * memory.
 */
- (void)testEventDeallocationIsEnforced {
  __weak NSData *weakDataObjectTransportBytes;
  GDTCOREvent *event;
  @autoreleasepool {
    event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    weakDataObjectTransportBytes = [event.dataObject transportBytes];
    event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
    event.clockSnapshot = [GDTCORClock snapshot];
    // Store the event and wait for the expectation.
    XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
    XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
        storeEvent:event
        onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
          XCTAssertNotEqualObjects(event.eventID, @0);
          XCTAssertNil(error);
          [writtenExpectation fulfill];
        }]);
    [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  }
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertNil(weakDataObjectTransportBytes);
    XCTAssertNotNil(event);
  });

  NSURL *eventFile = event.fileURL;

  // This isn't strictly necessary because of the -waitForExpectations above.
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });

  // Ensure event was removed.
  NSSet *eventIDs =
      [NSSet setWithArray:[[GDTCORFlatFileStorage sharedInstance].storedEvents allKeys]];
  [[GDTCORFlatFileStorage sharedInstance] removeEvents:eventIDs];
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 0);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].targetToEventSet[@(target)].count, 0);
  });
}

/** Tests encoding and decoding the storage singleton correctly. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDTCORFlatFileStorage supportsSecureCoding]);
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event.eventID, @0);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  event = nil;
  __block NSData *storageData;
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    NSError *error;
    storageData = GDTCOREncodeArchive([GDTCORFlatFileStorage sharedInstance], nil, &error);
    XCTAssertNil(error);
    XCTAssertNotNil(storageData);
  });
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 1);
  });
  NSSet *eventIDs =
      [NSSet setWithArray:[[GDTCORFlatFileStorage sharedInstance].storedEvents allKeys]];
  [[GDTCORFlatFileStorage sharedInstance] removeEvents:eventIDs];
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 0);
  });
  NSError *error;
  GDTCORFlatFileStorage *unarchivedStorage = (GDTCORFlatFileStorage *)GDTCORDecodeArchive(
      [GDTCORFlatFileStorage class], nil, storageData, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(unarchivedStorage);
  XCTAssertGreaterThan([unarchivedStorage storedEvents].count, 0);
}

/** Tests encoding and decoding the storage singleton when calling -sharedInstance. */
- (void)testNSSecureCodingWithSharedInstance {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event
      onComplete:^(BOOL wasWritten, NSError *_Nullable error) {
        XCTAssertNotEqualObjects(event.eventID, @0);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];
  event = nil;
  __block NSData *storageData;
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    NSError *error;
    storageData = GDTCOREncodeArchive([GDTCORFlatFileStorage sharedInstance], nil, &error);
    XCTAssertNil(error);
    XCTAssertNotNil(storageData);
  });
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([GDTCORFlatFileStorage sharedInstance].storedEvents);
    XCTAssertGreaterThan([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 0);
  });
  NSSet *eventIDs =
      [NSSet setWithArray:[[GDTCORFlatFileStorage sharedInstance].storedEvents allKeys]];
  [[GDTCORFlatFileStorage sharedInstance] removeEvents:eventIDs];
  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([GDTCORFlatFileStorage sharedInstance].storedEvents);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 0);
  });
  NSError *error;
  GDTCORFlatFileStorage *unarchivedStorage = (GDTCORFlatFileStorage *)GDTCORDecodeArchive(
      [GDTCORFlatFileStorage class], nil, storageData, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(unarchivedStorage);
  XCTAssertNotNil([unarchivedStorage storedEvents]);
  XCTAssertGreaterThan([unarchivedStorage storedEvents].count, 0);
}

/** Tests sending a fast priority event causes an upload attempt. */
- (void)testQoSTierFast {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:@"testString"];
  event.qosTier = GDTCOREventQoSFast;
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTAssertFalse(self.uploaderFake.forceUploadCalled);
  XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
  XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
      storeEvent:event
      onComplete:^(BOOL wasWritten, NSError *error) {
        XCTAssertNotEqualObjects(event.eventID, @0);
        XCTAssertNil(error);
        [writtenExpectation fulfill];
      }]);
  [self waitForExpectations:@[ writtenExpectation ] timeout:10.0];

  dispatch_sync([GDTCORFlatFileStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].storedEvents.count, 1);
    XCTAssertEqual([GDTCORFlatFileStorage sharedInstance].targetToEventSet[@(target)].count, 1);
    NSURL *eventFile = event.fileURL;
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtPath:eventFile.path error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Fuzz tests the storing of events at the same time as a terminate lifecycle notification. This
 * test can fail if there's simultaneous access to ivars of GDTCORFlatFileStorage with one access
 * being off the storage's queue. The terminate lifecycle event should operate on and flush the
 * queue.
 */
- (void)testStoringEventsDuringTerminate {
  int numberOfIterations = 1000;
  for (int i = 0; i < numberOfIterations; i++) {
    NSString *testString = [NSString stringWithFormat:@"testString %d", i];
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObject = [[GDTCORDataObjectTesterSimple alloc] initWithString:testString];
    event.clockSnapshot = [GDTCORClock snapshot];
    XCTestExpectation *writtenExpectation = [self expectationWithDescription:@"event written"];
    XCTAssertNoThrow([[GDTCORFlatFileStorage sharedInstance]
        storeEvent:event
        onComplete:^(BOOL wasWritten, NSError *error) {
          XCTAssertNotEqualObjects(event.eventID, @0);
          [writtenExpectation fulfill];
        }]);
    [self waitForExpectationsWithTimeout:10 handler:nil];
    if (i % 5 == 0) {
      NSSet *eventIDs =
          [NSSet setWithArray:[[GDTCORFlatFileStorage sharedInstance].storedEvents allKeys]];
      [[GDTCORFlatFileStorage sharedInstance] removeEvents:eventIDs];
    }
    [NSNotificationCenter.defaultCenter
        postNotificationName:kGDTCORApplicationWillTerminateNotification
                      object:nil];
  }
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
             onComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
               [expectation fulfill];
               XCTAssertNil(error);
               XCTAssertEqualObjects(@"test data",
                                     [[NSString alloc] initWithData:data
                                                           encoding:NSUTF8StringEncoding]);
             }];
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
  [[GDTCORFlatFileStorage sharedInstance]
      libraryDataForKey:dataKey
             onComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
               [expectation fulfill];
               XCTAssertNil(error);
               XCTAssertEqualObjects(@"test data",
                                     [[NSString alloc] initWithData:data
                                                           encoding:NSUTF8StringEncoding]);
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
             onComplete:^(NSData *_Nullable data, NSError *_Nullable error) {
               [expectation fulfill];
               XCTAssertNotNil(error);
               XCTAssertNil(data);
             }];
  [self waitForExpectations:@[ expectation ] timeout:10.0];
}

/** Tests migration from v1 of the storage format to v2. */
- (void)testMigrationFromOldVersion {
  static NSString *base64EncodedArchive =
      @"YnBsaXN0MDDUAAEAAgADAAQABQAGAAcAClgkdmVyc2lvblkkYXJjaGl2ZXJUJHRvcFgkb2JqZWN0cxIAAYagXxAPTlN"
      @"LZXllZEFyY2hpdmVy0QAIAAlUcm9vdIABrxBxAAsADAAVADsASQBPAFUAVgBcAGAAYQBiAGMAbQBxAHUAfQCBAIUAhg"
      @"CKAJIAlgCaAJsAnwCnAKsArwCwALQAvADAAMQAxQDGAMoA0gDWANoA2wDfAOcA6wDvAPAA8QD1AP0BAQEFAQYBCgESA"
      @"RYBGgEbAR8BJwErAS8BMAE0ATwBQAFEAUUBSQFRAVUBWQFaAV4BZgFqAW4BbwFwAXQBfAGAAYQBhQGJAZEBlQGZAZoB"
      @"ngGmAaoBrgGvAbABtAG8AcABxAHFAckB0QHVAdkB2gHeAeMB7QH2AfsCCgIPAhECFVUkbnVsbNQADQAOAA8AEAARABI"
      @"AEwAUXxAhR0RUQ09SU3RvcmFnZVVwbG9hZENvb3JkaW5hdG9yS2V5XxAgR0RUQ09SU3RvcmFnZVRhcmdldFRvRXZlbn"
      @"RTZXRLZXlfEBxHRFRDT1JTdG9yYWdlU3RvcmVkRXZlbnRzS2V5ViRjbGFzc4BugGmAAoBw3xATABYAFwAYABkAGgAbA"
      @"BwAHQAeAB8AIAAQACEAIgAjACQAJQAmACcAKAApACoAKwAsAC0ALgAvADAAMQAyADMANAA1ADYANwA4ADkAOltOUy5v"
      @"YmplY3QuNlxOUy5vYmplY3QuMTZbTlMub2JqZWN0LjdbTlMub2JqZWN0LjhcTlMub2JqZWN0LjE3W05TLm9iamVjdC4"
      @"5XE5TLm9iamVjdC4xMFxOUy5vYmplY3QuMTFbTlMub2JqZWN0LjBcTlMub2JqZWN0LjEyW05TLm9iamVjdC4xW05TLm"
      @"9iamVjdC4yXE5TLm9iamVjdC4xM1tOUy5vYmplY3QuM1xOUy5vYmplY3QuMTRbTlMub2JqZWN0LjRbTlMub2JqZWN0L"
      @"jVcTlMub2JqZWN0LjE1gCmAXoAvgDSAY4A5gD6AQ4ADgEiAD4BogBSAToAZgFOAHoAkgFjXABAAPAA9AD4APwBAAEEA"
      @"QgBDAEQARQBGAEcASF8QGkdEVENPUlN0b3JlZEV2ZW50VGFyZ2V0S2V5XxAeR0RUQ09SU3RvcmVkRXZlbnREYXRhRnV"
      @"0dXJlS2V5XxAbR0RUQ09SU3RvcmVkRXZlbnRRb3NUaWVyS2V5XxAlR0RUQ09SU3RvcmVkRXZlbnRjdXN0b21CeXRlc1"
      @"BhcmFtc0tleV8QIUdEVENPUlN0b3JlZEV2ZW50Q2xvY2tTbmFwc2hvdEtleV8QHUdEVENPUlN0b3JlZEV2ZW50TWFwc"
      @"GluZ0lES2V5gA6ACoAEgAuAAIAMgAnTABAASgBLAEwARgBOXxAXR0RUQ09SRGF0YUZ1dHVyZURhdGFLZXlfEBpHRFRD"
      @"T1JEYXRhRnV0dXJlRmlsZVVSTEtleYAIgACABdMAUAAQAFEARgBTAFRXTlMuYmFzZVtOUy5yZWxhdGl2ZYAAgAeABl8"
      @"Q5GZpbGU6Ly8vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2ZWxvcGVyL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMD"
      @"BCMS05MDc0LTQ2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0YS9Db250YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyM"
      @"DcyQjQtNjYzQi00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0xpYnJhcnkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9l"
      @"dmVudC0xODI5Nzg1NzIwNjcyMjc5OTkwONIAVwBYAFkAWlokY2xhc3NuYW1lWCRjbGFzc2VzVU5TVVJMogBZAFtYTlN"
      @"PYmplY3TSAFcAWABdAF5fEBBHRFRDT1JEYXRhRnV0dXJlogBfAFtfEBBHRFRDT1JEYXRhRnV0dXJlVDEwMTgRA+gQAd"
      @"UAEABkAGUAZgBnAGgAaQBqAGsAbF8QFUdEVENPUkNsb2NrVGltZU1pbGxpc18QEUdEVENPUkNsb2NrVXB0aW1lXxAgR"
      @"0RUQ09SQ2xvY2tUaW1lem9uZU9mZnNldFNlY29uZHNfEBlHRFRDT1JDbG9ja0tlcm5lbEJvb3RUaW1lgA0TAAABcEWS"
      @"uikTAAACb3DqLb8T////////j4ATAAWcIFQ9BZLSAFcAWABuAG9bR0RUQ09SQ2xvY2uiAHAAW1tHRFRDT1JDbG9ja9I"
      @"AVwBYAHIAc18QEUdEVENPUlN0b3JlZEV2ZW50ogB0AFtfEBFHRFRDT1JTdG9yZWRFdmVudNcAEAA8AD0APgA/AEAAQQ"
      @"BCAEMAeABFAEYAewBIgA6ACoAQgAuAAIATgAnTABAASgBLAEwARgCAgAiAAIAR0wBQABAAUQBGAFMAhIAAgAeAEl8Q5"
      @"GZpbGU6Ly8vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2ZWxvcGVyL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMDBC"
      @"MS05MDc0LTQ2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0YS9Db250YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyMDc"
      @"yQjQtNjYzQi00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0xpYnJhcnkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9ldm"
      @"VudC0xODI5NzcwODE2NDQwNDM0OTE4MdUAEABkAGUAZgBnAGgAiACJAGsAbIANEwAAAXBFkrrLEwAAAm9w7KYU1wAQA"
      @"DwAPQA+AD8AQABBAEIAQwCNAEUARgCQAEiADoAKgBWAC4AAgBiACdMAEABKAEsATABGAJWACIAAgBbTAFAAEABRAEYA"
      @"UwCZgACAB4AXXxDkZmlsZTovLy9Vc2Vycy9oYW5leW0vTGlicmFyeS9EZXZlbG9wZXIvQ29yZVNpbXVsYXRvci9EZXZ"
      @"pY2VzLzdDRkMwMEIxLTkwNzQtNDY0OC1BNEIwLUI3OTRGRjNFQzY5MS9kYXRhL0NvbnRhaW5lcnMvRGF0YS9BcHBsaW"
      @"NhdGlvbi84RTIwNzJCNC02NjNCLTQ1N0UtOUZBQy1GNUFBQjAwNkFGRkEvTGlicmFyeS9DYWNoZXMvZ29vZ2xlLXNka"
      @"3MtZXZlbnRzL2V2ZW50LTE4Mjk1OTM1ODIwNjI5NzUxODU41QAQAGQAZQBmAGcAaACdAJ4AawBsgA0TAAABcEWSu14T"
      @"AAACb3Du5R7XABAAPAA9AD4APwBAAEEAQgBDAKIARQBGAKUASIAOgAqAGoALgACAHYAJ0wAQAEoASwBMAEYAqoAIgAC"
      @"AG9MAUAAQAFEARgBTAK6AAIAHgBxfEORmaWxlOi8vL1VzZXJzL2hhbmV5bS9MaWJyYXJ5L0RldmVsb3Blci9Db3JlU2"
      @"ltdWxhdG9yL0RldmljZXMvN0NGQzAwQjEtOTA3NC00NjQ4LUE0QjAtQjc5NEZGM0VDNjkxL2RhdGEvQ29udGFpbmVyc"
      @"y9EYXRhL0FwcGxpY2F0aW9uLzhFMjA3MkI0LTY2M0ItNDU3RS05RkFDLUY1QUFCMDA2QUZGQS9MaWJyYXJ5L0NhY2hl"
      @"cy9nb29nbGUtc2Rrcy1ldmVudHMvZXZlbnQtMTgyOTY5NjUyNDM0ODIxNTA3NDPVABAAZABlAGYAZwBoALIAswBrAGy"
      @"ADRMAAAFwRZK8FhMAAAJvcPGzA9cAEAA8AD0APgA/AEAAQQBCAEMAtwC4AEYAugBIgA6ACoAfgCKAAIAjgAnTABAASg"
      @"BLAEwARgC/gAiAAIAg0wBQABAAUQBGAFMAw4AAgAeAIV8Q5GZpbGU6Ly8vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2Z"
      @"WxvcGVyL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMDBCMS05MDc0LTQ2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0"
      @"YS9Db250YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyMDcyQjQtNjYzQi00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0x"
      @"pYnJhcnkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9ldmVudC0xODI5OTgzMTA3OTY1MDA2NDQwMBAD1QAQAGQAZQ"
      @"BmAGcAaADIAMkAawBsgA0TAAABcEWSveMTAAACb3D4vMfXABAAPAA9AD4APwBAAEEAQgBDAM0AuABGANAASIAOgAqAJ"
      @"YAigACAKIAJ0wAQAEoASwBMAEYA1YAIgACAJtMAUAAQAFEARgBTANmAAIAHgCdfEORmaWxlOi8vL1VzZXJzL2hhbmV5"
      @"bS9MaWJyYXJ5L0RldmVsb3Blci9Db3JlU2ltdWxhdG9yL0RldmljZXMvN0NGQzAwQjEtOTA3NC00NjQ4LUE0QjAtQjc"
      @"5NEZGM0VDNjkxL2RhdGEvQ29udGFpbmVycy9EYXRhL0FwcGxpY2F0aW9uLzhFMjA3MkI0LTY2M0ItNDU3RS05RkFDLU"
      @"Y1QUFCMDA2QUZGQS9MaWJyYXJ5L0NhY2hlcy9nb29nbGUtc2Rrcy1ldmVudHMvZXZlbnQtMTgyOTg2ODA3Njk5NzU4M"
      @"DUxMjHVABAAZABlAGYAZwBoAN0A3gBrAGyADRMAAAFwRZK+lhMAAAJvcPt089cAEAA8AD0APgA/AEAAQQBCAOEA4gC4"
      @"AEYA5QBIgA6ALYAqgCKAAIAugAnTABAASgBLAEwARgDqgAiAAIAr0wBQABAAUQBGAFMA7oAAgAeALF8Q5GZpbGU6Ly8"
      @"vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2ZWxvcGVyL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMDBCMS05MDc0LT"
      @"Q2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0YS9Db250YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyMDcyQjQtNjYzQ"
      @"i00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0xpYnJhcnkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9ldmVudC0xODMw"
      @"MDUyNTEyMjAxMDQxNTY5NRED6dUAEABkAGUAZgBnAGgA8wD0AGsAbIANEwAAAXBFksI/EwAAAm9xCcJF1wAQADwAPQA"
      @"+AD8AQABBAEIA4QD4ALgARgD7AEiADoAtgDCAIoAAgDOACdMAEABKAEsATABGAQCACIAAgDHTAFAAEABRAEYAUwEEgA"
      @"CAB4AyXxDkZmlsZTovLy9Vc2Vycy9oYW5leW0vTGlicmFyeS9EZXZlbG9wZXIvQ29yZVNpbXVsYXRvci9EZXZpY2VzL"
      @"zdDRkMwMEIxLTkwNzQtNDY0OC1BNEIwLUI3OTRGRjNFQzY5MS9kYXRhL0NvbnRhaW5lcnMvRGF0YS9BcHBsaWNhdGlv"
      @"bi84RTIwNzJCNC02NjNCLTQ1N0UtOUZBQy1GNUFBQjAwNkFGRkEvTGlicmFyeS9DYWNoZXMvZ29vZ2xlLXNka3MtZXZ"
      @"lbnRzL2V2ZW50LTE4Mjg1ODc4MDYzMDU2ODM3MjUw1QAQAGQAZQBmAGcAaAEIAQkAawBsgA0TAAABcEWSw8MTAAACb3"
      @"EPrWTXABAAPAA9AD4APwBAAEEAQgDhAQ0AuABGARAASIAOgC2ANYAigACAOIAJ0wAQAEoASwBMAEYBFYAIgACANtMAU"
      @"AAQAFEARgBTARmAAIAHgDdfEORmaWxlOi8vL1VzZXJzL2hhbmV5bS9MaWJyYXJ5L0RldmVsb3Blci9Db3JlU2ltdWxh"
      @"dG9yL0RldmljZXMvN0NGQzAwQjEtOTA3NC00NjQ4LUE0QjAtQjc5NEZGM0VDNjkxL2RhdGEvQ29udGFpbmVycy9EYXR"
      @"hL0FwcGxpY2F0aW9uLzhFMjA3MkI0LTY2M0ItNDU3RS05RkFDLUY1QUFCMDA2QUZGQS9MaWJyYXJ5L0NhY2hlcy9nb2"
      @"9nbGUtc2Rrcy1ldmVudHMvZXZlbnQtMTgyODY0MTI4Njg1OTcwMzcwNzDVABAAZABlAGYAZwBoAR0BHgBrAGyADRMAA"
      @"AFwRZLElRMAAAJvcRLh3tcAEAA8AD0APgA/AEAAQQBCAOEBIgBFAEYBJQBIgA6ALYA6gAuAAIA9gAnTABAASgBLAEwA"
      @"RgEqgAiAAIA70wBQABAAUQBGAFMBLoAAgAeAPF8Q5GZpbGU6Ly8vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2ZWxvcGV"
      @"yL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMDBCMS05MDc0LTQ2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0YS9Db2"
      @"50YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyMDcyQjQtNjYzQi00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0xpYnJhc"
      @"nkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9ldmVudC0xODI4NTM5MTg3NjI3NTA4Mjk1MdUAEABkAGUAZgBnAGgB"
      @"MgEzAGsAbIANEwAAAXBFksZ7EwAAAm9xGktv1wAQADwAPQA+AD8AQABBAEIA4QE3AEUARgE6AEiADoAtgD+AC4AAgEK"
      @"ACdMAEABKAEsATABGAT+ACIAAgEDTAFAAEABRAEYAUwFDgACAB4BBXxDkZmlsZTovLy9Vc2Vycy9oYW5leW0vTGlicm"
      @"FyeS9EZXZlbG9wZXIvQ29yZVNpbXVsYXRvci9EZXZpY2VzLzdDRkMwMEIxLTkwNzQtNDY0OC1BNEIwLUI3OTRGRjNFQ"
      @"zY5MS9kYXRhL0NvbnRhaW5lcnMvRGF0YS9BcHBsaWNhdGlvbi84RTIwNzJCNC02NjNCLTQ1N0UtOUZBQy1GNUFBQjAw"
      @"NkFGRkEvTGlicmFyeS9DYWNoZXMvZ29vZ2xlLXNka3MtZXZlbnRzL2V2ZW50LTE4Mjg4MDcyODk3NDM3NDg0MDYy1QA"
      @"QAGQAZQBmAGcAaAFHAUgAawBsgA0TAAABcEWSxxwTAAACb3EcwoHXABAAPAA9AD4APwBAAEEAQgDhAUwARQBGAU8ASI"
      @"AOgC2ARIALgACAR4AJ0wAQAEoASwBMAEYBVIAIgACARdMAUAAQAFEARgBTAViAAIAHgEZfEORmaWxlOi8vL1VzZXJzL"
      @"2hhbmV5bS9MaWJyYXJ5L0RldmVsb3Blci9Db3JlU2ltdWxhdG9yL0RldmljZXMvN0NGQzAwQjEtOTA3NC00NjQ4LUE0"
      @"QjAtQjc5NEZGM0VDNjkxL2RhdGEvQ29udGFpbmVycy9EYXRhL0FwcGxpY2F0aW9uLzhFMjA3MkI0LTY2M0ItNDU3RS0"
      @"5RkFDLUY1QUFCMDA2QUZGQS9MaWJyYXJ5L0NhY2hlcy9nb29nbGUtc2Rrcy1ldmVudHMvZXZlbnQtMTgyODkwNDg0ND"
      @"AxMzk0MDIwNDbVABAAZABlAGYAZwBoAVwBXQBrAGyADRMAAAFwRZLHuBMAAAJvcR8jBdcAEAA8AD0APgA/AEAAQQBCA"
      @"OEBYQFiAEYBZABIgA6ALYBJgEyAAIBNgAnTABAASgBLAEwARgFpgAiAAIBK0wBQABAAUQBGAFMBbYAAgAeAS18Q5GZp"
      @"bGU6Ly8vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2ZWxvcGVyL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMDBCMS0"
      @"5MDc0LTQ2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0YS9Db250YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyMDcyQj"
      @"QtNjYzQi00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0xpYnJhcnkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9ldmVud"
      @"C0xODI5MDU2NDQ2MDYyMzE0NDA2NRAF1QAQAGQAZQBmAGcAaAFyAXMAawBsgA0TAAABcEWSydcTAAACb3EnbeLXABAA"
      @"PAA9AD4APwBAAEEAQgDhAXcBYgBGAXoASIAOgC2AT4BMgACAUoAJ0wAQAEoASwBMAEYBf4AIgACAUNMAUAAQAFEARgB"
      @"TAYOAAIAHgFFfEORmaWxlOi8vL1VzZXJzL2hhbmV5bS9MaWJyYXJ5L0RldmVsb3Blci9Db3JlU2ltdWxhdG9yL0Rldm"
      @"ljZXMvN0NGQzAwQjEtOTA3NC00NjQ4LUE0QjAtQjc5NEZGM0VDNjkxL2RhdGEvQ29udGFpbmVycy9EYXRhL0FwcGxpY"
      @"2F0aW9uLzhFMjA3MkI0LTY2M0ItNDU3RS05RkFDLUY1QUFCMDA2QUZGQS9MaWJyYXJ5L0NhY2hlcy9nb29nbGUtc2Rr"
      @"cy1ldmVudHMvZXZlbnQtMTgyOTAzMzI5MDkwMzM5NDQ3ODLVABAAZABlAGYAZwBoAYcBiABrAGyADRMAAAFwRZLKcRM"
      @"AAAJvcSnE+9cAEAA8AD0APgA/AEAAQQBCAOEBjAFiAEYBjwBIgA6ALYBUgEyAAIBXgAnTABAASgBLAEwARgGUgAiAAI"
      @"BV0wBQABAAUQBGAFMBmIAAgAeAVl8Q5GZpbGU6Ly8vVXNlcnMvaGFuZXltL0xpYnJhcnkvRGV2ZWxvcGVyL0NvcmVTa"
      @"W11bGF0b3IvRGV2aWNlcy83Q0ZDMDBCMS05MDc0LTQ2NDgtQTRCMC1CNzk0RkYzRUM2OTEvZGF0YS9Db250YWluZXJz"
      @"L0RhdGEvQXBwbGljYXRpb24vOEUyMDcyQjQtNjYzQi00NTdFLTlGQUMtRjVBQUIwMDZBRkZBL0xpYnJhcnkvQ2FjaGV"
      @"zL2dvb2dsZS1zZGtzLWV2ZW50cy9ldmVudC0xODI5MDg3MzY1MzgwODczNjM4NNUAEABkAGUAZgBnAGgBnAGdAGsAbI"
      @"ANEwAAAXBFkssiEwAAAm9xLHlG1wAQADwAPQA+AD8AQABBAEIA4QGhAaIARgGkAEiADoAtgFmAXIAAgF2ACdMAEABKA"
      @"EsATABGAamACIAAgFrTAFAAEABRAEYAUwGtgACAB4BbXxDkZmlsZTovLy9Vc2Vycy9oYW5leW0vTGlicmFyeS9EZXZl"
      @"bG9wZXIvQ29yZVNpbXVsYXRvci9EZXZpY2VzLzdDRkMwMEIxLTkwNzQtNDY0OC1BNEIwLUI3OTRGRjNFQzY5MS9kYXR"
      @"hL0NvbnRhaW5lcnMvRGF0YS9BcHBsaWNhdGlvbi84RTIwNzJCNC02NjNCLTQ1N0UtOUZBQy1GNUFBQjAwNkFGRkEvTG"
      @"licmFyeS9DYWNoZXMvZ29vZ2xlLXNka3MtZXZlbnRzL2V2ZW50LTE4MjkwMTg5OTgwODEwODcxNjk4EALVABAAZABlA"
      @"GYAZwBoAbIBswBrAGyADRMAAAFwRZLMtRMAAAJvcTKfNtcAEAA8AD0APgA/AEAAQQBCAOEBtwGiAEYBugBIgA6ALYBf"
      @"gFyAAIBigAnTABAASgBLAEwARgG/gAiAAIBg0wBQABAAUQBGAFMBw4AAgAeAYV8Q5GZpbGU6Ly8vVXNlcnMvaGFuZXl"
      @"tL0xpYnJhcnkvRGV2ZWxvcGVyL0NvcmVTaW11bGF0b3IvRGV2aWNlcy83Q0ZDMDBCMS05MDc0LTQ2NDgtQTRCMC1CNz"
      @"k0RkYzRUM2OTEvZGF0YS9Db250YWluZXJzL0RhdGEvQXBwbGljYXRpb24vOEUyMDcyQjQtNjYzQi00NTdFLTlGQUMtR"
      @"jVBQUIwMDZBRkZBL0xpYnJhcnkvQ2FjaGVzL2dvb2dsZS1zZGtzLWV2ZW50cy9ldmVudC0xODI5MzA1NjUzNjM1MjA0"
      @"NDYxOdUAEABkAGUAZgBnAGgBxwHIAGsAbIANEwAAAXBFks2BEwAAAm9xNbwL1wAQADwAPQA+AD8AQABBAEIA4QHMAaI"
      @"ARgHPAEiADoAtgGSAXIAAgGeACdMAEABKAEsATABGAdSACIAAgGXTAFAAEABRAEYAUwHYgACAB4BmXxDkZmlsZTovLy"
      @"9Vc2Vycy9oYW5leW0vTGlicmFyeS9EZXZlbG9wZXIvQ29yZVNpbXVsYXRvci9EZXZpY2VzLzdDRkMwMEIxLTkwNzQtN"
      @"DY0OC1BNEIwLUI3OTRGRjNFQzY5MS9kYXRhL0NvbnRhaW5lcnMvRGF0YS9BcHBsaWNhdGlvbi84RTIwNzJCNC02NjNC"
      @"LTQ1N0UtOUZBQy1GNUFBQjAwNkFGRkEvTGlicmFyeS9DYWNoZXMvZ29vZ2xlLXNka3MtZXZlbnRzL2V2ZW50LTE4Mjk"
      @"zNDI4OTExMjU2MzE1MjY21QAQAGQAZQBmAGcAaAHcAd0AawBsgA0TAAABcEWSziwTAAACb3E4V7/SAFcAWAHfAeBfEB"
      @"NOU011dGFibGVPcmRlcmVkU2V0owHhAeIAW18QE05TTXV0YWJsZU9yZGVyZWRTZXRcTlNPcmRlcmVkU2V00wHkAeUAE"
      @"AHmAekB7FdOUy5rZXlzWk5TLm9iamVjdHOiAEMA4YAKgC2iAeoB64BqgGyAbdIB5QAQAe4B9aYANAA4ADAAMgA2ADmA"
      @"FIAegAOAD4AZgCSAa9IAVwBYAfcB+FxOU011dGFibGVTZXSjAfkB+gBbXE5TTXV0YWJsZVNldFVOU1NldNIB5QAQAfw"
      @"B9awAOgApADUALgAvACwANwAoAC0AKwAqADGAWIBegE6APoBDgGOAU4ApgDmANIAvgEiAa9IAVwBYAgsCDF8QE05TTX"
      @"V0YWJsZURpY3Rpb25hcnmjAg0CDgBbXxATTlNNdXRhYmxlRGljdGlvbmFyeVxOU0RpY3Rpb25hcnnRABACEIBv0gBXA"
      @"FgCEgITXxAXR0RUQ09SVXBsb2FkQ29vcmRpbmF0b3KiAhQAW18QF0dEVENPUlVwbG9hZENvb3JkaW5hdG9y0gBXAFgC"
      @"FgIXXUdEVENPUlN0b3JhZ2WiAhgAW11HRFRDT1JTdG9yYWdlAAgAGQAiACwAMQA6AD8AUQBWAFsAXQFCAUgBWQF9AaA"
      @"BvwHGAcgBygHMAc4CHQIpAjYCQgJOAlsCZwJ0AoECjQKaAqYCsgK/AssC2ALkAvAC/QL/AwEDAwMFAwcDCQMLAw0DDw"
      @"MRAxMDFQMXAxkDGwMdAx8DIQMjA0ADXQN+A5wDxAPoBAgECgQMBA4EEAQSBBQEFgQjBD0EWgRcBF4EYARtBHUEgQSDB"
      @"IUEhwVuBXcFggWLBZEFlgWfBagFuwXABdMF2AXbBd0F8gYKBh4GQQZdBl8GaAZxBnoGgwaMBpgGnQapBrIGxgbLBt8G"
      @"/Ab+BwAHAgcEBwYHCAcKBxcHGQcbBx0HKgcsBy4HMAgXCCwILgg3CEAIXQhfCGEIYwhlCGcIaQhrCHgIegh8CH4Iiwi"
      @"NCI8IkQl4CY0JjwmYCaEJvgnACcIJxAnGCcgJygnMCdkJ2wndCd8J7AnuCfAJ8grZCu4K8Ar5CwILHwshCyMLJQsnCy"
      @"kLKwstCzoLPAs+C0ALTQtPC1ELUww6DDwMUQxTDFwMZQyCDIQMhgyIDIoMjAyODJAMnQyfDKEMowywDLIMtAy2DZ0Ns"
      @"g20Db0Nxg3jDeUN5w3pDesN7Q3vDfEN/g4ADgIOBA4RDhMOFQ4XDv4PAQ8WDxgPIQ8qD0cPSQ9LD00PTw9RD1MPVQ9i"
      @"D2QPZg9oD3UPdw95D3sQYhB3EHkQghCLEKgQqhCsEK4QsBCyELQQthDDEMUQxxDJENYQ2BDaENwRwxHYEdoR4xHsEgk"
      @"SCxINEg8SERITEhUSFxIkEiYSKBIqEjcSORI7Ej0TJBM5EzsTRBNNE2oTbBNuE3ATchN0E3YTeBOFE4cTiROLE5gTmh"
      @"OcE54UhRSaFJwUpRSuFMsUzRTPFNEU0xTVFNcU2RTmFOgU6hTsFPkU+xT9FP8V5hX7Ff0WBhYPFiwWLhYwFjIWNBY2F"
      @"jgWOhZHFkkWSxZNFloWXBZeFmAXRxdJF14XYBdpF3IXjxeRF5MXlReXF5kXmxedF6oXrBeuF7AXvRe/F8EXwxiqGL8Y"
      @"wRjKGNMY8BjyGPQY9hj4GPoY/Bj+GQsZDRkPGREZHhkgGSIZJBoLGiAaIhorGjQaURpTGlUaVxpZGlsaXRpfGmwabhp"
      @"wGnIafxqBGoMahRtsG24bgxuFG44blxu0G7YbuBu6G7wbvhvAG8IbzxvRG9Mb1RviG+Qb5hvoHM8c5BzmHO8c+B0VHR"
      @"cdGR0bHR0dHx0hHSMdMB0yHTQdNh1DHUUdRx1JHjAeRR5HHlAeWR5iHngefx6VHqIerx63HsIexx7JHsse0B7SHtQe1"
      @"h7fHuwe7h7wHvIe9B72Hvge+h8DHxAfFx8kHyofMx9MH04fUB9SH1QfVh9YH1ofXB9eH2AfYh9kH2Yfbx+FH4wfoh+v"
      @"H7Qfth+/H9kf3h/4IAEgDyAUAAAAAAAAAgIAAAAAAAACGQAAAAAAAAAAAAAAAAAAICI=";

  NSData *v1ArchiveData = [[NSData alloc] initWithBase64EncodedString:base64EncodedArchive
                                                              options:0];
  XCTAssertNotNil(v1ArchiveData);
  NSError *error;
  GDTCORFlatFileStorage *archiveStorage = (GDTCORFlatFileStorage *)GDTCORDecodeArchive(
      [GDTCORFlatFileStorage class], nil, v1ArchiveData, &error);
  XCTAssertNil(error);
  XCTAssertNotNil(archiveStorage);
  XCTAssertEqual(archiveStorage.targetToEventSet[@(kGDTCORTargetCCT)].count, 6);
  XCTAssertEqual(archiveStorage.targetToEventSet[@(kGDTCORTargetFLL)].count, 12);
  XCTAssertEqual(archiveStorage.storedEvents.count, 18);
  XCTAssertNotNil(archiveStorage.uploadCoordinator);
}

@end
