// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/FIRAppAssociationRegistration.h"

/** @var kKey
    @brief A unique string key.
 */
static NSString *kKey = @"key";

/** @var kKey1
    @brief A unique string key.
 */
static NSString *kKey1 = @"key1";

/** @var kKey2
    @brief A unique string key.
 */
static NSString *kKey2 = @"key2";

/** @var gCreateNewObject
    @brief A block that returns a new object everytime it is called.
 */
static id _Nullable (^gCreateNewObject)(void) = ^id _Nullable() {
  return [[NSObject alloc] init];
};

/** @class FIRAppAssociationRegistrationTests
    @brief Tests for @c FIRAppAssociationRegistration
 */
@interface FIRAppAssociationRegistrationTests : XCTestCase
@end

@implementation FIRAppAssociationRegistrationTests

- (void)testPassObject {
  id host = gCreateNewObject();
  id obj = gCreateNewObject();
  id result = [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                                  key:kKey
                                                        creationBlock:^id _Nullable() {
                                                          return obj;
                                                        }];
  XCTAssertEqual(obj, result);
}

- (void)testPassNil {
  id host = gCreateNewObject();
  id obj = [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                               key:kKey
                                                     creationBlock:^id _Nullable() {
                                                       return nil;
                                                     }];
  XCTAssertNil(obj);
}

- (void)testObjectOwnership {
  __weak id weakHost;
  __block __weak id weakObj;
  @autoreleasepool {
    id host = gCreateNewObject();
    weakHost = host;
    [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                        key:kKey
                                              creationBlock:^id _Nullable() {
                                                id obj = gCreateNewObject();
                                                weakObj = obj;
                                                return obj;
                                              }];
    // Verify that neither the host nor the object is released yet, i.e., the host owns the object
    // because nothing else retains the object.
    XCTAssertNotNil(weakHost);
    XCTAssertNotNil(weakObj);
  }
  // Verify that both the host and the object are released upon exit of the autorelease pool,
  // i.e., the host is the sole owner of the object.
  XCTAssertNil(weakHost);
  XCTAssertNil(weakObj);
}

- (void)testSameHostSameKey {
  id host = gCreateNewObject();
  id obj1 = [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                                key:kKey
                                                      creationBlock:gCreateNewObject];
  id obj2 = [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                                key:kKey
                                                      creationBlock:gCreateNewObject];
  XCTAssertEqual(obj1, obj2);
}

- (void)testSameHostDifferentKey {
  id host = gCreateNewObject();
  id obj1 = [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                                key:kKey1
                                                      creationBlock:gCreateNewObject];
  id obj2 = [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                                key:kKey2
                                                      creationBlock:gCreateNewObject];
  XCTAssertNotEqual(obj1, obj2);
}

- (void)testDifferentHostSameKey {
  id host1 = gCreateNewObject();
  id obj1 = [FIRAppAssociationRegistration registeredObjectWithHost:host1
                                                                key:kKey
                                                      creationBlock:gCreateNewObject];
  id host2 = gCreateNewObject();
  id obj2 = [FIRAppAssociationRegistration registeredObjectWithHost:host2
                                                                key:kKey
                                                      creationBlock:gCreateNewObject];
  XCTAssertNotEqual(obj1, obj2);
}

- (void)testDifferentHostDifferentKey {
  id host1 = gCreateNewObject();
  id obj1 = [FIRAppAssociationRegistration registeredObjectWithHost:host1
                                                                key:kKey1
                                                      creationBlock:gCreateNewObject];
  id host2 = gCreateNewObject();
  id obj2 = [FIRAppAssociationRegistration registeredObjectWithHost:host2
                                                                key:kKey2
                                                      creationBlock:gCreateNewObject];
  XCTAssertNotEqual(obj1, obj2);
}

- (void)testReentrySameHostSameKey {
  id host = gCreateNewObject();
  XCTAssertThrows([FIRAppAssociationRegistration
      registeredObjectWithHost:host
                           key:kKey
                 creationBlock:^id _Nullable() {
                   [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                                       key:kKey
                                                             creationBlock:gCreateNewObject];
                   return gCreateNewObject();
                 }]);
}

- (void)testReentrySameHostDifferentKey {
  id host = gCreateNewObject();
  [FIRAppAssociationRegistration registeredObjectWithHost:host
                                                      key:kKey1
                                            creationBlock:^id _Nullable() {
                                              [FIRAppAssociationRegistration
                                                  registeredObjectWithHost:host
                                                                       key:kKey2
                                                             creationBlock:gCreateNewObject];
                                              return gCreateNewObject();
                                            }];
  // Expect no exception raised.
}

- (void)testReentryDifferentHostSameKey {
  id host1 = gCreateNewObject();
  id host2 = gCreateNewObject();
  [FIRAppAssociationRegistration registeredObjectWithHost:host1
                                                      key:kKey
                                            creationBlock:^id _Nullable() {
                                              [FIRAppAssociationRegistration
                                                  registeredObjectWithHost:host2
                                                                       key:kKey
                                                             creationBlock:gCreateNewObject];
                                              return gCreateNewObject();
                                            }];
  // Expect no exception raised.
}

- (void)testReentryDifferentHostDifferentKey {
  id host1 = gCreateNewObject();
  id host2 = gCreateNewObject();
  [FIRAppAssociationRegistration registeredObjectWithHost:host1
                                                      key:kKey1
                                            creationBlock:^id _Nullable() {
                                              [FIRAppAssociationRegistration
                                                  registeredObjectWithHost:host2
                                                                       key:kKey2
                                                             creationBlock:gCreateNewObject];
                                              return gCreateNewObject();
                                            }];
  // Expect no exception raised.
}

@end
