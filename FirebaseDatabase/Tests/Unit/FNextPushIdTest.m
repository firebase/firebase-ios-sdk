/*
 * Copyright 2021 Google LLC
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

#import "FirebaseDatabase/Sources/Utilities/FNextPushId.h"
#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"

@interface FNextPushIdTest : XCTestCase

@end

@implementation FNextPushIdTest

static NSString *MIN_PUSH_CHAR = @"-";

static NSString *MAX_PUSH_CHAR = @"z";

static NSInteger MAX_KEY_LEN = 786;

- (void)testSuccessorSpecialValues {
  NSString *maxIntegerKeySuccessor =
      [FNextPushId successor:[NSString stringWithFormat:@"%d", INTEGER_32_MAX]];
  XCTAssertEqualObjects(maxIntegerKeySuccessor, MIN_PUSH_CHAR,
                        @"successor(INTEGER_32_MAX) == MIN_PUSH_CHAR");
  NSString *maxKey = [@"" stringByPaddingToLength:MAX_KEY_LEN
                                       withString:MAX_PUSH_CHAR
                                  startingAtIndex:0];
  NSString *maxKeySuccessor = [FNextPushId successor:maxKey];
  XCTAssertEqualObjects(maxKeySuccessor, [FUtilities maxName], @"");
}

- (void)testSuccessorBasic {
  NSString *actual = [FNextPushId successor:@"abc"];
  NSString *expected = [NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR];
  XCTAssertEqualObjects(expected, actual, @"successor(abc) == abc + MIN_PUSH_CHAR");

  actual = [FNextPushId successor:[@"abc" stringByPaddingToLength:MAX_KEY_LEN
                                                       withString:MAX_PUSH_CHAR
                                                  startingAtIndex:0]];
  expected = @"abd";
  XCTAssertEqualObjects(expected, actual,
                        @"successor(abc + MAX_PUSH_CHAR repeated MAX_KEY_LEN - 3 times) == abd");

  actual = [FNextPushId successor:[NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR]];
  expected = [NSString stringWithFormat:@"abc%@%@", MIN_PUSH_CHAR, MIN_PUSH_CHAR];
  XCTAssertEqualObjects(expected, actual,
                        @"successor(abc + MIN_PUSH_CHAR) == abc + MIN_PUSH_CHAR + MIN_PUSH_CHAR");
}

- (void)testPredecessorSpecialValues {
  NSString *actual = [FNextPushId predecessor:MIN_PUSH_CHAR];
  NSString *expected = [NSString stringWithFormat:@"%d", INTEGER_32_MAX];
  XCTAssertEqualObjects(expected, actual, @"predecessor(MIN_PUSH_CHAR) == INTEGER_32_MAX");
  actual = [FNextPushId predecessor:[NSString stringWithFormat:@"%ld", INTEGER_32_MIN]];
  expected = [FUtilities minName];
  XCTAssertEqualObjects(expected, actual, @"predecessor(INTEGER_32_MIN) == MIN_NAME");
}

- (void)testPredecessorBasic {
  NSString *actual = [FNextPushId predecessor:@"abc"];
  NSString *expected = [@"abb" stringByPaddingToLength:MAX_KEY_LEN
                                            withString:MAX_PUSH_CHAR
                                       startingAtIndex:0];
  XCTAssertEqualObjects(
      expected, actual,
      @"predecessor(abc) = abb + { MAX_PUSH_CHAR repeated MAX_KEY_LEN - 3 times }");

  actual = [FNextPushId predecessor:[NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR]];
  expected = @"abc";
  XCTAssertEqualObjects(expected, actual, @"predecessor(abc + MIN_PUSH_CHAR) == abc");
}

@end
