// Copyright 2017 Google
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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorage.h"

//#import "FirebaseStorageInternal/Sources/FIRStorageComponent.h"
#import "FirebaseStorageInternal/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorageInternal/Tests/Unit/FIRStorageTestHelpers.h"
#import "SharedTestUtilities/FIRComponentTestUtilities.h"

@interface FIRIMPLStorageReferenceTests : XCTestCase

@property(strong, nonatomic) FIRIMPLStorage *storage;

@end

@implementation FIRIMPLStorageReferenceTests

- (void)setUp {
  [super setUp];
  self.storage = [FIRStorageTestHelpers storageWithMockedApp];
}

- (void)tearDown {
  self.storage = nil;
  [super tearDown];
}

- (void)testRoot {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects([ref.root stringValue], @"gs://bucket/");
}

- (void)testRootWithNoPath {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  XCTAssertEqualObjects([ref.root stringValue], @"gs://bucket/");
}

- (void)testSingleChild {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *childRef = [ref child:@"path"];
  XCTAssertEqualObjects([childRef stringValue], @"gs://bucket/path");
}

- (void)testMultipleChildrenSingleString {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *childRef = [ref child:@"path/to/object"];
  XCTAssertEqualObjects([childRef stringValue], @"gs://bucket/path/to/object");
}

- (void)testMultipleChildrenMultipleStrings {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *childRef = [ref child:@"path"];
  childRef = [childRef child:@"to"];
  childRef = [childRef child:@"object"];
  XCTAssertEqualObjects([childRef stringValue], @"gs://bucket/path/to/object");
}

- (void)testSameChildDifferentRef {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *firstRef = [ref child:@"1"];
  FIRIMPLStorageReference *secondRef = [ref child:@"1"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/");
  XCTAssertEqualObjects(firstRef, secondRef);
  XCTAssertNotEqual(firstRef, secondRef);
}

- (void)testDifferentChildDifferentRef {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *firstRef = [ref child:@"1"];
  FIRIMPLStorageReference *secondRef = [ref child:@"2"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/");
  XCTAssertNotEqual(firstRef, secondRef);
}

- (void)testChildWithTrailingSlash {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object/"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/path/to/object");
}

- (void)testChildWithLeadingSlash {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket//path/to/object/"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/path/to/object");
}

- (void)testChildCompressSlashes {
  FIRIMPLStorageReference *ref =
      [self.storage referenceForURL:@"gs://bucket//path///to////object////"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/path/to/object");
}

- (void)testParent {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  FIRIMPLStorageReference *parentRef = [ref parent];
  XCTAssertEqualObjects([parentRef stringValue], @"gs://bucket/path/to");
}

- (void)testParentToRoot {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path"];
  FIRIMPLStorageReference *parentRef = [ref parent];
  XCTAssertEqualObjects([parentRef stringValue], @"gs://bucket/");
}

- (void)testParentToRootTrailingSlash {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/"];
  FIRIMPLStorageReference *parentRef = [ref parent];
  XCTAssertEqualObjects([parentRef stringValue], @"gs://bucket/");
}

- (void)testParentAtRoot {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *parentRef = [ref parent];
  XCTAssertNil(parentRef);
}

- (void)testBucket {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(ref.bucket, @"bucket");
}

- (void)testName {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(ref.name, @"object");
}

- (void)testNameNoObject {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  XCTAssertEqualObjects(ref.name, @"");
}

- (void)testFullPath {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(ref.fullPath, @"path/to/object");
}

- (void)testFullPathNoObject {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  XCTAssertEqualObjects(ref.fullPath, @"");
}

- (void)testCopy {
  FIRIMPLStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRIMPLStorageReference *copiedRef = [ref copy];
  XCTAssertEqualObjects(ref, copiedRef);
  XCTAssertNotEqual(ref, copiedRef);
}

- (void)testReferenceWithNonExistentFileFailsWithCompletion {
  NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.data"];
  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:tempFilePath];

  NSURL *dummyFileURL = [NSURL fileURLWithPath:@"some_non_existing-folder/file.data"];

  XCTestExpectation *expectation = [self expectationWithDescription:@"completionExpectation"];

  [ref putFile:dummyFileURL
        metadata:nil
      completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertNil(metadata);

        XCTAssertEqualObjects(error.domain, FIRStorageErrorDomainInternal);
        XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnknown);
        NSString *expectedDescription = [NSString
            stringWithFormat:@"File at URL: %@ is not reachable. "
                             @"Ensure file URL is not a directory, symbolic link, or invalid url.",
                             dummyFileURL.absoluteString];
        XCTAssertEqualObjects(error.localizedDescription, expectedDescription);
      }];

  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
}

- (void)testReferenceWithNilFileURLFailsWithCompletion {
  NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.data"];
  FIRIMPLStorageReference *ref = [self.storage referenceWithPath:tempFilePath];

  NSURL *dummyFileURL = [NSURL URLWithString:@"bad-url"];

  XCTestExpectation *expectation = [self expectationWithDescription:@"completionExpectation"];

  [ref putFile:dummyFileURL
        metadata:nil
      completion:^(FIRIMPLStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertNil(metadata);

        XCTAssertEqualObjects(error.domain, FIRStorageErrorDomainInternal);
        XCTAssertEqual(error.code, FIRIMPLStorageErrorCodeUnknown);
        NSString *expectedDescription = [NSString
            stringWithFormat:@"File at URL: %@ is not reachable. "
                             @"Ensure file URL is not a directory, symbolic link, or invalid url.",
                             dummyFileURL.absoluteString];
        XCTAssertEqualObjects(error.localizedDescription, expectedDescription);
      }];

  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
}

@end
