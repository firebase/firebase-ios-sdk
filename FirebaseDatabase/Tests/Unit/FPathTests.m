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

#import "FirebaseDatabase/Tests/Unit/FPathTests.h"
#import "FirebaseDatabase/Sources/Core/Utilities/FPath.h"

@implementation FPathTests

- (void)testContains {
  XCTAssertTrue([[[FPath alloc] initWith:@"/"] contains:[[FPath alloc] initWith:@"/a/b/c"]],
                @"contains should be correct");
  XCTAssertTrue([[[FPath alloc] initWith:@"/a"] contains:[[FPath alloc] initWith:@"/a/b/c"]],
                @"contains should be correct");
  XCTAssertTrue([[[FPath alloc] initWith:@"/a/b"] contains:[[FPath alloc] initWith:@"/a/b/c"]],
                @"contains should be correct");
  XCTAssertTrue([[[FPath alloc] initWith:@"/a/b/c"] contains:[[FPath alloc] initWith:@"/a/b/c"]],
                @"contains should be correct");

  XCTAssertFalse([[[FPath alloc] initWith:@"/a/b/c"] contains:[[FPath alloc] initWith:@"/a/b"]],
                 @"contains should be correct");
  XCTAssertFalse([[[FPath alloc] initWith:@"/a/b/c"] contains:[[FPath alloc] initWith:@"/a"]],
                 @"contains should be correct");
  XCTAssertFalse([[[FPath alloc] initWith:@"/a/b/c"] contains:[[FPath alloc] initWith:@"/"]],
                 @"contains should be correct");

  NSArray *pathPieces = @[ @"a", @"b", @"c" ];

  XCTAssertTrue([[[FPath alloc] initWithPieces:pathPieces
                                   andPieceNum:1] contains:[[FPath alloc] initWith:@"/b/c"]],
                @"contains should be correct");
  XCTAssertTrue([[[FPath alloc] initWithPieces:pathPieces
                                   andPieceNum:1] contains:[[FPath alloc] initWith:@"/b/c/d"]],
                @"contains should be correct");

  XCTAssertFalse([[[FPath alloc] initWith:@"/a/b/c"] contains:[[FPath alloc] initWith:@"/b/c"]],
                 @"contains should be correct");
  XCTAssertFalse([[[FPath alloc] initWith:@"/a/b/c"] contains:[[FPath alloc] initWith:@"/a/c/b"]],
                 @"contains should be correct");

  XCTAssertFalse([[[FPath alloc] initWithPieces:pathPieces
                                    andPieceNum:1] contains:[[FPath alloc] initWith:@"/a/b/c"]],
                 @"contains should be correct");
  XCTAssertTrue([[[FPath alloc] initWithPieces:pathPieces
                                   andPieceNum:1] contains:[[FPath alloc] initWith:@"/b/c"]],
                @"contains should be correct");
  XCTAssertTrue([[[FPath alloc] initWithPieces:pathPieces
                                   andPieceNum:1] contains:[[FPath alloc] initWith:@"/b/c/d"]],
                @"contains should be correct");
}

- (void)testPopFront {
  XCTAssertEqualObjects([[[FPath alloc] initWith:@"/a/b/c"] popFront],
                        [[FPath alloc] initWith:@"/b/c"], @"should be correct");
  XCTAssertEqualObjects([[[[FPath alloc] initWith:@"/a/b/c"] popFront] popFront],
                        [[FPath alloc] initWith:@"/c"], @"should be correct");
  XCTAssertEqualObjects([[[[[FPath alloc] initWith:@"/a/b/c"] popFront] popFront] popFront],
                        [[FPath alloc] initWith:@"/"], @"should be correct");
  XCTAssertEqualObjects(
      [[[[[[FPath alloc] initWith:@"/a/b/c"] popFront] popFront] popFront] popFront],
      [[FPath alloc] initWith:@"/"], @"should be correct");
}

- (void)testParent {
  XCTAssertEqualObjects([[[FPath alloc] initWith:@"/a/b/c"] parent],
                        [[FPath alloc] initWith:@"/a/b/"], @"should be correct");
  XCTAssertEqualObjects([[[[FPath alloc] initWith:@"/a/b/c"] parent] parent],
                        [[FPath alloc] initWith:@"/a/"], @"should be correct");
  XCTAssertEqualObjects([[[[[FPath alloc] initWith:@"/a/b/c"] parent] parent] parent],
                        [[FPath alloc] initWith:@"/"], @"should be correct");
  XCTAssertNil([[[[[[FPath alloc] initWith:@"/a/b/c"] parent] parent] parent] parent],
               @"should be correct");
}

- (void)testWireFormat {
  XCTAssertEqualObjects(@"/", [[FPath empty] wireFormat]);
  XCTAssertEqualObjects(@"a/b/c", [[[FPath alloc] initWith:@"/a/b//c/"] wireFormat]);
  XCTAssertEqualObjects(@"b/c", [[[[FPath alloc] initWith:@"/a/b//c/"] popFront] wireFormat]);
}

- (void)testComparison {
  NSArray *pathsInOrder = @[
    @"1", @"2", @"10", @"a", @"a/1", @"a/2", @"a/10", @"a/a", @"a/aa", @"a/b", @"a/b/c", @"b",
    @"b/a"
  ];
  for (NSInteger i = 0; i < pathsInOrder.count; i++) {
    FPath *path1 = PATH(pathsInOrder[i]);
    for (NSInteger j = i + 1; j < pathsInOrder.count; j++) {
      FPath *path2 = PATH(pathsInOrder[j]);
      XCTAssertEqual([path1 compare:path2], NSOrderedAscending);
      XCTAssertEqual([path2 compare:path1], NSOrderedDescending);
    }
    XCTAssertEqual([path1 compare:path1], NSOrderedSame);
  }
}

@end
