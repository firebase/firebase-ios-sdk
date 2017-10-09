/*
 * Copyright 2017 Google
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

#import "Model/FSTDocument.h"

#import <XCTest/XCTest.h>

#import "Core/FSTSnapshotVersion.h"
#import "Model/FSTDocumentKey.h"
#import "Model/FSTFieldValue.h"
#import "Model/FSTPath.h"

#import "FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentTests : XCTestCase
@end

@implementation FSTDocumentTests

- (void)testConstructor {
  FSTDocumentKey *key = [FSTDocumentKey keyWithPathString:@"messages/first"];
  FSTSnapshotVersion *version = FSTTestVersion(1);
  FSTObjectValue *data = FSTTestObjectValue(@{ @"a" : @1 });
  FSTDocument *doc =
      [FSTDocument documentWithData:data key:key version:version hasLocalMutations:NO];

  XCTAssertEqualObjects(doc.key, [FSTDocumentKey keyWithPathString:@"messages/first"]);
  XCTAssertEqualObjects(doc.version, version);
  XCTAssertEqualObjects(doc.data, data);
  XCTAssertEqual(doc.hasLocalMutations, NO);
}

- (void)testExtractsFields {
  FSTDocumentKey *key = [FSTDocumentKey keyWithPathString:@"rooms/eros"];
  FSTSnapshotVersion *version = FSTTestVersion(1);
  FSTObjectValue *data = FSTTestObjectValue(@{
    @"desc" : @"Discuss all the project related stuff",
    @"owner" : @{@"name" : @"Jonny", @"title" : @"scallywag"}
  });
  FSTDocument *doc =
      [FSTDocument documentWithData:data key:key version:version hasLocalMutations:NO];

  XCTAssertEqualObjects([doc fieldForPath:FSTTestFieldPath(@"desc")],
                        [FSTStringValue stringValue:@"Discuss all the project related stuff"]);
  XCTAssertEqualObjects([doc fieldForPath:FSTTestFieldPath(@"owner.title")],
                        [FSTStringValue stringValue:@"scallywag"]);
}

- (void)testIsEqual {
  FSTDocumentKey *key1 = [FSTDocumentKey keyWithPathString:@"messages/first"];
  FSTDocumentKey *key2 = [FSTDocumentKey keyWithPathString:@"messages/second"];
  FSTObjectValue *data1 = FSTTestObjectValue(@{ @"a" : @1 });
  FSTObjectValue *data2 = FSTTestObjectValue(@{ @"b" : @1 });
  FSTSnapshotVersion *version1 = FSTTestVersion(1);

  FSTDocument *doc1 =
      [FSTDocument documentWithData:data1 key:key1 version:version1 hasLocalMutations:NO];
  FSTDocument *doc2 =
      [FSTDocument documentWithData:data1 key:key1 version:version1 hasLocalMutations:NO];

  XCTAssertEqualObjects(doc1, doc2);
  XCTAssertEqualObjects(
      doc1, [FSTDocument documentWithData:FSTTestObjectValue(
                                              @{ @"a" : @1 })
                                      key:[FSTDocumentKey keyWithPathString:@"messages/first"]
                                  version:version1
                        hasLocalMutations:NO]);

  FSTSnapshotVersion *version2 = FSTTestVersion(2);
  XCTAssertNotEqualObjects(
      doc1, [FSTDocument documentWithData:data2 key:key1 version:version1 hasLocalMutations:NO]);
  XCTAssertNotEqualObjects(
      doc1, [FSTDocument documentWithData:data1 key:key2 version:version1 hasLocalMutations:NO]);
  XCTAssertNotEqualObjects(
      doc1, [FSTDocument documentWithData:data1 key:key1 version:version2 hasLocalMutations:NO]);
  XCTAssertNotEqualObjects(
      doc1, [FSTDocument documentWithData:data1 key:key1 version:version1 hasLocalMutations:YES]);

  XCTAssertEqualObjects(
      [FSTDocument documentWithData:data1 key:key1 version:version1 hasLocalMutations:YES],
      [FSTDocument documentWithData:data1 key:key1 version:version1 hasLocalMutations:5]);
}

@end

NS_ASSUME_NONNULL_END
