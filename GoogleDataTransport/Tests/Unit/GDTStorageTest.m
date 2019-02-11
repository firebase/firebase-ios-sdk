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

#import "GDTTestCase.h"

#import <GoogleDataTransport/GDTEvent.h>

#import "GDTEvent_Private.h"
#import "GDTRegistrar.h"
#import "GDTRegistrar_Private.h"
#import "GDTStorage.h"
#import "GDTStorage_Private.h"

#import "GDTTestPrioritizer.h"
#import "GDTTestUploader.h"

#import "GDTAssertHelper.h"
#import "GDTRegistrar+Testing.h"
#import "GDTStorage+Testing.h"
#import "GDTUploadCoordinatorFake.h"

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
  [GDTStorage sharedInstance].uploader = self.uploaderFake;
}

- (void)tearDown {
  [super tearDown];
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  self.testPrioritizer = nil;
  [[GDTRegistrar sharedInstance] reset];
  [[GDTStorage sharedInstance] reset];
  [GDTStorage sharedInstance].uploader = [GDTUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDTStorage sharedInstance], [GDTStorage sharedInstance]);
}

/** Tests storing an event. */
- (void)testStoreEvent {
  NSUInteger eventHash;
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    eventHash = event.hash;
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTStorage sharedInstance].eventHashToFile.count, 1);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventHashSet[@(target)].count, 1);
    NSURL *eventFile = [GDTStorage sharedInstance].eventHashToFile[@(eventHash)];
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:eventFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests removing an event. */
- (void)testRemoveEvent {
  NSUInteger eventHash;
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    eventHash = event.hash;
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  __block NSURL *eventFile;
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    eventFile = [GDTStorage sharedInstance].eventHashToFile[@(eventHash)];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });
  [[GDTStorage sharedInstance] removeEvents:[NSSet setWithObject:@(eventHash)] target:@(target)];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTStorage sharedInstance].eventHashToFile.count, 0);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventHashSet[@(target)].count, 0);
  });
}

/** Tests removing a set of events. */
- (void)testRemoveEvents {
  GDTStorage *storage = [GDTStorage sharedInstance];
  NSUInteger event1Hash, event2Hash, event3Hash;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    event1Hash = event.hash;
    XCTAssertNoThrow([storage storeEvent:event]);

    event = [[GDTEvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    event2Hash = event.hash;
    XCTAssertNoThrow([storage storeEvent:event]);

    event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    event3Hash = event.hash;
    XCTAssertNoThrow([storage storeEvent:event]);
  }
  NSSet<NSNumber *> *eventHashSet =
      [NSSet setWithObjects:@(event1Hash), @(event2Hash), @(event3Hash), nil];
  NSSet<NSURL *> *eventFiles = [storage eventHashesToFiles:eventHashSet];
  [storage removeEvents:eventHashSet target:@(target)];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertNil(storage.eventHashToFile[@(event1Hash)]);
    XCTAssertNil(storage.eventHashToFile[@(event2Hash)]);
    XCTAssertNil(storage.eventHashToFile[@(event3Hash)]);
    XCTAssertEqual(storage.targetToEventHashSet[@(target)].count, 0);
    for (NSURL *eventFile in eventFiles) {
      XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    }
  });
}

/** Tests storing a few different events. */
- (void)testStoreMultipleEvents {
  NSUInteger event1Hash, event2Hash, event3Hash;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    event1Hash = event.hash;
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);

    event = [[GDTEvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    event2Hash = event.hash;
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);

    event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    event3Hash = event.hash;
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTStorage sharedInstance].eventHashToFile.count, 3);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventHashSet[@(target)].count, 3);

    NSURL *event1File = [GDTStorage sharedInstance].eventHashToFile[@(event1Hash)];
    XCTAssertNotNil(event1File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event1File.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:event1File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);

    NSURL *event2File = [GDTStorage sharedInstance].eventHashToFile[@(event2Hash)];
    XCTAssertNotNil(event2File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event2File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:event2File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);

    NSURL *event3File = [GDTStorage sharedInstance].eventHashToFile[@(event3Hash)];
    XCTAssertNotNil(event3File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:event3File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:event3File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests enforcing that a prioritizer does not retain an event in memory. */
- (void)testEventDeallocationIsEnforced {
  XCTestExpectation *errorExpectation = [self expectationWithDescription:@"event retain error"];
  [GDTAssertHelper setAssertionBlock:^{
    [errorExpectation fulfill];
  }];

  // event is referenced past -storeEvent, ensuring it's retained, which should assert.
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
  event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];

  // Store the event and wait for the expectation.
  [[GDTStorage sharedInstance] storeEvent:event];
  [self waitForExpectations:@[ errorExpectation ] timeout:5.0];

  NSURL *eventFile;
  eventFile = [GDTStorage sharedInstance].eventHashToFile[@(event.hash)];

  // This isn't strictly necessary because of the -waitForExpectations above.
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
  });

  // Ensure event was removed.
  NSNumber *eventHash = @(event.hash);
  [[GDTStorage sharedInstance] removeEvents:[NSSet setWithObject:eventHash] target:@(target)];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    XCTAssertEqual([GDTStorage sharedInstance].eventHashToFile.count, 0);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventHashSet[@(target)].count, 0);
  });
}

/** Tests encoding and decoding the storage singleton correctly. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDTStorage supportsSecureCoding]);
  GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
  event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  NSUInteger eventHash = event.hash;
  XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  event = nil;
  NSData *storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTStorage sharedInstance]];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([GDTStorage sharedInstance].eventHashToFile[@(eventHash)]);
  });
  [[GDTStorage sharedInstance] removeEvents:[NSSet setWithObject:@(eventHash)] target:@(target)];
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([GDTStorage sharedInstance].eventHashToFile[@(eventHash)]);
  });

  // TODO(mikehaney24): Ensure that the object created by alloc is discarded?
  [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
  XCTAssertNotNil([GDTStorage sharedInstance].eventHashToFile[@(eventHash)]);
}

/** Tests sending a fast priority event causes an upload attempt. */
- (void)testQoSTierFast {
  NSUInteger eventHash;
  // event is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    event.qosTier = GDTEventQoSFast;
    eventHash = event.hash;
    XCTAssertFalse(self.uploaderFake.forceUploadCalled);
    XCTAssertNoThrow([[GDTStorage sharedInstance] storeEvent:event]);
  }
  dispatch_sync([GDTStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
    XCTAssertEqual([GDTStorage sharedInstance].eventHashToFile.count, 1);
    XCTAssertEqual([GDTStorage sharedInstance].targetToEventHashSet[@(target)].count, 1);
    NSURL *eventFile = [GDTStorage sharedInstance].eventHashToFile[@(eventHash)];
    XCTAssertNotNil(eventFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:eventFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:eventFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the eventFile: %@", error);
  });
}

/** Tests convert a set of event hashes to a set of event file URLS. */
- (void)testEventHashesToFiles {
  GDTStorage *storage = [GDTStorage sharedInstance];
  NSUInteger event1Hash, event2Hash, event3Hash;

  // events are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTEvent *event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    event1Hash = event.hash;
    XCTAssertNoThrow([storage storeEvent:event]);

    event = [[GDTEvent alloc] initWithMappingID:@"100" target:target];
    event.dataObjectTransportBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    event2Hash = event.hash;
    XCTAssertNoThrow([storage storeEvent:event]);

    event = [[GDTEvent alloc] initWithMappingID:@"404" target:target];
    event.dataObjectTransportBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    event3Hash = event.hash;
    XCTAssertNoThrow([storage storeEvent:event]);
  }
  NSSet<NSNumber *> *eventHashSet =
      [NSSet setWithObjects:@(event1Hash), @(event2Hash), @(event3Hash), nil];
  NSSet<NSURL *> *eventFiles = [storage eventHashesToFiles:eventHashSet];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertEqual(eventFiles.count, 3);
    XCTAssertTrue([eventFiles containsObject:storage.eventHashToFile[@(event1Hash)]]);
    XCTAssertTrue([eventFiles containsObject:storage.eventHashToFile[@(event2Hash)]]);
    XCTAssertTrue([eventFiles containsObject:storage.eventHashToFile[@(event3Hash)]]);
  });
}

@end
