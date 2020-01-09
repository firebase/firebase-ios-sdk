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

#import <XCTest/XCTest.h>

#import "FirebaseStorage/Sources/FIRStoragePath.h"

@interface FIRStoragePathTests : XCTestCase

@end

@implementation FIRStoragePathTests

- (void)testGSURI {
  FIRStoragePath *path = [FIRStoragePath pathFromString:@"gs://bucket/path/to/object"];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertEqualObjects(path.object, @"path/to/object");
}

- (void)testHTTPURL {
  NSString *httpURL =
      @"http://firebasestorage.googleapis.com/v0/b/bucket/o/path/to/object?token=signed_url_params";
  FIRStoragePath *path = [FIRStoragePath pathFromString:httpURL];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertEqualObjects(path.object, @"path/to/object");
}

- (void)testGSURINoPath {
  FIRStoragePath *path = [FIRStoragePath pathFromString:@"gs://bucket/"];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertNil(path.object);
}

- (void)testHTTPURLNoPath {
  FIRStoragePath *path =
      [FIRStoragePath pathFromString:@"http://firebasestorage.googleapis.com/v0/b/bucket/"];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertNil(path.object);
}

- (void)testGSURINoTrailingSlash {
  FIRStoragePath *path = [FIRStoragePath pathFromString:@"gs://bucket"];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertNil(path.object);
}

- (void)testHTTPURLNoTrailingSlash {
  FIRStoragePath *path =
      [FIRStoragePath pathFromString:@"http://firebasestorage.googleapis.com/v0/b/bucket"];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertNil(path.object);
}

- (void)testGSURIPercentEncoding {
  FIRStoragePath *path = [FIRStoragePath pathFromString:@"gs://bucket/?/%/#"];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertEqualObjects(path.object, @"?/%/#");
}

- (void)testHTTPURLPercentEncoding {
  NSString *httpURL =
      @"http://firebasestorage.googleapis.com/v0/b/bucket/o/%3F/%25/%23?token=signed_url_params";
  FIRStoragePath *path = [FIRStoragePath pathFromString:httpURL];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertEqualObjects(path.object, @"?/%/#");
}

- (void)testHTTPURLNoToken {
  NSString *httpURL = @"http://firebasestorage.googleapis.com/v0/b/bucket/o/%23hashtag/no/token";
  FIRStoragePath *path = [FIRStoragePath pathFromString:httpURL];
  XCTAssertEqualObjects(path.bucket, @"bucket");
  XCTAssertEqualObjects(path.object, @"#hashtag/no/token");
}

- (void)testGSURIThrowsOnNoBucket {
  XCTAssertThrows([FIRStoragePath pathFromString:@"gs://"]);
}

- (void)testHTTPURLThrowsOnNoBucket {
  XCTAssertThrows([FIRStoragePath pathFromString:@"http://firebasestorage.googleapis.com/"]);
}

- (void)testThrowsOnInvalidScheme {
  NSString *ftpURL = @"ftp://firebasestorage.googleapis.com/v0/b/bucket/o/path/to/object";
  XCTAssertThrows([FIRStoragePath pathFromString:ftpURL]);
}

- (void)testHTTPURLNilIncorrectHost {
  NSString *httpURL = @"http://foo.google.com/v0/b/bucket/o/%3F/%25/%23?token=signed_url_params";
  XCTAssertThrows([FIRStoragePath pathFromString:httpURL]);
}

- (void)testchildToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"object"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/object");
}

- (void)testChildByAppendingNilToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRStoragePath *childPath = [path child:nil];
#pragma clang diagnostic pop
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/");
}

- (void)testChildByAppendingNoPathToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@""];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/");
}

- (void)testChildByAppendingLeadingSlashChildToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"/object"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/object");
}

- (void)testChildByAppendingTrailingSlashChildToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"object/"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/object");
}

- (void)testChildByAppendingLeadingAndTrailingSlashChildToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"/object/"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/object");
}

- (void)testChildByAppendingMultipleChildrenToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"path/to/object"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/path/to/object");
}

- (void)testChildByAppendingMultipleChildrenWithMultipleSlashesToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"/path//to///object////"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/path/to/object");
}

- (void)testChildByAppendingOnlySlashesToRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *childPath = [path child:@"//////////"];
  XCTAssertEqualObjects([childPath stringValue], @"gs://bucket/");
}

- (void)testParentAtRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *parent = [path parent];
  XCTAssertNil(parent);
}

- (void)testParentChildPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRStoragePath *parent = [path parent];
  XCTAssertEqualObjects([parent stringValue], @"gs://bucket/path/to");
}

- (void)testParentChildPathSlashes {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"/path//to///"];
  FIRStoragePath *parent = [path parent];
  XCTAssertEqualObjects([parent stringValue], @"gs://bucket/path");
}

- (void)testParentChildPathOnlySlashs {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"/////"];
  FIRStoragePath *parent = [path parent];
  XCTAssertNil(parent);
}

- (void)testRootAtRoot {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *root = [path root];
  XCTAssertEqualObjects([root stringValue], @"gs://bucket/");
}

- (void)testRootAtChildPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  FIRStoragePath *root = [path root];
  XCTAssertEqualObjects([root stringValue], @"gs://bucket/");
}

- (void)testRootAtSlashPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"//////////"];
  FIRStoragePath *root = [path root];
  XCTAssertEqualObjects([root stringValue], @"gs://bucket/");
}

- (void)testCopy {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"object"];
  FIRStoragePath *copiedPath = [path copy];
  XCTAssertNotEqual(copiedPath, path);
  XCTAssertEqualObjects(copiedPath, path);
}

- (void)testCopyNoBucket {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:nil object:@"object"];
#pragma clang diagnostic pop
  FIRStoragePath *copiedPath = [path copy];
  XCTAssertNotEqual(copiedPath, path);
  XCTAssertEqualObjects(copiedPath, path);
}

- (void)testCopyNoObject {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  FIRStoragePath *copiedPath = [path copy];
  XCTAssertNotEqual(copiedPath, path);
  XCTAssertEqualObjects(copiedPath, path);
}

- (void)testCopyNothing {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:nil object:nil];
#pragma clang diagnostic pop
  FIRStoragePath *copiedPath = [path copy];
  XCTAssertNotEqual(copiedPath, path);
  XCTAssertEqualObjects(copiedPath, path);
}

@end
