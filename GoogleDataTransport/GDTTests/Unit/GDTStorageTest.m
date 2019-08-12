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
#import <GoogleDataTransport/GDTStoredEvent.h>

#import "GDTLibrary/Private/GDTEvent_Private.h"
#import "GDTLibrary/Private/GDTRegistrar_Private.h"
#import "GDTLibrary/Private/GDTStorage.h"
#import "GDTLibrary/Private/GDTStorage_Private.h"
#import "GDTLibrary/Public/GDTRegistrar.h"

#import "GDTTests/Unit/Helpers/GDTAssertHelper.h"
#import "GDTTests/Unit/Helpers/GDTTestPrioritizer.h"
#import "GDTTests/Unit/Helpers/GDTTestUploader.h"

#import "GDTTests/Common/Fakes/GDTUploadCoordinatorFake.h"

#import "GDTTests/Common/Categories/GDTRegistrar+Testing.h"
#import "GDTTests/Common/Categories/GDTStorage+Testing.h"

static NSInteger target = 1337;

@interface GDTStorageTest : GDTTestCase

/** The test backend implementation. */
@property(nullable, nonatomic) GDTTestUploader *testBackend;

/** The test prioritizer implementation. */
@property(nullable, nonatomic) GDTTestPrioritizer *testPrioritizer;

/** The uploader fake. */
@property(nonatomic) GDTUploadCoordinatorFake *uploaderFake;

@end

@implementation GDTStorageTest

- (void)setUp {
  [super setUp];
  self.testBackend = [[GDTTestUploader alloc] init];
  self.testPrioritizer = [[GDTTestPrioritizer alloc] init];
  [[GDTRegistrar sharedInstance] registerUploader:_testBackend target:target];
  [[GDTRegistrar sharedInstance] registerPrioritizer:_testPrioritizer target:target];
  self.uploaderFake = [[GDTUploadCoordinatorFake alloc] init];
  [GDTStorage sharedInstance].uploadCoordinator = self.uploaderFake;
}

- (void)tearDown {
  [super tearDown];
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  self.testPrioritizer = nil;
  [[GDTRegistrar sharedInstance] reset];
  [[GDTStorage sharedInstance] reset];
  [GDTStorage sharedInstance].uploadCoordinator = [GDTUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDTStorage sharedInstance], [GDTStorage sharedInstance]);
}

/** Tests storing an event. */
- (void)testStoreEvent {
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 1);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventSet[@(target)].count, 1);
    NSURL *eventFile = [[GDTStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;
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
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  __block NSURL *eventFile;
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    eventFile = [[GDTStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });
  [[GDTStorage sharedInstance] removeEvents:[GDTStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventSet[@(target)].count, 0);
  });
}

/** Tests removing a set of events. */
- (void)testRemoveEvents {
  GDTStorage *storage = [GDTStorage sharedInstance];
  __block GDTStoredEvent *storedEvent1, *storedEvent2, *storedEvent3;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([storage storeEvent:event]);
    dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
      storedEvent1 = [storage.storedEvents lastObject];
    });

    event = [[GDTEvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([storage storeEvent:event]);
    dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
      storedEvent2 = [storage.storedEvents lastObject];
    });

    event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([storage storeEvent:event]);
    dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
      storedEvent3 = [storage.storedEvents lastObject];
    });
  }
  NSSet<GDTStoredEvent *> *eventSet =
      [NSSet setWithObjects:storedEvent1, storedEvent2, storedEvent3, nil];
  [storage removeEvents:eventSet];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertFalse([storage.storedEvents containsObject:storedEvent1]);
    XCTAssertFalse([storage.storedEvents containsObject:storedEvent2]);
    XCTAssertFalse([storage.storedEvents containsObject:storedEvent3]);
    XCTAssertEqual(storage.targetToEventSet[@(target)].count, 0);
    for (GDTStoredEvent *event in eventSet) {
      XCTAssertFalse(
          [[NSFileManager defaultManager] fileExistsAtPath:event.dataFuture.fileURL.path]);
    }
  });
}

/** Tests storing a few different events. */
- (void)testStoreMultipleEvents {
  __block GDTStoredEvent *storedEvent1, *storedEvent2, *storedEvent3;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
    dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
      storedEvent1 = [[GDTStorage sharedInstance].storedEvents lastObject];
    });

    event = [[GDTEvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
    dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
      storedEvent2 = [[GDTStorage sharedInstance].storedEvents lastObject];
    });

    event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
    dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
      storedEvent3 = [[GDTStorage sharedInstance].storedEvents lastObject];
    });
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 3);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventSet[@(target)].count, 3);

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
  __weak GDTEvent *weakEvent;
  GDTStoredEvent *storedEvent;
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    weakEvent = event;
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];

    // Store the event and wait for the expectation.
    [[GDTStorage sharedInstance] storeEvent:event];
    GDTDataFuture *dataFuture =
        [[GDTDataFuture alloc] initWithFileURL:[NSURL fileURLWithPath:@"/test"]];
    storedEvent = [event storedEventWithDataFuture:dataFuture];
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNil(weakEvent);
    XCTAssertNotNil(storedEvent);
  });

  NSURL *eventFile;
  eventFile = [[GDTStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;

  // This isn't strictly necessary because of the -waitForExpectations above.
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });

  // Ensure event was removed.
  [[GDTStorage sharedInstance] removeEvents:[GDTStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 0);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventSet[@(target)].count, 0);
  });
}

/** Tests encoding and decoding the storage singleton correctly. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDTStorage supportsSecureCoding]);
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
  event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  event = nil;
  NSData *storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTStorage sharedInstance]];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([[GDTStorage sharedInstance].storedEvents lastObject]);
  });
  [[GDTStorage sharedInstance] removeEvents:[GDTStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([[GDTStorage sharedInstance].storedEvents lastObject]);
  });

  GDTStorage *unarchivedStorage = [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
  XCTAssertNotNil([unarchivedStorage.storedEvents lastObject]);
}

/** Tests encoding and decoding the storage singleton when calling -sharedInstance. */
- (void)testNSSecureCodingWithSharedInstance {
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
  event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  event = nil;
  NSData *storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTStorage sharedInstance]];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([[GDTStorage sharedInstance].storedEvents lastObject]);
  });
  [[GDTStorage sharedInstance] removeEvents:[GDTStorage sharedInstance].storedEvents.set];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([[GDTStorage sharedInstance].storedEvents lastObject]);
  });

  GDTStorage *unarchivedStorage = [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
  XCTAssertNotNil([unarchivedStorage.storedEvents lastObject]);
}

/** Tests sending a fast priority event causes an upload attempt. */
- (void)testQoSTierFast {
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    event.qosTier = GDTEventQoSFast;
    XCTAssertFalse(self.uploaderFake.forceUploadCalled);
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
    XCTAssertEqual([GDTStorage sharedInstance].storedEvents.count, 1);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventSet[@(target)].count, 1);
    NSURL *eventFile = [[GDTStorage sharedInstance].storedEvents lastObject].dataFuture.fileURL;
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:eventFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

@end
