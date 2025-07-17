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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"

// Test-only category to allow setting the root path
@interface FIRCLSFileManager (Testing)
- (void)test_setRootPath:(NSString *)newRootPath;
@end

@implementation FIRCLSFileManager (Testing)
- (void)test_setRootPath:(NSString *)newRootPath {
  // Access the private _rootPath ivar. This requires the test to be linked such that
  // it can see the ivar layout of FIRCLSFileManager.
  // This is a common, if somewhat fragile, pattern for testing Objective-C.
  // An alternative would be to modify FIRCLSFileManager to allow injection for testing,
  // or use a more complex mocking strategy.
  [self setValue:newRootPath forKey:@"_rootPath"];
}
@end

@interface FIRCLSFileManagerTests : XCTestCase {
  FIRCLSFileManager* _manager;
  NSString *_testSpecificRootPath;
}

@property(nonatomic, retain, readonly) FIRCLSFileManager* manager;

@end

@implementation FIRCLSFileManagerTests

- (void)setUp {
  [super setUp];

  // Generate a unique path for this test instance
  _testSpecificRootPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];

  _manager = [[FIRCLSFileManager alloc] init];
  // Override the root path to our unique one
  [_manager test_setRootPath:_testSpecificRootPath];

  // Ensure the unique directory exists before any test operations
  // and remove any potential leftovers from a previous failed run (though UUID should make it unique).
  [self removeTestSpecificRootDirectory]; // Clean up if it exists
  [[NSFileManager defaultManager] createDirectoryAtPath:_testSpecificRootPath
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
}

- (void)tearDown {
  [self removeTestSpecificRootDirectory];
  _manager = nil; // Release the manager
  _testSpecificRootPath = nil; // Release the path

  [super tearDown];
}

- (BOOL)removeTestSpecificRootDirectory {
  if (_testSpecificRootPath && [[NSFileManager defaultManager] fileExistsAtPath:_testSpecificRootPath]) {
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:_testSpecificRootPath error:&error];
    if (!success) {
        NSLog(@"[FIRCLSFileManagerTests] Error removing test root directory %@: %@", _testSpecificRootPath, error);
    }
    return success;
  }
  return YES;
}

- (void)printPathContents:(NSString*)path {
  NSLog(@"%@", [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil]);
}

- (BOOL)doesFileExist:(NSString*)path {
  return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (void)testCreateV4DirectoryStructure {
  NSString* path = [[self manager] rootPath];

  [[self manager] createReportDirectories];

  XCTAssertTrue([self doesFileExist:path], @"");

  path = [path stringByAppendingPathComponent:@"v5/reports"];
  XCTAssertTrue([self doesFileExist:path], @"");

  for (NSString* subpath in @[ @"active", @"prepared", @"processing" ]) {
    XCTAssertTrue([self doesFileExist:[path stringByAppendingPathComponent:subpath]], @"");
  }
}

@end
