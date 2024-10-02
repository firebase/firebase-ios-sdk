// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <XCTest/XCTest.h>

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

@interface FIRCLSLoggingTests : XCTestCase

@property(nonatomic, strong) NSString* kvPath;
@property(nonatomic, strong) NSString* compactedKVPath;
@property(nonatomic, strong) NSString* logAPath;
@property(nonatomic, strong) NSString* logBPath;
@property(nonatomic, strong) NSString* errorAPath;
@property(nonatomic, strong) NSString* errorBPath;

@end

@implementation FIRCLSLoggingTests

- (void)setUp {
  [super setUp];

  FIRCLSContextBaseInit();

  NSString* tempDir = NSTemporaryDirectory();
  self.kvPath = [tempDir stringByAppendingPathComponent:@"kv.clsrecord"];
  self.compactedKVPath = [tempDir stringByAppendingPathComponent:@"compacted_kv.clsrecord"];
  self.logAPath = [tempDir stringByAppendingPathComponent:@"loga.clsrecord"];
  self.logBPath = [tempDir stringByAppendingPathComponent:@"logb.clsrecord"];
  self.errorAPath = [tempDir stringByAppendingPathComponent:FIRCLSReportErrorAFile];
  self.errorBPath = [tempDir stringByAppendingPathComponent:FIRCLSReportErrorBFile];

  _firclsContext.readonly->logging.userKVStorage.incrementalPath =
      strdup([self.kvPath fileSystemRepresentation]);
  _firclsContext.readonly->logging.userKVStorage.compactedPath =
      strdup([self.compactedKVPath fileSystemRepresentation]);
  _firclsContext.readonly->logging.logStorage.aPath =
      strdup([self.logAPath fileSystemRepresentation]);
  _firclsContext.readonly->logging.logStorage.bPath =
      strdup([self.logBPath fileSystemRepresentation]);
  _firclsContext.readonly->logging.errorStorage.aPath =
      strdup([self.errorAPath fileSystemRepresentation]);
  _firclsContext.readonly->logging.errorStorage.bPath =
      strdup([self.errorBPath fileSystemRepresentation]);
  _firclsContext.readonly->logging.userKVStorage.maxIncrementalCount =
      FIRCLSUserLoggingMaxKVEntries;

  _firclsContext.readonly->logging.logStorage.maxSize = 64 * 1024;
  _firclsContext.readonly->logging.logStorage.restrictBySize = true;
  _firclsContext.readonly->logging.errorStorage.maxSize = 64 * 1024;
  _firclsContext.readonly->logging.errorStorage.restrictBySize = false;
  _firclsContext.readonly->logging.errorStorage.maxEntries = 8;
  _firclsContext.readonly->logging.errorStorage.entryCount =
      &_firclsContext.writable->logging.errorsCount;
  _firclsContext.readonly->logging.userKVStorage.maxCount = 64;

  _firclsContext.writable->logging.activeUserLogPath =
      _firclsContext.readonly->logging.logStorage.aPath;
  _firclsContext.writable->logging.activeErrorLogPath =
      _firclsContext.readonly->logging.errorStorage.aPath;
  _firclsContext.writable->logging.userKVCount = 0;
  _firclsContext.writable->logging.internalKVCount = 0;
  _firclsContext.writable->logging.errorsCount = 0;

  _firclsContext.readonly->initialized = true;

  for (NSString* path in @[
         self.kvPath, self.compactedKVPath, self.logAPath, self.logBPath, self.errorAPath,
         self.errorBPath
       ]) {
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
  }
}

- (void)tearDown {
  free((void*)_firclsContext.readonly->logging.userKVStorage.incrementalPath);
  free((void*)_firclsContext.readonly->logging.userKVStorage.compactedPath);
  free((void*)_firclsContext.readonly->logging.logStorage.aPath);
  free((void*)_firclsContext.readonly->logging.logStorage.bPath);
  free((void*)_firclsContext.readonly->logging.errorStorage.aPath);
  free((void*)_firclsContext.readonly->logging.errorStorage.bPath);

  FIRCLSContextBaseDeinit();

  [super tearDown];
}

- (NSArray*)incrementalKeyValues {
  return FIRCLSUserLoggingStoredKeyValues(
      _firclsContext.readonly->logging.userKVStorage.incrementalPath);
}

- (NSArray*)compactedKeyValues {
  return FIRCLSUserLoggingStoredKeyValues(
      _firclsContext.readonly->logging.userKVStorage.compactedPath);
}

- (NSArray*)logAContents {
  return FIRCLSFileReadSections([self.logAPath fileSystemRepresentation], true, nil);
}

- (NSArray*)logBContents {
  return FIRCLSFileReadSections([self.logBPath fileSystemRepresentation], true, nil);
}

- (NSArray*)errorAContents {
  return FIRCLSFileReadSections([self.errorAPath fileSystemRepresentation], true, nil);
}

- (NSArray*)errorBContents {
  return FIRCLSFileReadSections([self.errorBPath fileSystemRepresentation], true, nil);
}

- (void)testKeyValueWithNilKey {
  FIRCLSUserLoggingRecordUserKeyValue(nil, @"some string value");

  XCTAssertEqual([self incrementalKeyValues].count, 0, @"");
}

- (void)testKeyValueWithNilValue {
  FIRCLSUserLoggingRecordUserKeyValue(@"mykey", nil);

  XCTAssertEqual([[self incrementalKeyValues] count], 1, @"");
}

- (void)testKeyValueWithNilValueCompaction {
  for (int i = 0; i < FIRCLSUserLoggingMaxKVEntries - 1; i++) {
    FIRCLSUserLoggingRecordUserKeyValue(@"mykey", [NSString stringWithFormat:@"myvalue%i", i]);
  }
  FIRCLSUserLoggingRecordUserKeyValue(@"mykey", nil);

  XCTAssertEqual([[self compactedKeyValues] count], 0,
                 @"Key with last value of nil was not removed in compaction.");
}

- (void)testKeyValueWithNilKeyAndValue {
  FIRCLSUserLoggingRecordUserKeyValue(nil, nil);

  XCTAssertEqual([[self incrementalKeyValues] count], 0, @"");
}

- (void)testKeyValueLog {
  FIRCLSUserLoggingRecordUserKeyValue(@"mykey", @"some string value");

  NSArray* keyValues = [self incrementalKeyValues];

  XCTAssertEqual([keyValues count], 1, @"");
  XCTAssertEqualObjects(keyValues[0][@"key"], @"6d796b6579", @"");
  XCTAssertEqualObjects(keyValues[0][@"value"], @"736f6d6520737472696e672076616c7565", @"");
}

- (void)testKeyValueLogSingleKeyCompaction {
  for (NSUInteger i = 0; i < FIRCLSUserLoggingMaxKVEntries; ++i) {
    FIRCLSUserLoggingRecordUserKeyValue(
        @"mykey", [NSString stringWithFormat:@"some string value: %lu", (unsigned long)i]);
  }

  // we now need to wait for compaction to complete
  dispatch_sync(FIRCLSGetLoggingQueue(), ^{
    NSLog(@"queue emptied");
  });

  NSArray* keyValues = [self incrementalKeyValues];
  NSArray* compactedKeyValues = [self compactedKeyValues];

  XCTAssertEqual([keyValues count], 0, @"");
  XCTAssertEqual([compactedKeyValues count], 1, @"");
  XCTAssertEqualObjects(compactedKeyValues[0][@"key"], @"6d796b6579", @"");

  // the final value of this key should be "some string value: 63"
  XCTAssertEqualObjects(compactedKeyValues[0][@"value"],
                        @"736f6d6520737472696e672076616c75653a203633", @"");
}

- (void)testKeyValueLogMoreThanMaxKeys {
  // we need to end up with max + 1 keys written
  for (NSUInteger i = 0; i <= _firclsContext.readonly->logging.userKVStorage.maxCount + 1; ++i) {
    NSString* key = [NSString stringWithFormat:@"key%lu", (unsigned long)i];
    NSString* value = [NSString stringWithFormat:@"some string value: %lu", (unsigned long)i];

    FIRCLSUserLoggingRecordUserKeyValue(key, value);
  }

  // Do a full compaction here. This does two things. First, it makes sure
  // we don't have any incremental keys. It also accounts for differences between
  // the max and incremental values.
  dispatch_sync(FIRCLSGetLoggingQueue(), ^{
    FIRCLSUserLoggingCompactKVEntries(&_firclsContext.readonly->logging.userKVStorage);
  });

  NSArray* keyValues = [self incrementalKeyValues];
  NSArray* compactedKeyValues = [self compactedKeyValues];

  XCTAssertEqual([keyValues count], 0, @"");
  XCTAssertEqual([compactedKeyValues count], 64, @"");
}

- (void)testEmptyKeysAndValues {
  FIRCLSUserLoggingRecordUserKeysAndValues(@{});
  XCTAssertEqual([self incrementalKeyValues].count, 0, @"");
}

- (void)testKeysAndValuesWithNilValue {
  FIRCLSUserLoggingRecordUserKeysAndValues(@{@"mykey" : [NSNull null]});

  XCTAssertEqual([[self incrementalKeyValues] count], 1, @"");
}

- (void)testKeysAndValuesLog {
  NSDictionary* keysAndValues =
      @{@"mykey" : @"some string value", @"mykey2" : @"some string value 2"};
  FIRCLSUserLoggingRecordUserKeysAndValues(keysAndValues);

  NSArray* keyValues = [self incrementalKeyValues];

  XCTAssertEqual([keyValues count], 2, @"");
  XCTAssertEqualObjects(keyValues[0][@"key"], @"6d796b6579", @"");
  XCTAssertEqualObjects(keyValues[0][@"value"], @"736f6d6520737472696e672076616c7565", @"");
  XCTAssertEqualObjects(keyValues[1][@"key"], @"6d796b657932", @"");
  XCTAssertEqualObjects(keyValues[1][@"value"], @"736f6d6520737472696e672076616c75652032", @"");
}

- (void)testKeysAndValuesLogKeyCompaction {
  for (NSUInteger i = 0; i < FIRCLSUserLoggingMaxKVEntries; ++i) {
    NSString* value = [NSString stringWithFormat:@"some string value: %lu", (unsigned long)i];
    FIRCLSUserLoggingRecordUserKeysAndValues(@{@"mykey" : value});
  }

  // we now need to wait for compaction to complete
  dispatch_sync(FIRCLSGetLoggingQueue(), ^{
    NSLog(@"queue emptied");
  });

  NSArray* keyValues = [self incrementalKeyValues];
  NSArray* compactedKeyValues = [self compactedKeyValues];

  XCTAssertEqual([keyValues count], 0, @"");
  XCTAssertEqual([compactedKeyValues count], 1, @"");
  XCTAssertEqualObjects(compactedKeyValues[0][@"key"], @"6d796b6579", @"");

  // the final value of this key should be "some string value: 63"
  XCTAssertEqualObjects(compactedKeyValues[0][@"value"],
                        @"736f6d6520737472696e672076616c75653a203633", @"");
}

- (void)testKeysAndValuesLogMoreThanMaxKeys {
  NSUInteger keysAndValuesCount = _firclsContext.readonly->logging.userKVStorage.maxCount + 1;
  NSMutableDictionary* keysAndValuesToBeCompactedIn = [NSMutableDictionary dictionary];

  // we need to end up with max + 1 keys written
  for (NSUInteger i = 0; i <= keysAndValuesCount; ++i) {
    NSString* key = [NSString stringWithFormat:@"key%lu", (unsigned long)i];
    NSString* value = [NSString stringWithFormat:@"some string value: %lu", (unsigned long)i];

    if (i == 0) {
      FIRCLSUserLoggingRecordUserKeyValue(key, value);
    } else {
      keysAndValuesToBeCompactedIn[key] = value;
    }
  }

  FIRCLSUserLoggingRecordUserKeysAndValues(keysAndValuesToBeCompactedIn);

  // Do a full compaction here. This does two things. First, it makes sure
  // we don't have any incremental keys. It also accounts for differences between
  // the max and incremental values.
  dispatch_sync(FIRCLSGetLoggingQueue(), ^{
    FIRCLSUserLoggingCompactKVEntries(&_firclsContext.readonly->logging.userKVStorage);
  });

  NSArray* keyValues = [self incrementalKeyValues];
  NSArray* compactedKeyValues = [self compactedKeyValues];

  XCTAssertEqual([keyValues count], 0, @"");
  XCTAssertEqual([compactedKeyValues count], 64, @"");
}

- (void)testUserLogNil {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRCLSLog(nil);
#pragma clang diagnostic pop

  XCTAssertEqual([[self logAContents] count], 0, @"");
}

- (void)testLargeLogLine {
  size_t strLength = 100 * 1024;  // Attempt to write 100k of data
  char* longLine = malloc(strLength + 1);
  memset(longLine, 'a', strLength);
  longLine[strLength] = '\0';
  NSString* longStr = [[NSString alloc] initWithBytesNoCopy:longLine
                                                     length:strLength
                                                   encoding:NSUTF8StringEncoding
                                               freeWhenDone:YES];

  FIRCLSLog(@"%@", longStr);

  NSArray* array = [self logAContents];
  NSString* message = array[0][@"log"][@"msg"];
  XCTAssertEqual(message.length, _firclsContext.readonly->logging.logStorage.maxSize * 2,
                 "message: \"%@\"", message);
}

- (void)testUserLog {
  FIRCLSLog(@"some value");

  NSArray* array = [self logAContents];

  XCTAssertEqual([array count], 1, @"");
  XCTAssertEqualObjects(array[0][@"log"][@"msg"], @"736f6d652076616c7565", @"");
}

- (void)testUserLogRotation {
  // tune this carefully, based on max file size
  for (int i = 0; i < 969; ++i) {
    FIRCLSLog(@"some value %d", i);
  }

  NSArray* logA = [self logAContents];
  NSArray* logB = [self logBContents];

  XCTAssertEqual([logA count], 968, @"");
  XCTAssertEqual([logB count], 1, @"");
}

- (void)testUserLogRotationBackToBeginning {
  // careful tuning needs to be done to make sure there's exactly one entry
  for (int i = 0; i < 1907; ++i) {
    FIRCLSLog(@"some value %d", i);
  }

  NSArray* logA = [self logAContents];
  NSArray* logB = [self logBContents];

  XCTAssertEqual([logA count], 1, @"");
  XCTAssertEqual([logB count], 938, @"");

  // We need to verify that things have rolled correctly. This means log A should now have the
  // very last value, and log b should have the second-to-last.
  XCTAssertEqualObjects(logA[0][@"log"][@"msg"], @"736f6d652076616c75652031393036",
                        @"");  // "some value 1906"
  XCTAssertEqualObjects(logB[937][@"log"][@"msg"], @"736f6d652076616c75652031393035",
                        @"");  // "some value 1905"
}

- (void)testLoggedError {
  NSError* error = [NSError errorWithDomain:@"My Custom Domain"
                                       code:-1
                                   userInfo:@{@"key1" : @"value", @"key2" : @"value2"}];

  FIRCLSUserLoggingRecordError(error, @{@"additional" : @"key"}, nil);

  NSArray* errors = [self errorAContents];

  XCTAssertEqual([errors count], 1, @"");

  NSDictionary* errorDict = errors[0][@"error"];

  XCTAssertNotNil(errorDict, @"");

  XCTAssert([errorDict[@"stacktrace"] count] > 5, @"should have at least a few frames");
  XCTAssertEqualObjects(errorDict[@"domain"], @"4d7920437573746f6d20446f6d61696e", @"");
  XCTAssertEqual([errorDict[@"code"] integerValue], -1, @"");

  // this requires a sort to be non-flakey
  NSArray* userInfoEntries =
      [errorDict[@"info"] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1[0] compare:obj2[0]];
      }];

  NSArray* entryOne = @[ @"6b657931", @"76616c7565" ];
  NSArray* entryTwo = @[ @"6b657932", @"76616c756532" ];

  XCTAssertEqual([userInfoEntries count], 2, @"");
  XCTAssertEqualObjects(userInfoEntries[0], entryOne, @"");
  XCTAssertEqualObjects(userInfoEntries[1], entryTwo, @"");

  NSArray* additionalEntries = errorDict[@"extra_info"];
  entryOne = @[ @"6164646974696f6e616c", @"6b6579" ];

  XCTAssertEqual([additionalEntries count], 1, @"");
  XCTAssertEqualObjects(additionalEntries[0], entryOne, @"");
}

- (void)testWritingMaximumNumberOfLoggedErrors {
  NSError* error = [NSError errorWithDomain:@"My Custom Domain"
                                       code:-1
                                   userInfo:@{@"key1" : @"value", @"key2" : @"value2"}];

  for (size_t i = 0; i < _firclsContext.readonly->logging.errorStorage.maxEntries; ++i) {
    FIRCLSUserLoggingRecordError(error, nil, nil);
  }

  NSArray* errors = [self errorAContents];

  XCTAssertEqual([errors count], 8, @"");

  // at this point, if we log one more, we should expect a roll over to the next file

  FIRCLSUserLoggingRecordError(error, nil, nil);

  XCTAssertEqual([[self errorAContents] count], 8, @"");
  XCTAssertEqual([[self errorBContents] count], 1, @"");
  XCTAssertEqual(*_firclsContext.readonly->logging.errorStorage.entryCount, 1);

  // and our next entry should continue into the B file

  FIRCLSUserLoggingRecordError(error, nil, nil);

  XCTAssertEqual([[self errorAContents] count], 8, @"");
  XCTAssertEqual([[self errorBContents] count], 2, @"");
  XCTAssertEqual(*_firclsContext.readonly->logging.errorStorage.entryCount, 2);
}

- (void)testLoggedErrorWithNullsInAdditionalInfo {
  NSError* error = [NSError errorWithDomain:@"Domain" code:-1 userInfo:nil];

  FIRCLSUserLoggingRecordError(error, @{@"null-key" : [NSNull null]}, nil);

  NSArray* errors = [self errorAContents];

  XCTAssertEqual([errors count], 1, @"");

  NSDictionary* errorDict = errors[0][@"error"];

  XCTAssertNotNil(errorDict, @"");

  XCTAssert([errorDict[@"stacktrace"] count] > 5, @"should have at least a few frames");
  XCTAssertEqualObjects(errorDict[@"domain"], @"446f6d61696e", @"");
  XCTAssertEqual([errorDict[@"code"] integerValue], -1, @"");

  XCTAssertEqual([errorDict[@"info"] count], 0, @"");

  NSArray* additionalEntries = errorDict[@"extra_info"];
  NSArray* entryOne = @[ @"6e756c6c2d6b6579", @"3c6e756c6c3e" ];

  XCTAssertEqual([additionalEntries count], 1, @"");
  XCTAssertEqualObjects(additionalEntries[0], entryOne, @"");
}

@end
