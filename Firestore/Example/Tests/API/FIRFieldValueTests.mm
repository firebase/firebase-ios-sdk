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

#import <FirebaseFirestore/FIRDecimal128Value.h>
#import <FirebaseFirestore/FIRFieldValue.h>
#import <FirebaseFirestore/FIRInt32Value.h>
#import <FirebaseFirestore/FIRVectorValue.h>

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRFieldValueTests : XCTestCase
@end

@implementation FIRFieldValueTests

- (void)testEquals {
  FIRFieldValue *deleted = [FIRFieldValue fieldValueForDelete];
  FIRFieldValue *deleteDup = [FIRFieldValue fieldValueForDelete];
  FIRFieldValue *serverTimestamp = [FIRFieldValue fieldValueForServerTimestamp];
  FIRFieldValue *serverTimestampDup = [FIRFieldValue fieldValueForServerTimestamp];
  XCTAssertEqualObjects(deleted, deleteDup);
  XCTAssertNotEqualObjects(deleted, nil);
  XCTAssertEqualObjects(serverTimestamp, serverTimestampDup);
  XCTAssertNotEqualObjects(serverTimestamp, nil);
  XCTAssertNotEqualObjects(deleted, serverTimestamp);

  XCTAssertEqual([deleted hash], [deleteDup hash]);
  XCTAssertEqual([serverTimestamp hash], [serverTimestamp hash]);
  XCTAssertNotEqual([deleted hash], [serverTimestamp hash]);
}

- (void)testIncrementEquals {
  FIRFieldValue *int32Inc =
      [FIRFieldValue fieldValueForInt32Increment:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32IncDup =
      [FIRFieldValue fieldValueForInt32Increment:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32IncDiff =
      [FIRFieldValue fieldValueForInt32Increment:[[FIRInt32Value alloc] initWithValue:43]];
  XCTAssertEqualObjects(int32Inc, int32IncDup);
  XCTAssertNotEqualObjects(int32Inc, int32IncDiff);
  XCTAssertNotEqualObjects(int32Inc, nil);
  XCTAssertEqual([int32Inc hash], [int32IncDup hash]);

  FIRFieldValue *d128Inc = [FIRFieldValue
      fieldValueForDecimal128Increment:[[FIRDecimal128Value alloc] initWithValue:@"42.5"]];
  FIRFieldValue *d128IncDup = [FIRFieldValue
      fieldValueForDecimal128Increment:[[FIRDecimal128Value alloc] initWithValue:@"42.5"]];
  FIRFieldValue *d128IncDiff = [FIRFieldValue
      fieldValueForDecimal128Increment:[[FIRDecimal128Value alloc] initWithValue:@"43.5"]];
  XCTAssertEqualObjects(d128Inc, d128IncDup);
  XCTAssertNotEqualObjects(d128Inc, d128IncDiff);
  XCTAssertNotEqualObjects(d128Inc, nil);
  XCTAssertEqual([d128Inc hash], [d128IncDup hash]);
}

- (void)testMinimumEquals {
  FIRFieldValue *int32Min =
      [FIRFieldValue fieldValueForInt32Minimum:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32MinDup =
      [FIRFieldValue fieldValueForInt32Minimum:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32MinDiff =
      [FIRFieldValue fieldValueForInt32Minimum:[[FIRInt32Value alloc] initWithValue:43]];
  XCTAssertEqualObjects(int32Min, int32MinDup);
  XCTAssertNotEqualObjects(int32Min, int32MinDiff);
  XCTAssertNotEqualObjects(int32Min, nil);
  XCTAssertEqual([int32Min hash], [int32MinDup hash]);

  FIRFieldValue *d128Min = [FIRFieldValue
      fieldValueForDecimal128Minimum:[[FIRDecimal128Value alloc] initWithValue:@"42.5"]];
  FIRFieldValue *d128MinDup = [FIRFieldValue
      fieldValueForDecimal128Minimum:[[FIRDecimal128Value alloc] initWithValue:@"42.5"]];
  FIRFieldValue *d128MinDiff = [FIRFieldValue
      fieldValueForDecimal128Minimum:[[FIRDecimal128Value alloc] initWithValue:@"43.5"]];
  XCTAssertEqualObjects(d128Min, d128MinDup);
  XCTAssertNotEqualObjects(d128Min, d128MinDiff);
  XCTAssertNotEqualObjects(d128Min, nil);
  XCTAssertEqual([d128Min hash], [d128MinDup hash]);
}

- (void)testMaximumEquals {
  FIRFieldValue *int32Max =
      [FIRFieldValue fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32MaxDup =
      [FIRFieldValue fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32MaxDiff =
      [FIRFieldValue fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:43]];
  XCTAssertEqualObjects(int32Max, int32MaxDup);
  XCTAssertNotEqualObjects(int32Max, int32MaxDiff);
  XCTAssertNotEqualObjects(int32Max, nil);
  XCTAssertEqual([int32Max hash], [int32MaxDup hash]);

  FIRFieldValue *d128Max = [FIRFieldValue
      fieldValueForDecimal128Maximum:[[FIRDecimal128Value alloc] initWithValue:@"42.5"]];
  FIRFieldValue *d128MaxDup = [FIRFieldValue
      fieldValueForDecimal128Maximum:[[FIRDecimal128Value alloc] initWithValue:@"42.5"]];
  FIRFieldValue *d128MaxDiff = [FIRFieldValue
      fieldValueForDecimal128Maximum:[[FIRDecimal128Value alloc] initWithValue:@"43.5"]];
  XCTAssertEqualObjects(d128Max, d128MaxDup);
  XCTAssertNotEqualObjects(d128Max, d128MaxDiff);
  XCTAssertNotEqualObjects(d128Max, nil);
  XCTAssertEqual([d128Max hash], [d128MaxDup hash]);
}

- (void)testCrossOperationInequality {
  FIRFieldValue *deleted = [FIRFieldValue fieldValueForDelete];
  FIRFieldValue *int32Inc =
      [FIRFieldValue fieldValueForInt32Increment:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32Min =
      [FIRFieldValue fieldValueForInt32Minimum:[[FIRInt32Value alloc] initWithValue:42]];
  FIRFieldValue *int32Max =
      [FIRFieldValue fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:42]];

  XCTAssertNotEqualObjects(int32Inc, int32Min);
  XCTAssertNotEqualObjects(int32Min, int32Max);
  XCTAssertNotEqualObjects(int32Max, int32Inc);

  XCTAssertNotEqualObjects(int32Inc, deleted);
  XCTAssertNotEqualObjects(int32Min, deleted);
  XCTAssertNotEqualObjects(int32Max, deleted);
}

@end

NS_ASSUME_NONNULL_END