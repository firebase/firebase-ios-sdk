/*
 * Copyright 2023 Google LLC
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

#import <FirebaseFirestore/FIRAggregateQuery.h>

#import <FirebaseFirestore/FIRQuery.h>

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

namespace api = firebase::firestore::api;
using firebase::firestore::testutil::Query;

NS_ASSUME_NONNULL_BEGIN

@interface FIRAggregateQueryUnitTests : XCTestCase
@end

@implementation FIRAggregateQueryUnitTests

- (void)testEquals {
  std::shared_ptr<api::Firestore> firestore = FSTTestFirestore().wrapped;
  FIRAggregateQuery *queryFoo =
      [[FIRQuery alloc] initWithQuery:Query("foo") firestore:firestore].count;
  FIRAggregateQuery *queryFooDup =
      [[FIRQuery alloc] initWithQuery:Query("foo") firestore:firestore].count;
  FIRAggregateQuery *queryBar =
      [[FIRQuery alloc] initWithQuery:Query("bar") firestore:firestore].count;
  XCTAssertEqualObjects(queryFoo, queryFooDup);
  XCTAssertNotEqualObjects(queryFoo, queryBar);

  XCTAssertEqual([queryFoo hash], [queryFooDup hash]);
  XCTAssertNotEqual([queryFoo hash], [queryBar hash]);
}

@end

NS_ASSUME_NONNULL_END
