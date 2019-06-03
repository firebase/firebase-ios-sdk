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
  self.storage = [[FIRSecureStorage alloc] initWithService:@"com.tests.FIRSecureStorageTests"];
}

- (void)tearDown {
  self.storage = nil;
}

- (void)testSetGetObjectForKey {
  [self assertSuccessWriteAndReadObject:@[ @1, @2 ] class:[NSArray class] key:@"test-key1"];
  // Check overriding an object by key.
  [self assertSuccessWriteAndReadObject:@{ @"key": @"value" }
                                  class:[NSDictionary class]
                                    key:@"test-key1"];

  // Check object by another key.
  [self assertSuccessWriteAndReadObject:@{ @"key": @"value" }
                                  class:[NSDictionary class]
                                    key:@"test-key2"];
}

- (void)testGetNonExistingObject {
  [self assertNonExistingObjectForKey:[NSUUID UUID].UUIDString class:[NSArray class]];
}

- (void)testGetExistingObjectClassMismatch {
  NSString *key = [NSUUID UUID].UUIDString;

  // Wtite.
  [self assertSuccessWriteObject:@[ @8 ] forKey:key];

  // Read.
  FBLPromise<id<NSSecureCoding>> *getPromise = [self.storage getObjectForKey:key
                                                                 objectClass:[NSString class]
                                                                 accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(getPromise.value);
  XCTAssertNotNil(getPromise.error);
  // TODO: Test for particular error.
}

- (void)testRemoveExistingObject {
  NSString *key = @"testRemoveExistingObject";
  // Store the object.
  [self assertSuccessWriteAndReadObject:@[ @5 ] class:[NSArray class] key:key];

  // Remove object.
  [self assertRemoveObjectForKey:key];

  // Check if object is still stored.
  [self assertNonExistingObjectForKey:key class:[NSArray class]];
}

- (void)testRemoveNonExistingObject {
  NSString *key = [NSUUID UUID].UUIDString;
  [self assertRemoveObjectForKey:key];
  [self assertNonExistingObjectForKey:key class:[NSArray class]];
}

#pragma mark - Common

- (void)assertSuccessWriteObject:(id<NSSecureCoding>)object forKey:(NSString *)key {
  FBLPromise<NSNull *> *setPromise = [self.storage setObject:object forKey:key accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(setPromise.error);
}

- (void)assertSuccessWriteAndReadObject:(id<NSSecureCoding>)object
                                  class:(Class)class
                                    key:(NSString *)key {

  // Write.
  [self assertSuccessWriteObject:object forKey:key];

  // Read.
  FBLPromise<id<NSSecureCoding>> *getPromise = [self.storage getObjectForKey:key
                                                                 objectClass:class
                                                                 accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertEqualObjects(getPromise.value, object);
  XCTAssertNil(getPromise.error);
}

- (void)assertNonExistingObjectForKey:(NSString *)key class:(Class)class {
  FBLPromise<id<NSSecureCoding>> *promise = [self.storage getObjectForKey:key
                                                              objectClass:class
                                                              accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(promise.error);
  XCTAssertNil(promise.value);
}

- (void)assertRemoveObjectForKey:(NSString *)key {
  FBLPromise<NSNull *> *removePromise = [self.storage removeObjectForKey:key accessGroup:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(removePromise.error);
}

@end
