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

#import "FirebaseStorage/Sources/Public/FirebaseStorage/FIRStorage.h"

#import "FirebaseStorage/Sources/FIRStorageComponent.h"
#import "FirebaseStorage/Sources/FIRStorageReference_Private.h"
#import "FirebaseStorage/Tests/Unit/FIRStorageTestHelpers.h"
#import "SharedTestUtilities/FIRComponentTestUtilities.h"

@interface FIRStorageReferenceTests : XCTestCase

@property(strong, nonatomic) FIRStorage *storage;

@end

@implementation FIRStorageReferenceTests

- (void)setUp {
  [super setUp];

  id mockOptions = OCMClassMock([FIROptions class]);
  OCMStub([mockOptions storageBucket]).andReturn(@"bucket");

  id mockApp = [FIRStorageTestHelpers mockedApp];
  OCMStub([mockApp name]).andReturn(kFIRStorageAppName);
  OCMStub([(FIRApp *)mockApp options]).andReturn(mockOptions);
  self.storage = [FIRStorage storageForApp:mockApp];
}

- (void)tearDown {
  self.storage = nil;
  [super tearDown];
}

- (void)testRoot {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects([ref.root stringValue], @"gs://bucket/");
}

- (void)testRootWithNoPath {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  XCTAssertEqualObjects([ref.root stringValue], @"gs://bucket/");
}

- (void)testSingleChild {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *childRef = [ref child:@"path"];
  XCTAssertEqualObjects([childRef stringValue], @"gs://bucket/path");
}

- (void)testMultipleChildrenSingleString {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *childRef = [ref child:@"path/to/object"];
  XCTAssertEqualObjects([childRef stringValue], @"gs://bucket/path/to/object");
}

- (void)testMultipleChildrenMultipleStrings {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *childRef = [ref child:@"path"];
  childRef = [childRef child:@"to"];
  childRef = [childRef child:@"object"];
  XCTAssertEqualObjects([childRef stringValue], @"gs://bucket/path/to/object");
}

- (void)testSameChildDifferentRef {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *firstRef = [ref child:@"1"];
  FIRStorageReference *secondRef = [ref child:@"1"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/");
  XCTAssertEqualObjects(firstRef, secondRef);
  XCTAssertNotEqual(firstRef, secondRef);
}

- (void)testDifferentChildDifferentRef {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *firstRef = [ref child:@"1"];
  FIRStorageReference *secondRef = [ref child:@"2"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/");
  XCTAssertNotEqual(firstRef, secondRef);
}

- (void)testChildWithTrailingSlash {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object/"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/path/to/object");
}

- (void)testChildWithLeadingSlash {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket//path/to/object/"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/path/to/object");
}

- (void)testChildCompressSlashes {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket//path///to////object////"];
  XCTAssertEqualObjects([ref stringValue], @"gs://bucket/path/to/object");
}

- (void)testParent {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  FIRStorageReference *parentRef = [ref parent];
  XCTAssertEqualObjects([parentRef stringValue], @"gs://bucket/path/to");
}

- (void)testParentToRoot {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path"];
  FIRStorageReference *parentRef = [ref parent];
  XCTAssertEqualObjects([parentRef stringValue], @"gs://bucket/");
}

- (void)testParentToRootTrailingSlash {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/"];
  FIRStorageReference *parentRef = [ref parent];
  XCTAssertEqualObjects([parentRef stringValue], @"gs://bucket/");
}

- (void)testParentAtRoot {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *parentRef = [ref parent];
  XCTAssertNil(parentRef);
}

- (void)testBucket {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(ref.bucket, @"bucket");
}

- (void)testName {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(ref.name, @"object");
}

- (void)testNameNoObject {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  XCTAssertEqualObjects(ref.name, @"");
}

- (void)testFullPath {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(ref.fullPath, @"path/to/object");
}

- (void)testFullPathNoObject {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  XCTAssertEqualObjects(ref.fullPath, @"");
}

- (void)testCopy {
  FIRStorageReference *ref = [self.storage referenceForURL:@"gs://bucket/"];
  FIRStorageReference *copiedRef = [ref copy];
  XCTAssertEqualObjects(ref, copiedRef);
  XCTAssertNotEqual(ref, copiedRef);
}

- (void)testReferenceWithNonExistentFileFailsWithCompletion {
  NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.data"];
  FIRStorageReference *ref = [self.storage referenceWithPath:tempFilePath];

  NSURL *dummyFileURL = [NSURL fileURLWithPath:@"some_non_existing-folder/file.data"];

  XCTestExpectation *expectation = [self expectationWithDescription:@"completionExpectation"];

  [ref putFile:dummyFileURL
        metadata:nil
      completion:^(FIRStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertNil(metadata);

        XCTAssertEqualObjects(error.domain, FIRStorageErrorDomain);
        XCTAssertEqual(error.code, FIRStorageErrorCodeUnknown);
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
  FIRStorageReference *ref = [self.storage referenceWithPath:tempFilePath];

  NSURL *dummyFileURL = nil;

  XCTestExpectation *expectation = [self expectationWithDescription:@"completionExpectation"];

  [ref putFile:dummyFileURL
        metadata:nil
      completion:^(FIRStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
        [expectation fulfill];
        XCTAssertNotNil(error);
        XCTAssertNil(metadata);

        XCTAssertEqualObjects(error.domain, FIRStorageErrorDomain);
        XCTAssertEqual(error.code, FIRStorageErrorCodeUnknown);
        NSString *expectedDescription = [NSString
            stringWithFormat:@"File at URL: %@ is not reachable. "
                             @"Ensure file URL is not a directory, symbolic link, or invalid url.",
                             dummyFileURL.absoluteString];
        XCTAssertEqualObjects(error.localizedDescription, expectedDescription);
      }];

  [self waitForExpectationsWithTimeout:0.5 handler:NULL];
}

@end
