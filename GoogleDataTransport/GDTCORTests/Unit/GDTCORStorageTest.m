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
#import <GoogleDataTransport/GDTCORStoredEvent.h>

#import "GDTCORLibrary/Private/GDTCOREvent_Private.h"
#import "GDTCORLibrary/Private/GDTCORRegistrar_Private.h"
#import "GDTCORLibrary/Private/GDTCORStorage.h"
#import "GDTCORLibrary/Private/GDTCORStorage_Private.h"
#import "GDTCORLibrary/Public/GDTCORRegistrar.h"

#import "GDTCORTests/Unit/Helpers/GDTCORAssertHelper.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestPrioritizer.h"
#import "GDTCORTests/Unit/Helpers/GDTCORTestUploader.h"

#import "GDTCORTests/Common/Fakes/GDTCORUploadCoordinatorFake.h"

#import "GDTCORTests/Common/Categories/GDTCORRegistrar+Testing.h"
#import "GDTCORTests/Common/Categories/GDTCORStorage+Testing.h"

static NSInteger target = kGDTCORTargetCCT;

@interface GDTCORStorageTest : GDTCORTestCase

/** The test backend implementation. */
@property(nullable, nonatomic) GDTCORTestUploader *testBackend;

/** The test prioritizer implementation. */
@property(nullable, nonatomic) GDTCORTestPrioritizer *testPrioritizer;

/** The uploader fake. */
@property(nonatomic) GDTCORUploadCoordinatorFake *uploaderFake;

@end

@implementation GDTCORStorageTest

- (void)setUp {
  [super setUp];
  self.testBackend = [[GDTCORTestUploader alloc] init];
  self.testPrioritizer = [[GDTCORTestPrioritizer alloc] init];
  [[GDTCORRegistrar sharedInstance] registerUploader:_testBackend target:target];
  [[GDTCORRegistrar sharedInstance] registerPrioritizer:_testPrioritizer target:target];
  self.uploaderFake = [[GDTCORUploadCoordinatorFake alloc] init];
  [GDTCORStorage sharedInstance].uploadCoordinator = self.uploaderFake;
}

- (void)tearDown {
  [super tearDown];
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
                });
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  self.testPrioritizer = nil;
  [[GDTCORRegistrar sharedInstance] reset];
  [[GDTCORStorage sharedInstance] reset];
  [GDTCORStorage sharedInstance].uploadCoordinator = [GDTCORUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDTCORStorage sharedInstance], [GDTCORStorage sharedInstance]);
}

/** Tests storing an event. */
- (void)testStoreEvent {
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    event.clockSnapshot = [GDTCORClock snapshot];
    XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 1);
    XCTAssertEqual([GDTCORStorage sharedInstance].targetToEventSet[@(target)].count, 1);
    NSURL *eventFile = [[GDTCORStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:eventFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests removing an event. */
- (void)testRemoveEvent {
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    event.clockSnapshot = [GDTCORClock snapshot];
    XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
  }
  __block NSURL *eventFile;
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    eventFile = [[GDTCORStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });
  [[GDTCORStorage sharedInstance] removeEvents:[GDTCORStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 0);
    XCTAssertEqual([GDTCORStorage sharedInstance].targetToEventSet[@(target)].count, 0);
  });
}

/** Tests removing a set of events. */
- (void)testRemoveEvents {
  GDTCORStorage *storage = [GDTCORStorage sharedInstance];
  __block GDTCORStoredEvent *storedEvent1, *storedEvent2, *storedEvent3;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([storage storeEvent:event]);
    dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
      storedEvent1 = [storage.storedEvents lastObject];
    });

    event = [[GDTCOREvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([storage storeEvent:event]);
    dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
      storedEvent2 = [storage.storedEvents lastObject];
    });

    event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([storage storeEvent:event]);
    dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
      storedEvent3 = [storage.storedEvents lastObject];
    });
  }
  NSSet<GDTCORStoredEvent *> *eventSet =
      [NSSet setWithObjects:storedEvent1, storedEvent2, storedEvent3, nil];
  [storage removeEvents:eventSet];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertFalse([storage.storedEvents containsObject:storedEvent1]);
    XCTAssertFalse([storage.storedEvents containsObject:storedEvent2]);
    XCTAssertFalse([storage.storedEvents containsObject:storedEvent3]);
    XCTAssertEqual(storage.targetToEventSet[@(target)].count, 0);
    for (GDTCORStoredEvent *event in eventSet) {
      XCTAssertFalse(
          [[NSFileManager defaultManager] fileExistsAtPath:event.dataFuture.fileURL.path]);
    }
  });
}

/** Tests storing a few different events. */
- (void)testStoreMultipleEvents {
  __block GDTCORStoredEvent *storedEvent1, *storedEvent2, *storedEvent3;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
    dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
      storedEvent1 = [[GDTCORStorage sharedInstance].storedEvents lastObject];
    });

    event = [[GDTCOREvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
    dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
      storedEvent2 = [[GDTCORStorage sharedInstance].storedEvents lastObject];
    });

    event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
    dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
      storedEvent3 = [[GDTCORStorage sharedInstance].storedEvents lastObject];
    });
  }
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 3);
    XCTAssertEqual([GDTCORStorage sharedInstance].targetToEventSet[@(target)].count, 3);

    NSURL *event1File = storedEvent1.dataFuture.fileURL;
    XCTAssertNotNil(event1File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event1File.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:event1File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);

    NSURL *event2File = storedEvent2.dataFuture.fileURL;
    XCTAssertNotNil(event2File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event2File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:event2File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);

    NSURL *event3File = storedEvent3.dataFuture.fileURL;
    XCTAssertNotNil(event3File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event3File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:event3File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests enforcing that a prioritizer does not retain an event in memory. */
- (void)testEventDeallocationIsEnforced {
  __weak GDTCOREvent *weakEvent;
  GDTCORStoredEvent *storedEvent;
  @autoreleasepool {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    weakEvent = event;
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    event.clockSnapshot = [GDTCORClock snapshot];
    // Store the event and wait for the expectation.
    [[GDTCORStorage sharedInstance] storeEvent:event];
    GDTCORDataFuture *dataFuture =
        [[GDTCORDataFuture alloc] initWithFileURL:[NSURL fileURLWithPath:@"/test"]];
    storedEvent = [event storedEventWithDataFuture:dataFuture];
  }
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertNil(weakEvent);
    XCTAssertNotNil(storedEvent);
  });

  NSURL *eventFile;
  eventFile = [[GDTCORStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;

  // This isn't strictly necessary because of the -waitForExpectations above.
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });

  // Ensure event was removed.
  [[GDTCORStorage sharedInstance] removeEvents:[GDTCORStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 0);
    XCTAssertEqual([GDTCORStorage sharedInstance].targetToEventSet[@(target)].count, 0);
  });
}

/** Tests encoding and decoding the storage singleton correctly. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDTCORStorage supportsSecureCoding]);
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.clockSnapshot = [GDTCORClock snapshot];
  event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
  event = nil;
  __block NSData *storageData;
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
      storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTCORStorage sharedInstance]
                                          requiringSecureCoding:YES
                                                          error:nil];
    } else {
#if !TARGET_OS_MACCATALYST
      storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTCORStorage sharedInstance]];
#endif
    }
  });
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([[GDTCORStorage sharedInstance].storedEvents lastObject]);
  });
  [[GDTCORStorage sharedInstance] removeEvents:[GDTCORStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([[GDTCORStorage sharedInstance].storedEvents lastObject]);
  });
  GDTCORStorage *unarchivedStorage;
  NSError *error;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    unarchivedStorage = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTCORStorage class]
                                                          fromData:storageData
                                                             error:&error];
  } else {
#if !TARGET_OS_MACCATALYST
    unarchivedStorage = [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
#endif
  }
  XCTAssertNotNil([unarchivedStorage.storedEvents lastObject]);
}

/** Tests encoding and decoding the storage singleton when calling -sharedInstance. */
- (void)testNSSecureCodingWithSharedInstance {
  GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
  event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  event.clockSnapshot = [GDTCORClock snapshot];
  XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
  event = nil;
  __block NSData *storageData;
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
      storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTCORStorage sharedInstance]
                                          requiringSecureCoding:YES
                                                          error:nil];
    } else {
#if !TARGET_OS_MACCATALYST
      storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTCORStorage sharedInstance]];
#endif
    }
  });
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([[GDTCORStorage sharedInstance].storedEvents lastObject]);
  });
  [[GDTCORStorage sharedInstance] removeEvents:[GDTCORStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([[GDTCORStorage sharedInstance].storedEvents lastObject]);
  });
  GDTCORStorage *unarchivedStorage;
  if (@available(macOS 10.13, iOS 11.0, tvOS 11.0, *)) {
    unarchivedStorage = [NSKeyedUnarchiver unarchivedObjectOfClass:[GDTCORStorage class]
                                                          fromData:storageData
                                                             error:nil];
  } else {
#if !TARGET_OS_MACCATALYST
    unarchivedStorage = [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
#endif
  }
  XCTAssertNotNil([unarchivedStorage.storedEvents lastObject]);
}

/** Tests sending a fast priority event causes an upload attempt. */
- (void)testQoSTierFast {
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTCOREvent *event = [[GDTCOREvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    event.qosTier = GDTCOREventQoSFast;
    event.clockSnapshot = [GDTCORClock snapshot];
    XCTAssertFalse(self.uploaderFake.forceUploadCalled);
    XCTAssertNoThrow([[GDTCORStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTCORStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
    XCTAssertEqual([GDTCORStorage sharedInstance].storedEvents.count, 1);
    XCTAssertEqual([GDTCORStorage sharedInstance].targetToEventSet[@(target)].count, 1);
    NSURL *eventFile = [[GDTCORStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:eventFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

@end
