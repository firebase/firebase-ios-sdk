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

#import "Firestore/Source/Model/FSTDocumentSet.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentSetTests : XCTestCase
@end

@implementation FSTDocumentSetTests {
  NSComparator _comp;
  FSTDocument *_doc1;
  FSTDocument *_doc2;
  FSTDocument *_doc3;
}

- (void)setUp {
  [super setUp];

  _comp = FSTTestDocComparator(@"sort");
  _doc1 = FSTTestDoc(@"docs/1", 0, @{ @"sort" : @2 }, NO);
  _doc2 = FSTTestDoc(@"docs/2", 0, @{ @"sort" : @3 }, NO);
  _doc3 = FSTTestDoc(@"docs/3", 0, @{ @"sort" : @1 }, NO);
}

- (void)testCount {
  XCTAssertEqual([FSTTestDocSet(_comp, @[]) count], 0);
  XCTAssertEqual([FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]) count], 3);
}

- (void)testHasKey {
  FSTDocumentSet *set = FSTTestDocSet(_comp, @[ _doc1, _doc2 ]);

  XCTAssertTrue([set containsKey:_doc1.key]);
  XCTAssertTrue([set containsKey:_doc2.key]);
  XCTAssertFalse([set containsKey:_doc3.key]);
}

- (void)testDocumentForKey {
  FSTDocumentSet *set = FSTTestDocSet(_comp, @[ _doc1, _doc2 ]);

  XCTAssertEqualObjects([set documentForKey:_doc1.key], _doc1);
  XCTAssertEqualObjects([set documentForKey:_doc2.key], _doc2);
  XCTAssertNil([set documentForKey:_doc3.key]);
}

- (void)testFirstAndLastDocument {
  FSTDocumentSet *set = FSTTestDocSet(_comp, @[]);
  XCTAssertNil([set firstDocument]);
  XCTAssertNil([set lastDocument]);

  set = FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqualObjects([set firstDocument], _doc3);
  XCTAssertEqualObjects([set lastDocument], _doc2);
}

- (void)testKeepsDocumentsInTheRightOrder {
  FSTDocumentSet *set = FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqualObjects([[set documentEnumerator] allObjects], (@[ _doc3, _doc1, _doc2 ]));
}

- (void)testDeletes {
  FSTDocumentSet *set = FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]);

  FSTDocumentSet *setWithoutDoc1 = [set documentSetByRemovingKey:_doc1.key];
  XCTAssertEqualObjects([[setWithoutDoc1 documentEnumerator] allObjects], (@[ _doc3, _doc2 ]));
  XCTAssertEqual([setWithoutDoc1 count], 2);

  // Original remains unchanged
  XCTAssertEqualObjects([[set documentEnumerator] allObjects], (@[ _doc3, _doc1, _doc2 ]));

  FSTDocumentSet *setWithoutDoc3 = [setWithoutDoc1 documentSetByRemovingKey:_doc3.key];
  XCTAssertEqualObjects([[setWithoutDoc3 documentEnumerator] allObjects], (@[ _doc2 ]));
  XCTAssertEqual([setWithoutDoc3 count], 1);
}

- (void)testUpdates {
  FSTDocumentSet *set = FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]);

  FSTDocument *doc2Prime = FSTTestDoc(@"docs/2", 0, @{ @"sort" : @9 }, NO);

  set = [set documentSetByAddingDocument:doc2Prime];
  XCTAssertEqual([set count], 3);
  XCTAssertEqualObjects([set documentForKey:doc2Prime.key], doc2Prime);
  XCTAssertEqualObjects([[set documentEnumerator] allObjects], (@[ _doc3, _doc1, doc2Prime ]));
}

- (void)testAddsDocsWithEqualComparisonValues {
  FSTDocument *doc4 = FSTTestDoc(@"docs/4", 0, @{ @"sort" : @2 }, NO);

  FSTDocumentSet *set = FSTTestDocSet(_comp, @[ _doc1, doc4 ]);
  XCTAssertEqualObjects([[set documentEnumerator] allObjects], (@[ _doc1, doc4 ]));
}

- (void)testIsEqual {
  FSTDocumentSet *set1 = FSTTestDocSet(FSTDocumentComparatorByKey, @[ _doc1, _doc2, _doc3 ]);
  FSTDocumentSet *set2 = FSTTestDocSet(FSTDocumentComparatorByKey, @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqualObjects(set1, set1);
  XCTAssertEqualObjects(set1, set2);
  XCTAssertNotEqualObjects(set1, nil);

  FSTDocumentSet *sortedSet1 = FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]);
  FSTDocumentSet *sortedSet2 = FSTTestDocSet(_comp, @[ _doc1, _doc2, _doc3 ]);
  XCTAssertEqualObjects(sortedSet1, sortedSet1);
  XCTAssertEqualObjects(sortedSet1, sortedSet2);
  XCTAssertNotEqualObjects(sortedSet1, nil);

  FSTDocumentSet *shortSet = FSTTestDocSet(FSTDocumentComparatorByKey, @[ _doc1, _doc2 ]);
  XCTAssertNotEqualObjects(set1, shortSet);
  XCTAssertNotEqualObjects(set1, sortedSet1);
}
@end

NS_ASSUME_NONNULL_END
