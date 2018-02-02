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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Model/FSTPath.h"

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FSTFieldPathTests : XCTestCase
@end

@implementation FSTFieldPathTests

- (void)testConstructor {
  FSTFieldPath *path = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros", @"messages" ]];
  XCTAssertEqual(3, path.length);
}

- (void)testIndexing {
  FSTFieldPath *path = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros", @"messages" ]];
  XCTAssertEqualObjects(@"rooms", path.firstSegment);
  XCTAssertEqualObjects(@"rooms", [path segmentAtIndex:0]);
  XCTAssertEqualObjects(@"rooms", path[0]);

  XCTAssertEqualObjects(@"Eros", [path segmentAtIndex:1]);
  XCTAssertEqualObjects(@"Eros", path[1]);

  XCTAssertEqualObjects(@"messages", [path segmentAtIndex:2]);
  XCTAssertEqualObjects(@"messages", path[2]);
  XCTAssertEqualObjects(@"messages", path.lastSegment);
}

- (void)testPathByRemovingFirstSegment {
  FSTFieldPath *path = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros", @"messages" ]];
  FSTFieldPath *same = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros", @"messages" ]];
  FSTFieldPath *second = [FSTFieldPath pathWithSegments:@[ @"Eros", @"messages" ]];
  FSTFieldPath *third = [FSTFieldPath pathWithSegments:@[ @"messages" ]];
  FSTFieldPath *empty = [FSTFieldPath pathWithSegments:@[]];

  XCTAssertEqualObjects(second, path.pathByRemovingFirstSegment);
  XCTAssertEqualObjects(third, path.pathByRemovingFirstSegment.pathByRemovingFirstSegment);
  XCTAssertEqualObjects(
      empty, path.pathByRemovingFirstSegment.pathByRemovingFirstSegment.pathByRemovingFirstSegment);
  // unmodified original
  XCTAssertEqualObjects(same, path);
}

- (void)testPathByRemovingLastSegment {
  FSTFieldPath *path = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros", @"messages" ]];
  FSTFieldPath *same = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros", @"messages" ]];
  FSTFieldPath *second = [FSTFieldPath pathWithSegments:@[ @"rooms", @"Eros" ]];
  FSTFieldPath *third = [FSTFieldPath pathWithSegments:@[ @"rooms" ]];
  FSTFieldPath *empty = [FSTFieldPath pathWithSegments:@[]];

  XCTAssertEqualObjects(second, path.pathByRemovingLastSegment);
  XCTAssertEqualObjects(third, path.pathByRemovingLastSegment.pathByRemovingLastSegment);
  XCTAssertEqualObjects(
      empty, path.pathByRemovingLastSegment.pathByRemovingLastSegment.pathByRemovingLastSegment);
  // unmodified original
  XCTAssertEqualObjects(same, path);
}

- (void)testPathByAppendingSegment {
  FSTFieldPath *path = [FSTFieldPath pathWithSegments:@[ @"rooms" ]];
  FSTFieldPath *rooms = [FSTFieldPath pathWithSegments:@[ @"rooms" ]];
  FSTFieldPath *roomsEros = [FSTFieldPath pathWithSegments:@[ @"rooms", @"eros" ]];
  FSTFieldPath *roomsEros1 = [FSTFieldPath pathWithSegments:@[ @"rooms", @"eros", @"1" ]];

  XCTAssertEqualObjects(roomsEros, [path pathByAppendingSegment:@"eros"]);
  XCTAssertEqualObjects(roomsEros1,
                        [[path pathByAppendingSegment:@"eros"] pathByAppendingSegment:@"1"]);
  // unmodified original
  XCTAssertEqualObjects(rooms, path);

  FSTFieldPath *sub = [FSTTestFieldPath(@"rooms.eros.1") pathByRemovingFirstSegment];
  FSTFieldPath *appended = [sub pathByAppendingSegment:@"2"];
  XCTAssertEqualObjects(appended, FSTTestFieldPath(@"eros.1.2"));
}

- (void)testPathComparison {
  FSTFieldPath *path1 = [FSTFieldPath pathWithSegments:@[ @"a", @"b", @"c" ]];
  FSTFieldPath *path2 = [FSTFieldPath pathWithSegments:@[ @"a", @"b", @"c" ]];
  FSTFieldPath *path3 = [FSTFieldPath pathWithSegments:@[ @"x", @"y", @"z" ]];
  XCTAssertTrue([path1 isEqual:path2]);
  XCTAssertFalse([path1 isEqual:path3]);

  FSTFieldPath *empty = [FSTFieldPath pathWithSegments:@[]];
  FSTFieldPath *a = [FSTFieldPath pathWithSegments:@[ @"a" ]];
  FSTFieldPath *b = [FSTFieldPath pathWithSegments:@[ @"b" ]];
  FSTFieldPath *ab = [FSTFieldPath pathWithSegments:@[ @"a", @"b" ]];

  XCTAssertEqual(NSOrderedAscending, [empty compare:a]);
  XCTAssertEqual(NSOrderedAscending, [a compare:b]);
  XCTAssertEqual(NSOrderedAscending, [a compare:ab]);

  XCTAssertEqual(NSOrderedDescending, [a compare:empty]);
  XCTAssertEqual(NSOrderedDescending, [b compare:a]);
  XCTAssertEqual(NSOrderedDescending, [ab compare:a]);
}

- (void)testIsPrefixOfPath {
  FSTFieldPath *empty = [FSTFieldPath pathWithSegments:@[]];
  FSTFieldPath *a = [FSTFieldPath pathWithSegments:@[ @"a" ]];
  FSTFieldPath *ab = [FSTFieldPath pathWithSegments:@[ @"a", @"b" ]];
  FSTFieldPath *abc = [FSTFieldPath pathWithSegments:@[ @"a", @"b", @"c" ]];
  FSTFieldPath *b = [FSTFieldPath pathWithSegments:@[ @"b" ]];
  FSTFieldPath *ba = [FSTFieldPath pathWithSegments:@[ @"b", @"a" ]];

  XCTAssertTrue([empty isPrefixOfPath:a]);
  XCTAssertTrue([empty isPrefixOfPath:ab]);
  XCTAssertTrue([empty isPrefixOfPath:abc]);
  XCTAssertTrue([empty isPrefixOfPath:empty]);
  XCTAssertTrue([empty isPrefixOfPath:b]);
  XCTAssertTrue([empty isPrefixOfPath:ba]);

  XCTAssertTrue([a isPrefixOfPath:a]);
  XCTAssertTrue([a isPrefixOfPath:ab]);
  XCTAssertTrue([a isPrefixOfPath:abc]);
  XCTAssertFalse([a isPrefixOfPath:empty]);
  XCTAssertFalse([a isPrefixOfPath:b]);
  XCTAssertFalse([a isPrefixOfPath:ba]);

  XCTAssertFalse([ab isPrefixOfPath:a]);
  XCTAssertTrue([ab isPrefixOfPath:ab]);
  XCTAssertTrue([ab isPrefixOfPath:abc]);
  XCTAssertFalse([ab isPrefixOfPath:empty]);
  XCTAssertFalse([ab isPrefixOfPath:b]);
  XCTAssertFalse([ab isPrefixOfPath:ba]);

  XCTAssertFalse([abc isPrefixOfPath:a]);
  XCTAssertFalse([abc isPrefixOfPath:ab]);
  XCTAssertTrue([abc isPrefixOfPath:abc]);
  XCTAssertFalse([abc isPrefixOfPath:empty]);
  XCTAssertFalse([abc isPrefixOfPath:b]);
  XCTAssertFalse([abc isPrefixOfPath:ba]);
}

- (void)testInvalidPaths {
  XCTAssertThrows(FSTTestFieldPath(@""));
  XCTAssertThrows(FSTTestFieldPath(@"."));
  XCTAssertThrows(FSTTestFieldPath(@".foo"));
  XCTAssertThrows(FSTTestFieldPath(@"foo."));
  XCTAssertThrows(FSTTestFieldPath(@"foo..bar"));
}

#define ASSERT_ROUND_TRIP(str, segments)                          \
  do {                                                            \
    FSTFieldPath *path = [FSTFieldPath pathWithServerFormat:str]; \
    XCTAssertEqual([path length], segments);                      \
    NSString *canonical = [path canonicalString];                 \
    XCTAssertEqualObjects(canonical, str);                        \
  } while (0);

- (void)testCanonicalString {
  ASSERT_ROUND_TRIP(@"foo", 1);
  ASSERT_ROUND_TRIP(@"foo.bar", 2);
  ASSERT_ROUND_TRIP(@"foo.bar.baz", 3);
  ASSERT_ROUND_TRIP(@"`.foo\\\\`", 1);
  ASSERT_ROUND_TRIP(@"`.foo\\\\`.`.foo`", 2);
  ASSERT_ROUND_TRIP(@"foo.`\\``.bar", 3);

  FSTFieldPath *path = [FSTFieldPath pathWithServerFormat:@"foo\\.bar"];
  XCTAssertEqualObjects([path canonicalString], @"`foo.bar`");
  XCTAssertEqual(path.length, 1);
}

#undef ASSERT_ROUND_TRIP

- (void)testCanonicalStringOfSubstring {
  FSTFieldPath *path = [FSTFieldPath pathWithServerFormat:@"foo.bar.baz"];
  XCTAssertEqualObjects([path canonicalString], @"foo.bar.baz");

  FSTFieldPath *pathTail = [path pathByRemovingFirstSegment];
  XCTAssertEqualObjects([pathTail canonicalString], @"bar.baz");

  FSTFieldPath *pathHead = [path pathByRemovingLastSegment];
  XCTAssertEqualObjects([pathHead canonicalString], @"foo.bar");

  XCTAssertEqualObjects([[pathTail pathByRemovingLastSegment] canonicalString], @"bar");
  XCTAssertEqualObjects([[pathHead pathByRemovingFirstSegment] canonicalString], @"bar");
}

@end

NS_ASSUME_NONNULL_END
