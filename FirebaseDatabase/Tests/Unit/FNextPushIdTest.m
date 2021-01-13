//
//  FNextPushIdTest.m
//  Pods
//
//  Created by Jan Wyszynski on 1/12/21.
//

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
  XCTAssertEqualObjects(maxIntegerKeySuccessor, MIN_PUSH_CHAR, @"successor(INTEGER_32_MAX) == MIN_PUSH_CHAR");
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
  XCTAssertEqualObjects(expected, actual, @"successor(abc + MAX_PUSH_CHAR repeated MAX_KEY_LEN - 3 times) == abd");

  actual = [FNextPushId successor:[NSString stringWithFormat:@"abc%@", MIN_PUSH_CHAR]];
  expected = [NSString stringWithFormat:@"abc%@%@", MIN_PUSH_CHAR, MIN_PUSH_CHAR];
  XCTAssertEqualObjects(expected, actual, @"successor(abc + MIN_PUSH_CHAR) == abc + MIN_PUSH_CHAR + MIN_PUSH_CHAR");
}

@end
