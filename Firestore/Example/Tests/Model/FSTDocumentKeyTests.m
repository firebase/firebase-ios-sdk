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

#import "Model/FSTDocumentKey.h"

#import <XCTest/XCTest.h>

#import "Model/FSTPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTDocumentKeyTests : XCTestCase
@end

@implementation FSTDocumentKeyTests

- (void)testConstructor {
  FSTResourcePath *path =
      [FSTResourcePath pathWithSegments:@[ @"rooms", @"firestore", @"messages", @"1" ]];
  FSTDocumentKey *key = [FSTDocumentKey keyWithPath:path];
  XCTAssertEqual(path, key.path);
}

- (void)testComparison {
  FSTDocumentKey *key1 = [FSTDocumentKey keyWithSegments:@[ @"a", @"b", @"c", @"d" ]];
  FSTDocumentKey *key2 = [FSTDocumentKey keyWithSegments:@[ @"a", @"b", @"c", @"d" ]];
  FSTDocumentKey *key3 = [FSTDocumentKey keyWithSegments:@[ @"x", @"y", @"z", @"w" ]];
  XCTAssertTrue([key1 isEqualToKey:key2]);
  XCTAssertFalse([key1 isEqualToKey:key3]);

  FSTDocumentKey *empty = [FSTDocumentKey keyWithSegments:@[]];
  FSTDocumentKey *a = [FSTDocumentKey keyWithSegments:@[ @"a", @"a" ]];
  FSTDocumentKey *b = [FSTDocumentKey keyWithSegments:@[ @"b", @"b" ]];
  FSTDocumentKey *ab = [FSTDocumentKey keyWithSegments:@[ @"a", @"a", @"b", @"b" ]];

  XCTAssertEqual(NSOrderedAscending, [empty compare:a]);
  XCTAssertEqual(NSOrderedAscending, [a compare:b]);
  XCTAssertEqual(NSOrderedAscending, [a compare:ab]);

  XCTAssertEqual(NSOrderedDescending, [a compare:empty]);
  XCTAssertEqual(NSOrderedDescending, [b compare:a]);
  XCTAssertEqual(NSOrderedDescending, [ab compare:a]);
}

@end

NS_ASSUME_NONNULL_END
