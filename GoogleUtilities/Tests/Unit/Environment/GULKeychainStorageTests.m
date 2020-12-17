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

#import <TargetConditionals.h>
#if !TARGET_OS_MACCATALYST
// Skip keychain tests on Catalyst.

#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"
#import "GoogleUtilities/Tests/Unit/Utils/GULTestKeychain.h"
#import "OCMock.h"

#import "GoogleUtilities/Environment/Public/GoogleUtilities/GULKeychainStorage.h"

@interface GULKeychainStorage (Tests)
- (instancetype)initWithService:(NSString *)service cache:(NSCache *)cache;
- (void)resetInMemoryCache;
@end

@interface GULKeychainStorageTests : XCTestCase
@property(nonatomic, strong) GULKeychainStorage *storage;
@property(nonatomic, strong) NSCache *cache;
@property(nonatomic, strong) id mockCache;

#if TARGET_OS_OSX
@property(nonatomic) GULTestKeychain *privateKeychain;
#endif  // TARGET_OSX

@end

@implementation GULKeychainStorageTests

- (void)setUp {
  self.cache = [[NSCache alloc] init];
  self.mockCache = OCMPartialMock(self.cache);
  self.storage = [[GULKeychainStorage alloc] initWithService:@"com.tests.GULKeychainStorageTests"
                                                       cache:self.mockCache];

#if TARGET_OS_OSX
  self.privateKeychain = [[GULTestKeychain alloc] init];
  self.storage.keychainRef = self.privateKeychain.testKeychainRef;
#endif  // TARGET_OSX
}

- (void)tearDown {
  self.storage = nil;
  self.mockCache = nil;
  self.cache = nil;

#if TARGET_OS_OSX
  self.privateKeychain = nil;
#endif  // TARGET_OSX
}

- (void)testSetGetObjectForKey {
  // 1. Write and read object initially.
  [self assertSuccessWriteObject:@[ @1, @2 ] forKey:@"test-key1"];
  [self assertSuccessReadObject:@[ @1, @2 ]
                         forKey:@"test-key1"
                          class:[NSArray class]
                  existsInCache:YES];

  //  // 2. Override existing object.
  [self assertSuccessWriteObject:@{@"key" : @"value"} forKey:@"test-key1"];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key1"
                          class:[NSDictionary class]
                  existsInCache:YES];

  // 3. Read existing object which is not present in in-memory cache.
  [self.cache removeAllObjects];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key1"
                          class:[NSDictionary class]
                  existsInCache:NO];

  // 4. Write and read an object for another key.
  [self assertSuccessWriteObject:@{@"key" : @"value"} forKey:@"test-key2"];
  [self assertSuccessReadObject:@{@"key" : @"value"}
                         forKey:@"test-key2"
                          class:[NSDictionary class]
                  existsInCache:YES];
}

- (void)testGetNonExistingObject {
  [self assertNonExistingObjectForKey:[NSUUID UUID].UUIDString class:[NSArray class]];
}

- (void)testGetExistingObjectClassMismatch {
  NSString *key = [NSUUID UUID].UUIDString;

  // Write.
  [self assertSuccessWriteObject:@[ @8 ] forKey:key];

  // Read.
  // Skip in-memory cache because the error is relevant only for Keychain.
  OCMExpect([self.mockCache objectForKey:key]).andReturn(nil);

  FBLPromise<id<NSSecureCoding>> *getPromise = [self.storage getObjectForKey:key
                                                                 objectClass:[NSString class]
                                                                 accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(getPromise.value);
  XCTAssertNotNil(getPromise.error);
  // TODO: Test for particular error.

  OCMVerifyAll(self.mockCache);
}

- (void)testRemoveExistingObject {
  NSString *key = @"testRemoveExistingObject";
  // Store the object.
  [self assertSuccessWriteObject:@[ @5 ] forKey:(NSString *)key];

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
  OCMExpect([self.mockCache setObject:object forKey:key]).andForwardToRealObject();

  FBLPromise<NSNull *> *setPromise = [self.storage setObject:object forKey:key accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(setPromise.error, @"%@", self.name);

  OCMVerifyAll(self.mockCache);

  // Check in-memory cache.
  XCTAssertEqualObjects([self.cache objectForKey:key], object);
}

- (void)assertSuccessReadObject:(id<NSSecureCoding>)object
                         forKey:(NSString *)key
                          class:(Class)class
                  existsInCache:(BOOL)existisInCache {
  OCMExpect([self.mockCache objectForKey:key]).andForwardToRealObject();

  if (!existisInCache) {
    OCMExpect([self.mockCache setObject:object forKey:key]).andForwardToRealObject();
  }

  FBLPromise<id<NSSecureCoding>> *getPromise =
      [self.storage getObjectForKey:key objectClass:class accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1), @"%@", self.name);
  XCTAssertEqualObjects(getPromise.value, object, @"%@", self.name);
  XCTAssertNil(getPromise.error, @"%@", self.name);

  OCMVerifyAll(self.mockCache);

  // Check in-memory cache.
  XCTAssertEqualObjects([self.cache objectForKey:key], object, @"%@", self.name);
}

- (void)assertNonExistingObjectForKey:(NSString *)key class:(Class)class {
  OCMExpect([self.mockCache objectForKey:key]).andForwardToRealObject();

  FBLPromise<id<NSSecureCoding>> *promise =
      [self.storage getObjectForKey:key objectClass:class accessGroup:nil];

  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(promise.error, @"%@", self.name);
  XCTAssertNil(promise.value, @"%@", self.name);

  OCMVerifyAll(self.mockCache);
}

- (void)assertRemoveObjectForKey:(NSString *)key {
  OCMExpect([self.mockCache removeObjectForKey:key]).andForwardToRealObject();

  FBLPromise<NSNull *> *removePromise = [self.storage removeObjectForKey:key accessGroup:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(1));
  XCTAssertNil(removePromise.error);

  OCMVerifyAll(self.mockCache);
}

@end

#endif  // TARGET_OS_MACCATALYST
