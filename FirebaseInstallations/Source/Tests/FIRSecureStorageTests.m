/*
 * Copyright 2019 Google
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
#import "FBLPromise+Testing.h"
#import "FIRSecureStorage.h"

@interface FIRSecureStorageTests : XCTestCase
@property (nonatomic, strong) FIRSecureStorage *storage;
@end

@implementation FIRSecureStorageTests

- (void)setUp {
  self.storage = [[FIRSecureStorage alloc] init];
}

- (void)tearDown {
  self.storage = nil;
}

- (void)testSetGetObjectForKey {
  NSArray *object = @[ @1, @2 ];
  NSString *key = @"test-key";
  FBLPromise<id> *setPromise = [self.storage setObject:object forKey:key];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(setPromise.error);

  FBLPromise<id<NSSecureCoding>> *getPromise = [self.storage getObjectForKey:key];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertEqualObjects(getPromise.value, object);
  XCTAssertNil(getPromise.error);
}

@end
