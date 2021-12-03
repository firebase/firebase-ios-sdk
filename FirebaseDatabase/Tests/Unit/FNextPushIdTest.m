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
#import "FirebaseDatabase/Sources/Utilities/FValidation.h"

@interface FValidation (Test)
+ (BOOL)isValidKey:(NSString *)key;
@end

@interface FNextPushIdTest : XCTestCase

@end

@implementation FNextPushIdTest

static NSString *MIN_PUSH_CHAR = @" ";

static NSString *MAX_PUSH_CHAR = @"\uFFFF";

static NSInteger MAX_KEY_LEN = 786;

- (void)testSuccessorSpecialValues {
  NSString *maxIntegerKeySuccessor =
      [FNextPushId from:@"test" successor:[NSString stringWithFormat:@"%d", INTEGER_32_MAX]];
  XCTAssertEqualObjects(maxIntegerKeySuccessor, MIN_PUSH_CHAR,
                        @"successor(INTEGER_32_MAX) == MIN_PUSH_CHAR");
  NSString *maxKey = [@"" stringByPaddingToLength:MAX_KEY_LEN
                                       withString:MAX_PUSH_CHAR
                                  startingAtIndex:0];
  NSString *maxKeySuccessor = [FNextPushId from:@"test" successor:maxKey];
  XCTAssertEqualObjects(maxKeySuccessor, [FUtilities maxName],
                        @"successor(MAX_PUSH_CHAR repeated MAX_KEY_LEN times) == MAX_NAME");
}

- (void)testSuccessorBasic {
  NSString *actual = [FNextPushId from:@"test" successor:@"abc"];
  NSString *expected = [NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR];
  XCTAssertEqualObjects(expected, actual, @"successor(abc) == abc + MIN_PUSH_CHAR");

  actual = [FNextPushId from:@"test"
                   successor:[@"abc" stringByPaddingToLength:MAX_KEY_LEN
                                                  withString:MAX_PUSH_CHAR
                                             startingAtIndex:0]];
  expected = @"abd";
  XCTAssertEqualObjects(expected, actual,
                        @"successor(abc + MAX_PUSH_CHAR repeated MAX_KEY_LEN - 3 times) == abd");

  actual = [FNextPushId from:@"test" successor:[NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR]];
  expected = [NSString stringWithFormat:@"abc%@%@", MIN_PUSH_CHAR, MIN_PUSH_CHAR];
  XCTAssertEqualObjects(expected, actual,
                        @"successor(abc + MIN_PUSH_CHAR) == abc + MIN_PUSH_CHAR + MIN_PUSH_CHAR");
}

- (void)testPredecessorSpecialValues {
  NSString *actual = [FNextPushId from:@"test" predecessor:MIN_PUSH_CHAR];
  NSString *expected = [NSString stringWithFormat:@"%d", INTEGER_32_MAX];
  XCTAssertEqualObjects(expected, actual, @"predecessor(MIN_PUSH_CHAR) == INTEGER_32_MAX");
  actual = [FNextPushId from:@"test"
                 predecessor:[NSString stringWithFormat:@"%ld", INTEGER_32_MIN]];
  expected = [FUtilities minName];
  XCTAssertEqualObjects(expected, actual, @"predecessor(INTEGER_32_MIN) == MIN_NAME");
}

- (void)testPredecessorBasic {
  NSString *actual = [FNextPushId from:@"test" predecessor:@"abc"];
  NSString *expected = [@"abb" stringByPaddingToLength:MAX_KEY_LEN
                                            withString:MAX_PUSH_CHAR
                                       startingAtIndex:0];
  XCTAssertEqualObjects(
      expected, actual,
      @"predecessor(abc) = abb + { MAX_PUSH_CHAR repeated MAX_KEY_LEN - 3 times }");

  actual = [FNextPushId from:@"test"
                 predecessor:[NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR]];
  expected = @"abc";
  XCTAssertEqualObjects(expected, actual, @"predecessor(abc + MIN_PUSH_CHAR) == abc");
}

- (void)testPredecessorUnicode {
  NSString *actual = [FNextPushId from:@"test" predecessor:@"\uE000"];
  NSString *expected = [@"\U0010FFFF" stringByPaddingToLength:MAX_KEY_LEN
                                                   withString:MAX_PUSH_CHAR
                                              startingAtIndex:0];

  XCTAssertEqualObjects(
      expected, actual,
      @"predecessor(uE000) = U0010FFFF + { MAX_PUSH_CHAR repeated MAX_KEY_LEN - 2 times }");

  actual = [FNextPushId from:@"test" predecessor:@"\U00010000"];
  expected = [@"\uD7FF" stringByPaddingToLength:MAX_KEY_LEN
                                     withString:MAX_PUSH_CHAR
                                startingAtIndex:0];
  XCTAssertEqualObjects(
      expected, actual,
      @"predecessor(U00010000) == uD7FF + { MAX_PUSH_CHAR repeated MAX_KEY_LEN - 2 times }");

  actual = [FNextPushId from:@"test" predecessor:[[NSString alloc] initWithFormat:@"%C", 0x80]];
  expected = [[[NSString alloc] initWithFormat:@"%C", 0x7E] stringByPaddingToLength:MAX_KEY_LEN
                                                                         withString:MAX_PUSH_CHAR
                                                                    startingAtIndex:0];
  XCTAssertEqualObjects(expected, actual, @"predecessor(u0080) == u007e");
}

- (void)testPredecessorOrdering {
  // Start _after_ space because otherwise we have to consider integer interpretation.
  for (unichar i = 0x20; i < 0xD800; i++) {
    NSString *key = [[NSString alloc] initWithFormat:@"%C", i];
    if (![FValidation isValidKey:key]) {
      continue;
    }
    NSString *predecessor = [FNextPushId from:@"test" predecessor:key];
    NSComparisonResult r = [FUtilities compareKey:key toKey:predecessor];
    XCTAssertEqual(r, NSOrderedDescending);
  }
  for (NSInteger i = 0xE000; i <= 0xFFFF; i++) {
    NSString *key = [[NSString alloc] initWithFormat:@"%C", (unichar)i];
    NSString *predecessor = [FNextPushId from:@"test" predecessor:key];
    NSComparisonResult r = [FUtilities compareKey:key toKey:predecessor];
    XCTAssertEqual(r, NSOrderedDescending);
  }
  // Unicode code points starting at 0x10000 are exactly the ones that encode
  // as surrogate pairs in utf16
  for (UTF32Char i = 0x10000; i <= 0x10FFFF; i++) {
    UniChar c[2];
    CFStringGetSurrogatePairForLongCharacter(i, c);
    NSString *key = [[NSString alloc] initWithCharacters:c length:2];
    NSString *predecessor = [FNextPushId from:@"test" predecessor:key];
    NSComparisonResult r = [FUtilities compareKey:key toKey:predecessor];
    XCTAssertEqual(r, NSOrderedDescending);
  }
}

- (void)testSuccessorOrdering {
  for (unichar i = 0x20; i < 0xD800; i++) {
    NSString *key = [[NSString alloc] initWithFormat:@"%C", i];
    if (![FValidation isValidKey:key]) {
      continue;
    }
    NSString *successor = [FNextPushId from:@"test" successor:key];
    NSComparisonResult r = [FUtilities compareKey:key toKey:successor];
    XCTAssertEqual(r, NSOrderedAscending);
  }
  for (NSInteger i = 0xE000; i <= 0xFFFF; i++) {
    NSString *key = [[NSString alloc] initWithFormat:@"%C", (unichar)i];
    NSString *successor = [FNextPushId from:@"test" successor:key];
    NSComparisonResult r = [FUtilities compareKey:key toKey:successor];
    XCTAssertEqual(r, NSOrderedAscending);
  }
  // Unicode code points starting at 0x10000 are exactly the ones that encode
  // as surrogate pairs in utf16
  for (UTF32Char i = 0x10000; i <= 0x10FFFF; i++) {
    UniChar c[2];
    CFStringGetSurrogatePairForLongCharacter(i, c);
    NSString *key = [[NSString alloc] initWithCharacters:c length:2];
    NSString *successor = [FNextPushId from:@"test" successor:key];
    NSComparisonResult r = [FUtilities compareKey:key toKey:successor];
    XCTAssertEqual(r, NSOrderedAscending);
  }
}

@end
