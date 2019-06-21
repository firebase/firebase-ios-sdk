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

#import <XCTest/XCTest.h>

#include <vector>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Model/FSTDocument.h"

// TODO(wilhuff) move to first include once this test filename matches
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"

namespace util = firebase::firestore::util;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using testing::ElementsAre;

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentSetTests : XCTestCase
@end

@implementation FSTDocumentSetTests {
  util::DelayedConstructor<DocumentComparator> _comp;
  FSTDocument *_doc1;
  FSTDocument *_doc2;
  FSTDocument *_doc3;
}

- (void)setUp {
  [super setUp];

  _comp.Init(FSTTestDocComparator("sort"));
  _doc1 = FSTTestDoc("docs/1", 0, @{@"sort" : @2}, DocumentState::kSynced);
  _doc2 = FSTTestDoc("docs/2", 0, @{@"sort" : @3}, DocumentState::kSynced);
  _doc3 = FSTTestDoc("docs/3", 0, @{@"sort" : @1}, DocumentState::kSynced);
}

- (void)testCount {
  XCTAssertEqual(FSTTestDocSet(*_comp, @[]).size(), 0);
  XCTAssertEqual(FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]).size(), 3);
}

- (void)testHasKey {
  DocumentSet set = FSTTestDocSet(*_comp, @[ _doc1, _doc2 ]);

  XCTAssertTrue(set.ContainsKey(_doc1.key));
  XCTAssertTrue(set.ContainsKey(_doc2.key));
  XCTAssertFalse(set.ContainsKey(_doc3.key));
}

- (void)testDocumentForKey {
  DocumentSet set = FSTTestDocSet(*_comp, @[ _doc1, _doc2 ]);

  XCTAssertEqualObjects(set.GetDocument(_doc1.key), _doc1);
  XCTAssertEqualObjects(set.GetDocument(_doc2.key), _doc2);
  XCTAssertNil(set.GetDocument(_doc3.key));
}

- (void)testFirstAndLastDocument {
  DocumentSet set = FSTTestDocSet(*_comp, @[]);
  XCTAssertNil(set.GetFirstDocument());
  XCTAssertNil(set.GetLastDocument());

  set = FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqualObjects(set.GetFirstDocument(), _doc3);
  XCTAssertEqualObjects(set.GetLastDocument(), _doc2);
}

- (void)testKeepsDocumentsInTheRightOrder {
  DocumentSet set = FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]);
  XC_ASSERT_THAT(set, ElementsAre(_doc3, _doc1, _doc2));
}

- (void)testDeletes {
  DocumentSet set = FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]);

  DocumentSet setWithoutDoc1 = set.erase(_doc1.key);
  XC_ASSERT_THAT(setWithoutDoc1, ElementsAre(_doc3, _doc2));
  XCTAssertEqual(setWithoutDoc1.size(), 2);

  // Original remains unchanged
  XC_ASSERT_THAT(set, ElementsAre(_doc3, _doc1, _doc2));

  DocumentSet setWithoutDoc3 = setWithoutDoc1.erase(_doc3.key);
  XC_ASSERT_THAT(setWithoutDoc3, ElementsAre(_doc2));
  XCTAssertEqual(setWithoutDoc3.size(), 1);
}

- (void)testUpdates {
  DocumentSet set = FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]);

  FSTDocument *doc2Prime = FSTTestDoc("docs/2", 0, @{@"sort" : @9}, DocumentState::kSynced);

  set = set.insert(doc2Prime);
  XCTAssertEqual(set.size(), 3);
  XCTAssertEqualObjects(set.GetDocument(doc2Prime.key), doc2Prime);
  XC_ASSERT_THAT(set, ElementsAre(_doc3, _doc1, doc2Prime));
}

- (void)testAddsDocsWithEqualComparisonValues {
  FSTDocument *doc4 = FSTTestDoc("docs/4", 0, @{@"sort" : @2}, DocumentState::kSynced);

  DocumentSet set = FSTTestDocSet(*_comp, @[ _doc1, doc4 ]);
  XC_ASSERT_THAT(set, ElementsAre(_doc1, doc4));
}

- (void)testIsEqual {
  DocumentSet empty{DocumentComparator::ByKey()};
  DocumentSet set1 = FSTTestDocSet(DocumentComparator::ByKey(), @[ _doc1, _doc2, _doc3 ]);
  DocumentSet set2 = FSTTestDocSet(DocumentComparator::ByKey(), @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqual(set1, set1);
  XCTAssertEqual(set1, set2);
  XCTAssertNotEqual(set1, empty);

  DocumentSet sortedSet1 = FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]);
  DocumentSet sortedSet2 = FSTTestDocSet(*_comp, @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqual(sortedSet1, sortedSet1);
  XCTAssertEqual(sortedSet1, sortedSet2);
  XCTAssertNotEqual(sortedSet1, empty);

  DocumentSet shortSet = FSTTestDocSet(DocumentComparator::ByKey(), @[ _doc1, _doc2 ]);
  XCTAssertNotEqual(set1, shortSet);
  XCTAssertNotEqual(set1, sortedSet1);
}

@end

NS_ASSUME_NONNULL_END
