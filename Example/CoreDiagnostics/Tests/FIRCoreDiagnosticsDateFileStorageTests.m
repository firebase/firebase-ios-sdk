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
#import "FIRCDLibrary/FIRCoreDiagnosticsDateFileStorage.h"

@interface FIRCoreDiagnosticsDateFileStorageTests : XCTestCase
@property(nonatomic) NSURL *fileURL;
@property(nonatomic) FIRCoreDiagnosticsDateFileStorage *storage;
@end

@implementation FIRCoreDiagnosticsDateFileStorageTests

- (void)setUp {
  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  XCTAssertNotNil(documentsPath);
  NSURL *documentsURL = [NSURL fileURLWithPath:documentsPath];
  self.fileURL = [documentsURL URLByAppendingPathComponent:@"FIRDiagnosticsDateFileStorageTests"
                                               isDirectory:NO];

  NSError *error;
  if (![documentsURL checkResourceIsReachableAndReturnError:&error]) {
    XCTAssert([[NSFileManager defaultManager] createDirectoryAtURL:documentsURL
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error],
              @"Error: %@", error);
  }

  self.storage = [[FIRCoreDiagnosticsDateFileStorage alloc] initWithFileURL:self.fileURL];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
  self.fileURL = nil;
  self.storage = nil;
}

- (void)testDateStorage {
  NSDate *dateToSave = [NSDate date];

  XCTAssertNil([self.storage date]);

  NSError *error;
  XCTAssertTrue([self.storage setDate:dateToSave error:&error]);

  XCTAssertEqualObjects([self.storage date], dateToSave);

  XCTAssertTrue([self.storage setDate:nil error:&error]);
  XCTAssertNil([self.storage date]);
}

- (void)testDateIsStoredToFileSystem {
  NSDate *date = [NSDate date];

  NSError *error;
  XCTAssert([self.storage setDate:date error:&error], @"Error: %@", error);

  FIRCoreDiagnosticsDateFileStorage *anotherStorage =
      [[FIRCoreDiagnosticsDateFileStorage alloc] initWithFileURL:self.fileURL];

  XCTAssertEqualObjects([anotherStorage date], date);
}

@end
