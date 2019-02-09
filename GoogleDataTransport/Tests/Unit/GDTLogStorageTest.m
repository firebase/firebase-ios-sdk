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

#import <GoogleDataTransport/GDTLogEvent.h>

#import "GDTLogEvent_Private.h"
#import "GDTLogStorage.h"
#import "GDTLogStorage_Private.h"
#import "GDTRegistrar.h"
#import "GDTRegistrar_Private.h"

#import "GDTTestPrioritizer.h"
#import "GDTTestUploader.h"

#import "GDTAssertHelper.h"
#import "GDTLogStorage+Testing.h"
#import "GDTRegistrar+Testing.h"
#import "GDTUploadCoordinatorFake.h"

static NSInteger logTarget = 1337;

@interface GDTLogStorageTest : GDTTestCase

/** The test backend implementation. */
@property(nullable, nonatomic) GDTTestUploader *testBackend;

/** The test prioritizer implementation. */
@property(nullable, nonatomic) GDTTestPrioritizer *testPrioritizer;

/** The uploader fake. */
@property(nonatomic) GDTUploadCoordinatorFake *uploaderFake;

@end

@implementation GDTLogStorageTest

- (void)setUp {
  [super setUp];
  self.testBackend = [[GDTTestUploader alloc] init];
  self.testPrioritizer = [[GDTTestPrioritizer alloc] init];
  [[GDTRegistrar sharedInstance] registerUploader:_testBackend logTarget:logTarget];
  [[GDTRegistrar sharedInstance] registerPrioritizer:_testPrioritizer logTarget:logTarget];
  self.uploaderFake = [[GDTUploadCoordinatorFake alloc] init];
  [GDTLogStorage sharedInstance].uploader = self.uploaderFake;
}

- (void)tearDown {
  [super tearDown];
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  self.testPrioritizer = nil;
  [[GDTRegistrar sharedInstance] reset];
  [[GDTLogStorage sharedInstance] reset];
  [GDTLogStorage sharedInstance].uploader = [GDTUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDTLogStorage sharedInstance], [GDTLogStorage sharedInstance]);
}

/** Tests storing a log. */
- (void)testStoreLog {
  NSUInteger logHash;
  // logEvent is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    logHash = logEvent.hash;
    XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);
  }
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 1);
    XCTAssertEqual([GDTLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 1);
    NSURL *logFile = [GDTLogStorage sharedInstance].logHashToLogFile[@(logHash)];
    XCTAssertNotNil(logFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:logFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);
  });
}

/** Tests removing a log. */
- (void)testRemoveLog {
  NSUInteger logHash;
  // logEvent is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    logHash = logEvent.hash;
    XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);
  }
  __block NSURL *logFile;
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    logFile = [GDTLogStorage sharedInstance].logHashToLogFile[@(logHash)];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
  });
  [[GDTLogStorage sharedInstance] removeLogs:[NSSet setWithObject:@(logHash)]
                                   logTarget:@(logTarget)];
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 0);
    XCTAssertEqual([GDTLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 0);
  });
}

/** Tests removing a set of logs */
- (void)testRemoveLogs {
  GDTLogStorage *storage = [GDTLogStorage sharedInstance];
  NSUInteger log1Hash, log2Hash, log3Hash;

  // logEvents are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    log1Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"100" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    log2Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    log3Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);
  }
  NSSet<NSNumber *> *logHashSet = [NSSet setWithObjects:@(log1Hash), @(log2Hash), @(log3Hash), nil];
  NSSet<NSURL *> *logFiles = [storage logHashesToFiles:logHashSet];
  [storage removeLogs:logHashSet logTarget:@(logTarget)];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertNil(storage.logHashToLogFile[@(log1Hash)]);
    XCTAssertNil(storage.logHashToLogFile[@(log2Hash)]);
    XCTAssertNil(storage.logHashToLogFile[@(log3Hash)]);
    XCTAssertEqual(storage.logTargetToLogHashSet[@(logTarget)].count, 0);
    for (NSURL *logFile in logFiles) {
      XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    }
  });
}

/** Tests storing a few different logs. */
- (void)testStoreMultipleLogs {
  NSUInteger log1Hash, log2Hash, log3Hash;

  // logEvents are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    log1Hash = logEvent.hash;
    XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);

    logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"100" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    log2Hash = logEvent.hash;
    XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);

    logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    log3Hash = logEvent.hash;
    XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);
  }
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 3);
    XCTAssertEqual([GDTLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 3);

    NSURL *log1File = [GDTLogStorage sharedInstance].logHashToLogFile[@(log1Hash)];
    XCTAssertNotNil(log1File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:log1File.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:log1File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);

    NSURL *log2File = [GDTLogStorage sharedInstance].logHashToLogFile[@(log2Hash)];
    XCTAssertNotNil(log2File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:log2File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:log2File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);

    NSURL *log3File = [GDTLogStorage sharedInstance].logHashToLogFile[@(log3Hash)];
    XCTAssertNotNil(log3File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:log3File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:log3File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);
  });
}

/** Tests enforcing that a log prioritizer does not retain a log in memory. */
- (void)testLogEventDeallocationIsEnforced {
  XCTestExpectation *errorExpectation = [self expectationWithDescription:@"log retain error"];
  [GDTAssertHelper setAssertionBlock:^{
    [errorExpectation fulfill];
  }];

  // logEvent is referenced past -storeLog, ensuring it's retained, which should assert.
  GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
  logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];

  // Store the log and wait for the expectation.
  [[GDTLogStorage sharedInstance] storeLog:logEvent];
  [self waitForExpectations:@[ errorExpectation ] timeout:5.0];

  NSURL *logFile;
  logFile = [GDTLogStorage sharedInstance].logHashToLogFile[@(logEvent.hash)];

  // This isn't strictly necessary because of the -waitForExpectations above.
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
  });

  // Ensure log was removed.
  NSNumber *logHash = @(logEvent.hash);
  [[GDTLogStorage sharedInstance] removeLogs:[NSSet setWithObject:logHash] logTarget:@(logTarget)];
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 0);
    XCTAssertEqual([GDTLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 0);
  });
}

/** Tests encoding and decoding the storage singleton correctly. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDTLogStorage supportsSecureCoding]);
  GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
  logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  NSUInteger logHash = logEvent.hash;
  XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);
  logEvent = nil;
  NSData *storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDTLogStorage sharedInstance]];
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([GDTLogStorage sharedInstance].logHashToLogFile[@(logHash)]);
  });
  [[GDTLogStorage sharedInstance] removeLogs:[NSSet setWithObject:@(logHash)]
                                   logTarget:@(logTarget)];
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([GDTLogStorage sharedInstance].logHashToLogFile[@(logHash)]);
  });

  // TODO(mikehaney24): Ensure that the object created by alloc is discarded?
  [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
  XCTAssertNotNil([GDTLogStorage sharedInstance].logHashToLogFile[@(logHash)]);
}

/** Tests logging a fast log causes an upload attempt. */
- (void)testQoSTierFast {
  NSUInteger logHash;
  // logEvent is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    logEvent.qosTier = GDTLogQoSFast;
    logHash = logEvent.hash;
    XCTAssertFalse(self.uploaderFake.forceUploadCalled);
    XCTAssertNoThrow([[GDTLogStorage sharedInstance] storeLog:logEvent]);
  }
  dispatch_sync([GDTLogStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
    XCTAssertEqual([GDTLogStorage sharedInstance].logHashToLogFile.count, 1);
    XCTAssertEqual([GDTLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 1);
    NSURL *logFile = [GDTLogStorage sharedInstance].logHashToLogFile[@(logHash)];
    XCTAssertNotNil(logFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:logFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);
  });
}

/** Tests convert a set of log hashes to a set of log file URLS. */
- (void)testLogHashesToFiles {
  GDTLogStorage *storage = [GDTLogStorage sharedInstance];
  NSUInteger log1Hash, log2Hash, log3Hash;

  // logEvents are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDTLogEvent *logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    log1Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"100" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    log2Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDTLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    log3Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);
  }
  NSSet<NSNumber *> *logHashSet = [NSSet setWithObjects:@(log1Hash), @(log2Hash), @(log3Hash), nil];
  NSSet<NSURL *> *logFiles = [storage logHashesToFiles:logHashSet];
  dispatch_sync(storage.storageQueue, ^{
    XCTAssertEqual(logFiles.count, 3);
    XCTAssertTrue([logFiles containsObject:storage.logHashToLogFile[@(log1Hash)]]);
    XCTAssertTrue([logFiles containsObject:storage.logHashToLogFile[@(log2Hash)]]);
    XCTAssertTrue([logFiles containsObject:storage.logHashToLogFile[@(log3Hash)]]);
  });
}

@end
