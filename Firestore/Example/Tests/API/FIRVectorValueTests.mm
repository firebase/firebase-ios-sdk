/*
 * Copyright 2024 Google LLC
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

#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRVectorValue.h>

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRVectorValueTests : XCTestCase
@end

@implementation FIRVectorValueTests

- (void)testCreateAndReadVectorValue {
  FIRVectorValue *vector = [FIRFieldValue vectorWithArray:@[
    @DBL_MIN, @0.0, [NSNumber numberWithLong:((long)pow(2, 53)) + 1], @DBL_MAX, @DBL_EPSILON,
    @INT64_MAX
  ]];
  NSArray<NSNumber *> *outArray = vector.array;

  XCTAssertEqualObjects([outArray objectAtIndex:0], @DBL_MIN);
  XCTAssertEqualObjects([outArray objectAtIndex:1], @0.0);
  // Assert that if the vector is created with large long values,
  // then the data will be truncated as a double.
  XCTAssertEqual([outArray objectAtIndex:2].longValue, pow(2, 53));
  XCTAssertEqualObjects([outArray objectAtIndex:3], @DBL_MAX);
  XCTAssertEqualObjects([outArray objectAtIndex:4], @DBL_EPSILON);
  XCTAssertEqualObjects([outArray objectAtIndex:5], @INT64_MAX);
}

@end

NS_ASSUME_NONNULL_END
