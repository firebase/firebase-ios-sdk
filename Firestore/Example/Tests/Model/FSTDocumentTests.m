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

#import "Firestore/Source/Model/FSTDocument.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentTests : XCTestCase
@end

@implementation FSTDocumentTests

- (void)testConstructor {
  FSTDocumentKey *key = FSTTestDocKey(@"messages/first");
  FSTSnapshotVersion *version = FSTTestVersion(1);
  FSTObjectValue *data = FSTTestObjectValue(@{ @"a" : @1 });
  FSTDocument *doc =
      [FSTDocument documentWithData:data key:key version:version hasLocalMutations:NO];

  XCTAssertEqualObjects(doc.key, FSTTestDocKey(@"messages/first"));
  XCTAssertEqualObjects(doc.version, version);
  XCTAssertEqualObjects(doc.data, data);
  XCTAssertEqual(doc.hasLocalMutations, NO);
}

- (void)testExtractsFields {
  FSTDocumentKey *key = FSTTestDocKey(@"rooms/eros");
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
  XCTAssertEqualObjects(FSTTestDoc(@"messages/first", 1,
                                   @{ @"a" : @1 }, NO),
                        FSTTestDoc(@"messages/first", 1,
                                   @{ @"a" : @1 }, NO));
  XCTAssertNotEqualObjects(FSTTestDoc(@"messages/first", 1,
                                      @{ @"a" : @1 }, NO),
                           FSTTestDoc(@"messages/first", 1,
                                      @{ @"b" : @1 }, NO));
  XCTAssertNotEqualObjects(FSTTestDoc(@"messages/first", 1,
                                      @{ @"a" : @1 }, NO),
                           FSTTestDoc(@"messages/second", 1,
                                      @{ @"b" : @1 }, NO));
  XCTAssertNotEqualObjects(FSTTestDoc(@"messages/first", 1,
                                      @{ @"a" : @1 }, NO),
                           FSTTestDoc(@"messages/first", 2,
                                      @{ @"a" : @1 }, NO));
  XCTAssertNotEqualObjects(FSTTestDoc(@"messages/first", 1,
                                      @{ @"a" : @1 }, NO),
                           FSTTestDoc(@"messages/first", 1,
                                      @{ @"a" : @1 }, YES));

  XCTAssertEqualObjects(FSTTestDoc(@"messages/first", 1,
                                   @{ @"a" : @1 }, YES),
                        FSTTestDoc(@"messages/first", 1,
                                   @{ @"a" : @1 }, 5));
}

@end

NS_ASSUME_NONNULL_END
