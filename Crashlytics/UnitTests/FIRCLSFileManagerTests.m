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

@interface FIRCLSFileManagerTests : XCTestCase {
  FIRCLSFileManager* _manager;
}

@property(nonatomic, retain, readonly) FIRCLSFileManager* manager;

@end

@implementation FIRCLSFileManagerTests

- (void)setUp {
  [super setUp];

  _manager = [[FIRCLSFileManager alloc] init];

  [self removeRootDirectory];
}

- (void)tearDown {
  [self removeRootDirectory];

  [super tearDown];
}

- (BOOL)removeRootDirectory {
  if ([self doesFileExist:[_manager rootPath]]) {
    assert([_manager removeItemAtPath:[_manager rootPath]]);
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
