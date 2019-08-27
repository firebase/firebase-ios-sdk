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

#import <GoogleUtilities/GULKeyedArchiver.h>
#import <XCTest/XCTest.h>

@interface SecureCodingIncompatibleObject : NSObject <NSCoding>
@end

@implementation SecureCodingIncompatibleObject

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
  return [self init];
}

@end

@interface GULKeyedArchiverTests : XCTestCase

@end

@implementation GULKeyedArchiverTests

- (void)testArchiveUnarchive {
  NSDictionary *objectToArchive = @{@"key1" : @"value1", @"key2" : @(2)};

  NSError *error;
  NSData *archiveData = [GULKeyedArchiver archivedDataWithRootObject:objectToArchive
                                               requiringSecureCoding:YES
                                                               error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(archiveData);

  NSDictionary *unarchivedObject = [GULKeyedArchiver unarchivedObjectOfClass:[NSDictionary class]
                                                                    fromData:archiveData
                                                                       error:&error];
  XCTAssertNil(error);
  XCTAssert([objectToArchive isEqualToDictionary:unarchivedObject]);
}

- (void)testArchivingIncompatibleObjectError {
  SecureCodingIncompatibleObject *objectToArchive = [[SecureCodingIncompatibleObject alloc] init];

  NSError *error;
  NSData *archiveData = [GULKeyedArchiver archivedDataWithRootObject:objectToArchive
                                               requiringSecureCoding:YES
                                                               error:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(archiveData);
}

- (void)testUnarchivingClassMismatchError {
  NSDictionary *objectToArchive = @{@"key1" : @"value1", @"key2" : @(2)};
  NSError *error;
  NSData *archiveData = [GULKeyedArchiver archivedDataWithRootObject:objectToArchive
                                               requiringSecureCoding:YES
                                                               error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(archiveData);

  NSArray *unarchivedObject = [GULKeyedArchiver unarchivedObjectOfClass:[NSArray class]
                                                               fromData:archiveData
                                                                  error:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(unarchivedObject);
}

- (void)testUnarchivingCorruptedDataError {
  NSData *corruptedData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSString *unarchivedObject = [GULKeyedArchiver unarchivedObjectOfClass:[NSString class]
                                                                fromData:corruptedData
                                                                   error:&error];
  XCTAssertNotNil(error);
  XCTAssertNil(unarchivedObject);
}

- (void)testArchiveUnarchiveWithNULLError {
  SecureCodingIncompatibleObject *objectToArchive = [[SecureCodingIncompatibleObject alloc] init];

  NSData *archiveData = [GULKeyedArchiver archivedDataWithRootObject:objectToArchive
                                               requiringSecureCoding:YES
                                                               error:NULL];
  XCTAssertNil(archiveData);

  NSData *corruptedData = [@"abc" dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *unarchivedObject = [GULKeyedArchiver unarchivedObjectOfClass:[NSDictionary class]
                                                                    fromData:corruptedData
                                                                       error:NULL];
  XCTAssertNil(unarchivedObject);
}

@end
