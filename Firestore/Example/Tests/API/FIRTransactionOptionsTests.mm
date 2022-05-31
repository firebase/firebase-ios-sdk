/*
 * Copyright 2022 Google LLC
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

#import <FirebaseFirestore/FIRTransactionOptions.h>

#import <XCTest/XCTest.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRTransactionOptionsTests : XCTestCase
@end

@implementation FIRTransactionOptionsTests

- (void)testDefaults {
  FIRTransactionOptions* options = [[FIRTransactionOptions alloc] init];
  XCTAssertEqual(options.maxAttempts, 5);
}

- (void)testSetMaxAttempts {
  FIRTransactionOptions* options = [[FIRTransactionOptions alloc] init];
  options.maxAttempts = 10;
  XCTAssertEqual(options.maxAttempts, 10);
  options.maxAttempts = 99;
  XCTAssertEqual(options.maxAttempts, 99);
}

- (void)testSetMaxAttemptsThrowsOnInvalidValue {
  FIRTransactionOptions* options = [[FIRTransactionOptions alloc] init];
  XCTAssertThrows(options.maxAttempts = 0);
  XCTAssertThrows(options.maxAttempts = -1);
  XCTAssertThrows(options.maxAttempts = INT32_MIN);
  XCTAssertThrows(options.maxAttempts = INT32_MAX + 1);
}

- (void)testHash {
  XCTAssertEqual([[[FIRTransactionOptions alloc] init] hash],
                 [[[FIRTransactionOptions alloc] init] hash]);

  FIRTransactionOptions* options1a = [[FIRTransactionOptions alloc] init];
  options1a.maxAttempts = 99;
  FIRTransactionOptions* options1b = [[FIRTransactionOptions alloc] init];
  options1b.maxAttempts = 99;
  FIRTransactionOptions* options2a = [[FIRTransactionOptions alloc] init];
  options2a.maxAttempts = 11;
  FIRTransactionOptions* options2b = [[FIRTransactionOptions alloc] init];
  options2b.maxAttempts = 11;

  XCTAssertEqual([options1a hash], [options1b hash]);
  XCTAssertEqual([options2a hash], [options2b hash]);
  XCTAssertNotEqual([options1a hash], [options2a hash]);
}

- (void)testIsEqual {
  FIRTransactionOptions* options1a = [[FIRTransactionOptions alloc] init];
  options1a.maxAttempts = 99;
  FIRTransactionOptions* options1b = [[FIRTransactionOptions alloc] init];
  options1b.maxAttempts = 99;
  FIRTransactionOptions* options2a = [[FIRTransactionOptions alloc] init];
  options2a.maxAttempts = 11;
  FIRTransactionOptions* options2b = [[FIRTransactionOptions alloc] init];
  options2b.maxAttempts = 11;

  XCTAssertTrue([options1a isEqual:options1a]);

  XCTAssertTrue([options1a isEqual:options1b]);
  XCTAssertTrue([options2a isEqual:options2b]);

  XCTAssertFalse([options1a isEqual:options2a]);

  XCTAssertFalse([options1a isEqual:@"definitely not equal"]);
}

- (void)testCopy {
  FIRTransactionOptions* options1 = [[FIRTransactionOptions alloc] init];
  options1.maxAttempts = 99;
  FIRTransactionOptions* options2 = [options1 copy];
  XCTAssertEqual(options2.maxAttempts, 99);

  // Verify that the copy is independent of the copied object.
  options1.maxAttempts = 55;
  XCTAssertEqual(options2.maxAttempts, 99);
  options2.maxAttempts = 22;
  XCTAssertEqual(options1.maxAttempts, 55);
}

@end

NS_ASSUME_NONNULL_END
