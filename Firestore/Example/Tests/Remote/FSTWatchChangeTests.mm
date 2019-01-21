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

#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/remote/existence_filter.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"

using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;

NS_ASSUME_NONNULL_BEGIN

@interface FSTWatchChangeTests : XCTestCase
@end

@implementation FSTWatchChangeTests

- (void)testDocumentChange {
  FSTMaybeDocument *doc = FSTTestDoc("a/b", 1, @{}, FSTDocumentStateSynced);
  DocumentWatchChange change{{1, 2, 3}, {4, 5}, doc.key, doc};

  XCTAssertEqual(change.updated_target_ids().size(), 3);
  XCTAssertEqual(change.removed_target_ids().size(), 2);
  // Testing object identity here is fine.
  XCTAssertEqual(change.new_document(), doc);
}

- (void)testExistenceFilterChange {
  ExistenceFilter filter{7};
  ExistenceFilterWatchChange change{filter, 5};
  XCTAssertEqual(change.filter().count(), 7);
  XCTAssertEqual(change.target_id(), 5);
}

- (void)testWatchTargetChange {
  WatchTargetChange change{WatchTargetChangeState::Reset,
                           {
                               1,
                               2,
                           }};
  XCTAssertEqual(change.state(), WatchTargetChangeState::Reset);
  XCTAssertEqual(change.target_ids().size(), 2);
}

@end

NS_ASSUME_NONNULL_END
