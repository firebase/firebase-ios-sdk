/*
 * Copyright 2019 Google
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
#import "Firebase/InstanceID/FIRInstanceIDAuthKeyChain.h"
#import "Firebase/InstanceID/FIRInstanceIDBackupExcludedPlist.h"
#import "Firebase/InstanceID/FIRInstanceIDStore.h"

static NSString *const kSubDirectoryName = @"FirebaseInstanceIDBackupPlistTest";
static NSString *const kTestPlistFileName = @"com.google.test.IIDBackupExcludedPlist";

@interface FIRInstanceIDBackupExcludedPlist ()
- (BOOL)moveToApplicationSupportSubDirectory:(NSString *)subDirectoryName;
@end

@interface FIRInstanceIDBackupExcludedPlistTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceIDBackupExcludedPlist *plist;

@end

@implementation FIRInstanceIDBackupExcludedPlistTest

- (void)setUp {
  [super setUp];
  [FIRInstanceIDStore createSubDirectory:kSubDirectoryName];
  self.plist = [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kTestPlistFileName
                                                             subDirectory:kSubDirectoryName];
}

- (void)tearDown {
  [self.plist deleteFile:nil];
  [FIRInstanceIDStore removeSubDirectory:kSubDirectoryName error:nil];
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

- (void)testMovePlistToApplicationSupportDirectorySuccess {
  NSDictionary *plistContents = @{@"hello" : @"world", @"id" : @123};
  [self.plist writeDictionary:plistContents error:nil];
  [self.plist moveToApplicationSupportSubDirectory:kSubDirectoryName];
  XCTAssertTrue([self doesPlistFileExist]);
  XCTAssertFalse([self isPlistInDocumentsDirectory]);

  NSDictionary *newPlistContents = @{@"world" : @"hello"};
  [self.plist writeDictionary:newPlistContents error:nil];
  XCTAssertEqualObjects(newPlistContents, [self.plist contentAsDictionary]);
}

- (void)testMovePlistToApplicationSupportDirectoryFailure {
  // This is to test moving data from deprecated document folder to application folder
  // which should only apply to iOS.
#if TARGET_OS_IOS
  // Delete the subdirectory
  [FIRInstanceIDStore removeSubDirectory:kSubDirectoryName error:nil];

  // Create a new plistl This would try to move or write to the ApplicationSupport directory
  // but since the subdirectory is not there anymore it will fail and rather write to the
  // Documents folder.
  self.plist = [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:kTestPlistFileName
                                                             subDirectory:kSubDirectoryName];

  NSDictionary *plistContents = @{@"hello" : @"world", @"id" : @123};
  [self.plist writeDictionary:plistContents error:nil];

  XCTAssertFalse([self doesPlistFileExist]);
  XCTAssertTrue([self isPlistInDocumentsDirectory]);

  NSDictionary *newPlistContents = @{@"world" : @"hello"};
  [self.plist writeDictionary:newPlistContents error:nil];

  XCTAssertEqualObjects(newPlistContents, [self.plist contentAsDictionary]);

  // The new file should still be written to the Documents folder.
  XCTAssertFalse([self doesPlistFileExist]);
  XCTAssertTrue([self isPlistInDocumentsDirectory]);
#endif
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

- (BOOL)isPlistInDocumentsDirectory {
  NSArray *directoryPaths =
      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsSupportDirPath = directoryPaths.lastObject;
  NSArray *components =
      @[ documentsSupportDirPath, [NSString stringWithFormat:@"%@.plist", kTestPlistFileName] ];
  NSString *plistPath = [NSString pathWithComponents:components];
  return [[NSFileManager defaultManager] fileExistsAtPath:plistPath];
}

@end
