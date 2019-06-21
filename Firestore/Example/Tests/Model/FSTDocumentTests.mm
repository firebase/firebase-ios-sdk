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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::testutil::Field;

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentTests : XCTestCase
@end

@implementation FSTDocumentTests

- (void)testConstructor {
  DocumentKey key = testutil::Key("messages/first");
  SnapshotVersion version = testutil::Version(1);
  ObjectValue data = FSTTestObjectValue(@{@"a" : @1});
  FSTDocument *doc = [FSTDocument documentWithData:data
                                               key:key
                                           version:version
                                             state:DocumentState::kSynced];

  XCTAssertEqual(doc.key, FSTTestDocKey(@"messages/first"));
  XCTAssertEqual(doc.version, version);
  XCTAssertEqual(doc.data, data);
  XCTAssertEqual(doc.hasLocalMutations, NO);
}

- (void)testExtractsFields {
  DocumentKey key = testutil::Key("rooms/eros");
  SnapshotVersion version = testutil::Version(1);
  ObjectValue data = FSTTestObjectValue(@{
    @"desc" : @"Discuss all the project related stuff",
    @"owner" : @{@"name" : @"Jonny", @"title" : @"scallywag"}
  });
  FSTDocument *doc = [FSTDocument documentWithData:data
                                               key:key
                                           version:version
                                             state:DocumentState::kSynced];

  XCTAssertEqual(*[doc fieldForPath:Field("desc")],
                 FieldValue::FromString("Discuss all the project related stuff"));
  XCTAssertEqual(*[doc fieldForPath:Field("owner.title")], FieldValue::FromString("scallywag"));
}

- (void)testIsEqual {
  XCTAssertEqualObjects(FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kSynced),
                        FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kSynced));
  XCTAssertNotEqualObjects(FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kSynced),
                           FSTTestDoc("messages/first", 1, @{@"b" : @1}, DocumentState::kSynced));
  XCTAssertNotEqualObjects(FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kSynced),
                           FSTTestDoc("messages/second", 1, @{@"b" : @1}, DocumentState::kSynced));
  XCTAssertNotEqualObjects(FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kSynced),
                           FSTTestDoc("messages/first", 2, @{@"a" : @1}, DocumentState::kSynced));
  XCTAssertNotEqualObjects(
      FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kSynced),
      FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kLocalMutations));

  XCTAssertEqualObjects(
      FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kLocalMutations),
      FSTTestDoc("messages/first", 1, @{@"a" : @1}, DocumentState::kLocalMutations));
}

@end

NS_ASSUME_NONNULL_END
