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

#import "GDTTestCase.h"

#import <GoogleDataTransport/GDTUploadPackage.h>

#import "GDTUploadPackage_Private.h"

@interface GDTUploadPackageTest : GDTTestCase

@end

@implementation GDTUploadPackageTest

/** Tests the default initializer. */
- (void)testInit {
  XCTAssertNotNil([[GDTUploadPackage alloc] init]);
}

/** Tests copying indicates that the underlying sets of events can't be changed from underneath. */
- (void)testRegisterUpload {
  GDTUploadPackage *uploadPackage = [[GDTUploadPackage alloc] init];
  GDTUploadPackage *uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  XCTAssertEqualObjects(uploadPackage.eventHashes, uploadPackageCopy.eventHashes);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);

  uploadPackage.eventHashes = [NSSet set];
  uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  XCTAssertEqualObjects(uploadPackage.eventHashes, uploadPackageCopy.eventHashes);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);

  NSMutableSet *set = [[NSMutableSet alloc] initWithObjects:@1, @2, @3, nil];
  [set addObject:@4];
  uploadPackage.eventHashes = set;
  uploadPackageCopy = [uploadPackage copy];
  XCTAssertNotEqual(uploadPackage, uploadPackageCopy);
  [set addObject:@5];
  XCTAssertFalse([uploadPackageCopy.eventHashes containsObject:@5]);
  XCTAssertEqualObjects(uploadPackage.eventHashes, uploadPackageCopy.eventHashes);
  XCTAssertEqualObjects(uploadPackage, uploadPackageCopy);
}

@end
