/*
 * Copyright 2021 Google LLC
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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingBackupExcludedPlist.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"

static NSString *const kSubDirectoryName = @"FirebaseInstanceIDBackupPlistTest";
static NSString *const kTestPlistFileName = @"com.google.test.IIDBackupExcludedPlist";

@interface FIRMessaging (ExposedForTest)
+ (BOOL)createSubDirectory:(NSString *)subDirectoryName;
@end

@interface FIRMessagingBackupExcludedPlist ()
- (BOOL)moveToApplicationSupportSubDirectory:(NSString *)subDirectoryName;
@end

@interface FIRMessagingBackupExcludedPlistTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRMessagingBackupExcludedPlist *plist;

@end

@implementation FIRMessagingBackupExcludedPlistTest

- (void)setUp {
  [super setUp];
  [FIRMessaging createSubDirectory:kSubDirectoryName];
  self.plist = [[FIRMessagingBackupExcludedPlist alloc] initWithFileName:kTestPlistFileName
                                                            subDirectory:kSubDirectoryName];
}

- (void)tearDown {
  [self.plist deleteFile:nil];
  [super tearDown];
}

- (void)testWriteToPlistInDocumentsFolder {
  XCTAssertNil([self.plist contentAsDictionary]);
  NSDictionary *plistContents = @{@"hello" : @"world", @"id" : @123};
  [self.plist writeDictionary:plistContents error:nil];
  XCTAssertEqualObjects(plistContents, [self.plist contentAsDictionary]);
}

- (void)testDeleteFileInDocumentsFolder {
  NSDictionary *plistContents = @{@"hello" : @"world", @"id" : @123};
  [self.plist writeDictionary:plistContents error:nil];
  XCTAssertEqualObjects(plistContents, [self.plist contentAsDictionary]);

  // Delete file
  XCTAssertTrue([self.plist doesFileExist]);
  XCTAssertTrue([self.plist deleteFile:nil]);
  XCTAssertFalse([self.plist doesFileExist]);
}

- (void)testWriteToPlistInApplicationSupportFolder {
  XCTAssertNil([self.plist contentAsDictionary]);

  NSDictionary *plistContents = @{@"hello" : @"world", @"id" : @123};
  [self.plist writeDictionary:plistContents error:nil];

  XCTAssertTrue([self.plist doesFileExist]);
  XCTAssertEqualObjects(plistContents, [self.plist contentAsDictionary]);

  XCTAssertTrue([self doesPlistFileExist]);
}

#pragma mark - Private Helpers

- (BOOL)doesPlistFileExist {
#if TARGET_OS_TV
  NSArray *directoryPaths =
      NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
  NSArray *directoryPaths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
#endif
  NSString *dirPath = directoryPaths.lastObject;
  NSArray *components =
      @[ dirPath, kSubDirectoryName, [NSString stringWithFormat:@"%@.plist", kTestPlistFileName] ];
  NSString *plistPath = [NSString pathWithComponents:components];
  return [[NSFileManager defaultManager] fileExistsAtPath:plistPath];
}
@end
