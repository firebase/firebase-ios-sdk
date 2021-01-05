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

#import "FirebaseStorage/Sources/FIRStorageUtils.h"

#import "FirebaseStorage/Sources/FIRStoragePath.h"

@interface FIRStorageUtilsTests : XCTestCase

@end

@implementation FIRStorageUtilsTests

- (void)testCommonExtensionToMIMEType {
  NSDictionary<NSString *, NSString *> *extensionToMIMEType = @{
    @"txt" : @"text/plain",
    @"png" : @"image/png",
    @"mp3" : @"audio/mpeg",
    @"mov" : @"video/quicktime",
    @"gif" : @"image/gif"
  };
  [extensionToMIMEType
      enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull extension, NSString *_Nonnull MIMEType,
                                          BOOL *_Nonnull stop) {
        XCTAssertEqualObjects([FIRStorageUtils MIMETypeForExtension:extension], MIMEType);
      }];
}

- (void)testParseGoodDataToDict {
  NSString *JSONString = @"{\"hello\" : \"world\"}";
  NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *JSONDictionary = [NSDictionary frs_dictionaryFromJSONData:JSONData];
  NSDictionary *expectedDictionary = @{@"hello" : @"world"};
  XCTAssertEqualObjects(JSONDictionary, expectedDictionary);
}

- (void)testParseBadDataToDict {
  NSString *JSONString = @"Invalid JSON Object";
  NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *JSONDictionary = [NSDictionary frs_dictionaryFromJSONData:JSONData];
  XCTAssertNil(JSONDictionary);
}

- (void)testParseNilToDict {
  NSDictionary *JSONDictionary = [NSDictionary frs_dictionaryFromJSONData:nil];
  XCTAssertNil(JSONDictionary);
}

- (void)testParseGoodDictToData {
  NSDictionary *JSONDictionary = @{@"hello" : @"world"};
  NSData *expectedData = [NSData frs_dataFromJSONDictionary:JSONDictionary];
  NSString *JSONString = [[NSString alloc] initWithData:expectedData encoding:NSUTF8StringEncoding];
  NSString *expectedString = @"{\"hello\":\"world\"}";
  XCTAssertEqualObjects(JSONString, expectedString);
}

- (void)testParseNilToData {
  NSData *JSONData = [NSData frs_dataFromJSONDictionary:nil];
  XCTAssertNil(JSONData);
}

- (void)testNilDictToQueryString {
  NSDictionary *params;
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"");
}

- (void)testEmptyDictToQueryString {
  NSDictionary *params = @{};
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"");
}

- (void)testSingleItemToQueryString {
  NSDictionary *params = @{@"foo" : @"bar"};
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"foo=bar");
}

- (void)testMultiItemDictToQueryString {
  NSDictionary *params = @{@"foo" : @"bar", @"baz" : @"qux"};
  NSString *queryString = [FIRStorageUtils queryStringForDictionary:params];
  XCTAssertEqualObjects(queryString, @"foo=bar&baz=qux");
}

- (void)testDefaultRequestForFullPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  NSURLRequest *request = [FIRStorageUtils defaultRequestForPath:path];
  XCTAssertEqualObjects([request.URL absoluteString],
                        @"https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Fobject");
}

- (void)testDefaultRequestForNoPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  NSURLRequest *request = [FIRStorageUtils defaultRequestForPath:path];
  XCTAssertEqualObjects([request.URL absoluteString],
                        @"https://firebasestorage.googleapis.com/v0/b/bucket/o");
}

- (void)testEncodedURLForFullPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:@"path/to/object"];
  NSString *encodedURL = [FIRStorageUtils encodedURLForPath:path];
  XCTAssertEqualObjects(encodedURL, @"/v0/b/bucket/o/path%2Fto%2Fobject");
}

- (void)testEncodedURLForNoPath {
  FIRStoragePath *path = [[FIRStoragePath alloc] initWithBucket:@"bucket" object:nil];
  NSString *encodedURL = [FIRStorageUtils encodedURLForPath:path];
  XCTAssertEqualObjects(encodedURL, @"/v0/b/bucket/o");
}

- (void)testTranslateRetryTime {
  // The 1st retry attempt runs after 1 second.
  // The 2nd retry attempt is delayed by 2 seconds (3s total)
  // The 3rd retry attempt is delayed by 4 seconds (7s total)
  // The 4th retry attempt is delayed by 8 seconds (15s total)
  // The 5th retry attempt is delayed by 16 seconds (31s total)
  // The 6th retry attempt is delayed by 32 seconds (63s total)
  // Thus, we should exit just between the 5th and 6th retry attempt and cut off before 32s.
  XCTAssertEqual(32.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:60.0]);

  XCTAssertEqual(1.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:1.0]);
  XCTAssertEqual(2.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:2.0]);
  XCTAssertEqual(4.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:4.0]);
  XCTAssertEqual(8.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:10.0]);
  XCTAssertEqual(16.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:20.0]);
  XCTAssertEqual(16.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:30.0]);
  XCTAssertEqual(32.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:40.0]);
  XCTAssertEqual(32.0, [FIRStorageUtils computeRetryIntervalFromRetryTime:50.0]);
}

@end
