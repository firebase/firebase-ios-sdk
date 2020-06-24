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

#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"
#import "FirebaseDatabase/Sources/Persistence/FPruneForest.h"

@interface FPruneForestTest : XCTestCase

@end

@implementation FPruneForestTest

- (void)testEmptyDoesNotAffectAnyPaths {
  FPruneForest *forest = [FPruneForest empty];
  XCTAssertFalse([forest affectsPath:[FPath empty]]);
  XCTAssertFalse([forest affectsPath:[FPath pathWithString:@"foo"]]);
}

- (void)testPruneAffectsPath {
  FPruneForest *forest = [FPruneForest empty];
  forest = [forest prunePath:[FPath pathWithString:@"foo/bar"]];
  forest = [forest keepPath:[FPath pathWithString:@"foo/bar/baz"]];
  XCTAssertTrue([forest affectsPath:[FPath pathWithString:@"foo"]]);
  XCTAssertFalse([forest affectsPath:[FPath pathWithString:@"baz"]]);
  XCTAssertFalse([forest affectsPath:[FPath pathWithString:@"baz/bar"]]);
  XCTAssertTrue([forest affectsPath:[FPath pathWithString:@"foo/bar"]]);
  XCTAssertTrue([forest affectsPath:[FPath pathWithString:@"foo/bar/baz"]]);
  XCTAssertTrue([forest affectsPath:[FPath pathWithString:@"foo/bar/qux"]]);
}

- (void)testPruneAnythingWorks {
  FPruneForest *empty = [FPruneForest empty];
  XCTAssertFalse([empty prunesAnything]);
  XCTAssertTrue([[empty prunePath:[FPath pathWithString:@"foo"]] prunesAnything]);
  XCTAssertFalse([[[empty prunePath:[FPath pathWithString:@"foo/bar"]]
      keepPath:[FPath pathWithString:@"foo"]] prunesAnything]);
  XCTAssertTrue([[[empty prunePath:[FPath pathWithString:@"foo"]]
      keepPath:[FPath pathWithString:@"foo/bar"]] prunesAnything]);
}

- (void)testKeepUnderPruneWorks {
  FPruneForest *forest = [FPruneForest empty];
  forest = [forest prunePath:[FPath pathWithString:@"foo/bar"]];
  forest = [forest keepPath:[FPath pathWithString:@"foo/bar/baz"]];
  [forest keepAll:[NSSet setWithArray:@[ @"qux", @"quu" ]]
           atPath:[FPath pathWithString:@"foo/bar"]];
}

- (void)testPruneUnderKeepThrows {
  FPruneForest *forest = [FPruneForest empty];
  forest = [forest prunePath:[FPath pathWithString:@"foo"]];
  forest = [forest keepPath:[FPath pathWithString:@"foo/bar"]];
  XCTAssertThrows([forest prunePath:[FPath pathWithString:@"foo/bar/baz"]]);
  NSSet *children = [NSSet setWithArray:@[ @"qux", @"quu" ]];
  XCTAssertThrows([forest pruneAll:children atPath:[FPath pathWithString:@"foo/bar"]]);
}

- (void)testChildKeepsPruneInfo {
  FPruneForest *forest = [FPruneForest empty];
  forest = [forest keepPath:[FPath pathWithString:@"foo/bar"]];
  XCTAssertTrue([[forest child:@"foo"] affectsPath:[FPath pathWithString:@"bar"]]);
  XCTAssertTrue([[[forest child:@"foo"] child:@"bar"] affectsPath:[FPath pathWithString:@""]]);
  XCTAssertTrue(
      [[[[forest child:@"foo"] child:@"bar"] child:@"baz"] affectsPath:[FPath pathWithString:@""]]);

  forest = [[FPruneForest empty] prunePath:[FPath pathWithString:@"foo/bar"]];
  XCTAssertTrue([[forest child:@"foo"] affectsPath:[FPath pathWithString:@"bar"]]);
  XCTAssertTrue([[[forest child:@"foo"] child:@"bar"] affectsPath:[FPath pathWithString:@""]]);
  XCTAssertTrue(
      [[[[forest child:@"foo"] child:@"bar"] child:@"baz"] affectsPath:[FPath pathWithString:@""]]);

  XCTAssertFalse([[forest child:@"non-existent"] affectsPath:[FPath pathWithString:@""]]);
}

- (void)testShouldPruneWorks {
  FPruneForest *forest = [FPruneForest empty];
  forest = [forest prunePath:[FPath pathWithString:@"foo"]];
  forest = [forest keepPath:[FPath pathWithString:@"foo/bar/baz"]];
  XCTAssertTrue([forest shouldPruneUnkeptDescendantsAtPath:[FPath pathWithString:@"foo"]]);
  XCTAssertTrue([forest shouldPruneUnkeptDescendantsAtPath:[FPath pathWithString:@"foo/bar"]]);
  XCTAssertFalse([forest shouldPruneUnkeptDescendantsAtPath:[FPath pathWithString:@"foo/bar/baz"]]);
  XCTAssertFalse([forest shouldPruneUnkeptDescendantsAtPath:[FPath pathWithString:@"qux"]]);
}

@end
