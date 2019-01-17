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

#import "GDLTestCase.h"

#import <GoogleDataLogger/GDLLogEvent.h>

#import "GDLLogEvent_Private.h"
#import "GDLLogStorage.h"
#import "GDLLogStorage_Private.h"
#import "GDLRegistrar.h"
#import "GDLRegistrar_Private.h"

#import "GDLTestPrioritizer.h"
#import "GDLTestUploader.h"

#import "GDLAssertHelper.h"
#import "GDLLogStorage+Testing.h"
#import "GDLRegistrar+Testing.h"
#import "GDLUploadCoordinatorFake.h"

static NSInteger logTarget = 1337;

@interface GDLLogStorageTest : GDLTestCase

/** The test backend implementation. */
@property(nullable, nonatomic) GDLTestUploader *testBackend;

/** The test prioritizer implementation. */
@property(nullable, nonatomic) GDLTestPrioritizer *testPrioritizer;

/** The uploader fake. */
@property(nonatomic) GDLUploadCoordinatorFake *uploaderFake;

@end

@implementation GDLLogStorageTest

- (void)setUp {
  [super setUp];
  self.testBackend = [[GDLTestUploader alloc] init];
  self.testPrioritizer = [[GDLTestPrioritizer alloc] init];
  [[GDLRegistrar sharedInstance] registerBackend:_testBackend forLogTarget:logTarget];
  [[GDLRegistrar sharedInstance] registerLogPrioritizer:_testPrioritizer forLogTarget:logTarget];
  self.uploaderFake = [[GDLUploadCoordinatorFake alloc] init];
  [GDLLogStorage sharedInstance].uploader = self.uploaderFake;
}

- (void)tearDown {
  [super tearDown];
  // Destroy these objects before the next test begins.
  self.testBackend = nil;
  self.testPrioritizer = nil;
  [[GDLRegistrar sharedInstance] reset];
  [[GDLLogStorage sharedInstance] reset];
  [GDLLogStorage sharedInstance].uploader = [GDLUploadCoordinator sharedInstance];
  self.uploaderFake = nil;
}

/** Tests the singleton pattern. */
- (void)testInit {
  XCTAssertEqual([GDLLogStorage sharedInstance], [GDLLogStorage sharedInstance]);
}

/** Tests storing a log. */
- (void)testStoreLog {
  NSUInteger logHash;
  // logEvent is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    logHash = logEvent.hash;
    XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);
  }
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDLLogStorage sharedInstance].logHashToLogFile.count, 1);
    XCTAssertEqual([GDLLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 1);
    NSURL *logFile = [GDLLogStorage sharedInstance].logHashToLogFile[@(logHash)];
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
    GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    logHash = logEvent.hash;
    XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);
  }
  __block NSURL *logFile;
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    logFile = [GDLLogStorage sharedInstance].logHashToLogFile[@(logHash)];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
  });
  [[GDLLogStorage sharedInstance] removeLog:@(logHash) logTarget:@(logTarget)];
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    XCTAssertEqual([GDLLogStorage sharedInstance].logHashToLogFile.count, 0);
    XCTAssertEqual([GDLLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 0);
  });
}

/** Tests removing a set of logs */
- (void)testRemoveLogs {
  GDLLogStorage *storage = [GDLLogStorage sharedInstance];
  NSUInteger log1Hash, log2Hash, log3Hash;

  // logEvents are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    log1Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"100" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    log2Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
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
    GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    log1Hash = logEvent.hash;
    XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);

    logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"100" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    log2Hash = logEvent.hash;
    XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);

    logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString3" dataUsingEncoding:NSUTF8StringEncoding];
    log3Hash = logEvent.hash;
    XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);
  }
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertEqual([GDLLogStorage sharedInstance].logHashToLogFile.count, 3);
    XCTAssertEqual([GDLLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 3);

    NSURL *log1File = [GDLLogStorage sharedInstance].logHashToLogFile[@(log1Hash)];
    XCTAssertNotNil(log1File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:log1File.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:log1File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);

    NSURL *log2File = [GDLLogStorage sharedInstance].logHashToLogFile[@(log2Hash)];
    XCTAssertNotNil(log2File);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:log2File.path]);
    error = nil;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:log2File error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);

    NSURL *log3File = [GDLLogStorage sharedInstance].logHashToLogFile[@(log3Hash)];
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
  [GDLAssertHelper setAssertionBlock:^{
    [errorExpectation fulfill];
  }];

  // logEvent is referenced past -storeLog, ensuring it's retained, which should assert.
  GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
  logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];

  // Store the log and wait for the expectation.
  [[GDLLogStorage sharedInstance] storeLog:logEvent];
  [self waitForExpectations:@[ errorExpectation ] timeout:5.0];

  NSURL *logFile;
  logFile = [GDLLogStorage sharedInstance].logHashToLogFile[@(logEvent.hash)];

  // This isn't strictly necessary because of the -waitForExpectations above.
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
  });

  // Ensure log was removed.
  [[GDLLogStorage sharedInstance] removeLog:@(logEvent.hash) logTarget:@(logTarget)];
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    XCTAssertEqual([GDLLogStorage sharedInstance].logHashToLogFile.count, 0);
    XCTAssertEqual([GDLLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 0);
  });
}

/** Tests encoding and decoding the storage singleton correctly. */
- (void)testNSSecureCoding {
  XCTAssertTrue([GDLLogStorage supportsSecureCoding]);
  GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
  logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
  NSUInteger logHash = logEvent.hash;
  XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);
  logEvent = nil;
  NSData *storageData = [NSKeyedArchiver archivedDataWithRootObject:[GDLLogStorage sharedInstance]];
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertNotNil([GDLLogStorage sharedInstance].logHashToLogFile[@(logHash)]);
  });
  [[GDLLogStorage sharedInstance] removeLog:@(logHash) logTarget:@(logTarget)];
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertNil([GDLLogStorage sharedInstance].logHashToLogFile[@(logHash)]);
  });

  // TODO(mikehaney24): Ensure that the object created by alloc is discarded?
  [NSKeyedUnarchiver unarchiveObjectWithData:storageData];
  XCTAssertNotNil([GDLLogStorage sharedInstance].logHashToLogFile[@(logHash)]);
}

/** Tests logging a fast log causes an upload attempt. */
- (void)testQoSTierFast {
  NSUInteger logHash;
  // logEvent is autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString" dataUsingEncoding:NSUTF8StringEncoding];
    logEvent.qosTier = GDLLogQoSFast;
    logHash = logEvent.hash;
    XCTAssertFalse(self.uploaderFake.forceUploadCalled);
    XCTAssertNoThrow([[GDLLogStorage sharedInstance] storeLog:logEvent]);
  }
  dispatch_sync([GDLLogStorage sharedInstance].storageQueue, ^{
    XCTAssertTrue(self.uploaderFake.forceUploadCalled);
    XCTAssertEqual([GDLLogStorage sharedInstance].logHashToLogFile.count, 1);
    XCTAssertEqual([GDLLogStorage sharedInstance].logTargetToLogHashSet[@(logTarget)].count, 1);
    NSURL *logFile = [GDLLogStorage sharedInstance].logHashToLogFile[@(logHash)];
    XCTAssertNotNil(logFile);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:logFile.path]);
    NSError *error;
    XCTAssertTrue([[NSFileManager defaultManager] removeItemAtURL:logFile error:&error]);
    XCTAssertNil(error, @"There was an error deleting the logFile: %@", error);
  });
}

/** Tests convert a set of log hashes to a set of log file URLS. */
- (void)testLogHashesToFiles {
  GDLLogStorage *storage = [GDLLogStorage sharedInstance];
  NSUInteger log1Hash, log2Hash, log3Hash;

  // logEvents are autoreleased, and the pool needs to drain.
  @autoreleasepool {
    GDLLogEvent *logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString1" dataUsingEncoding:NSUTF8StringEncoding];
    log1Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"100" logTarget:logTarget];
    logEvent.extensionBytes = [@"testString2" dataUsingEncoding:NSUTF8StringEncoding];
    log2Hash = logEvent.hash;
    XCTAssertNoThrow([storage storeLog:logEvent]);

    logEvent = [[GDLLogEvent alloc] initWithLogMapID:@"404" logTarget:logTarget];
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
