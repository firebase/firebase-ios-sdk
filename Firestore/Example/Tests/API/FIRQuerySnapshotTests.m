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

#import "FirebaseFirestore/FIRQuerySnapshot.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRQuerySnapshotTests : XCTestCase
@end

@implementation FIRQuerySnapshotTests

- (void)testEquals {
  FIRQuerySnapshot *foo = FSTTestQuerySnapshot(@"foo/bar", @[], @[ @{ @"a":@1 } ], YES, YES);
  FIRQuerySnapshot *fooDup = FSTTestQuerySnapshot(@"foo/bar", @[], @[ @{ @"a":@1 } ], YES, YES);
  FIRQuerySnapshot *bar = FSTTestQuerySnapshot(@"bar/foo", @[], @[ @{ @"a":@1 } ], YES, YES);
  FIRQuerySnapshot *baz = FSTTestQuerySnapshot(@"foo/bar", @[ @{ @"a":@1 } ], @[], YES, YES);
  FIRQuerySnapshot *qux = FSTTestQuerySnapshot(@"foo/bar", @[], @[ @{ @"b":@1 } ], NO, YES);
  FIRQuerySnapshot *quux = FSTTestQuerySnapshot(@"foo/bar", @[], @[ @{ @"b":@1 } ], YES, NO);
  NSArray *groups = @[ @[foo, fooDup], @[bar], @[baz], @[qux], @[quux]];
  FSTAssertEqualityGroups(groups);

  NSArray *hashGroups = @[ @[[NSNumber numberWithLong:[foo hash]], [NSNumber numberWithLong:[fooDup hash]] ],
      @[ [NSNumber numberWithLong:[bar hash]] ], @[ [NSNumber numberWithLong:[baz hash]] ],
      @[ [NSNumber numberWithLong:[qux hash]] ], @[ [NSNumber numberWithLong:[quux hash]]  ]];
  FSTAssertEqualityGroups(hashGroups);
}

@end

NS_ASSUME_NONNULL_END
