/*
 * Copyright 2018 Google
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
#import "OCMock.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseStorage/Sources/FIRStorageComponent.h"
#import "SharedTestUtilities/FIRComponentTestUtilities.h"

// Make FIRComponentRegistrant conformance visible to the tests and expose the initializer.
@interface FIRStorageComponent () <FIRLibrary>
/// Internal initializer.
- (instancetype)initWithApp:(FIRApp *)app;
@end

@interface FIRStorageComponentTests : XCTestCase
@end

@implementation FIRStorageComponentTests

#pragma mark - Interoperability Tests

// Tests that the right number of components are being provided for the container.
- (void)testComponentsBeingRegistered {
  // Check the count, because any time a new component is added it should be added to the test suite
  // as well.
  NSArray<FIRComponent *> *components = [FIRStorageComponent componentsToRegister];
  XCTAssertTrue(components.count == 1);

  FIRComponent *component = [components firstObject];
  XCTAssert(component.protocol == @protocol(FIRStorageMultiBucketProvider));
}

/// Tests that a FIRStorage instance can be created properly by the FIRStorageComponent.
- (void)testStorageInstanceCreation {
  // Get a mocked app, but don't use the default helper since it uses this class in the
  // implementation.
  id app = [self appMockWithOptions];
  FIRStorageComponent *component = [[FIRStorageComponent alloc] initWithApp:app];
  FIRStorage *storage = [component storageForBucket:@"someBucket"];
  XCTAssertNotNil(storage);
}

/// Tests that the component container does not cache instances of FIRStorageComponent.
- (void)testMultipleComponentInstancesCreated {
  // App isn't used in any of this, so a simple class mock works for simplicity.
  id app = OCMClassMock([FIRApp class]);
  NSMutableSet *registrants = [NSMutableSet setWithObject:[FIRStorageComponent class]];
  FIRComponentContainer *container = [[FIRComponentContainer alloc] initWithApp:app
                                                                    registrants:registrants];
  id<FIRStorageMultiBucketProvider> provider1 =
      FIR_COMPONENT(FIRStorageMultiBucketProvider, container);
  XCTAssertNotNil(provider1);

  id<FIRStorageMultiBucketProvider> provider2 =
      FIR_COMPONENT(FIRStorageMultiBucketProvider, container);
  XCTAssertNotNil(provider2);

  // Ensure they're different instances.
  XCTAssertNotEqual(provider1, provider2);
}

/// Tests that instances of FIRStorage created are different.
- (void)testMultipleStorageInstancesCreated {
  // Get a mocked app, but don't use the default helper since is uses this class in the
  // implementation.
  id app = [self appMockWithOptions];
  NSMutableSet *registrants = [NSMutableSet setWithObject:[FIRStorageComponent class]];
  FIRComponentContainer *container = [[FIRComponentContainer alloc] initWithApp:app
                                                                    registrants:registrants];
  id<FIRStorageMultiBucketProvider> provider =
      FIR_COMPONENT(FIRStorageMultiBucketProvider, container);
  XCTAssertNotNil(provider);

  FIRStorage *storage1 = [provider storageForBucket:@"randomBucket"];
  XCTAssertNotNil(storage1);
  FIRStorage *storage2 = [provider storageForBucket:@"randomBucket"];
  XCTAssertNotNil(storage2);

  // Ensure that they're different instances but equal objects since everything else matches.
  XCTAssertNotEqual(storage1, storage2);
  XCTAssertEqualObjects(storage1, storage2);

  // Create another bucket with a different provider from above.
  FIRStorage *storage3 = [provider storageForBucket:@"differentBucket"];
  XCTAssertNotNil(storage3);

  // Ensure it's a different object.
  XCTAssertNotEqualObjects(storage2, storage3);
}

#pragma mark - Test Helpers

/// Creates a FIRApp mock with a googleAppID.
- (id)appMockWithOptions {
  id app = OCMClassMock([FIRApp class]);
  OCMStub([app name]).andReturn(@"__FIRAPP_DEFAULT");
  id options = OCMClassMock([FIROptions class]);
  OCMStub([options googleAppID]).andReturn(@"dummyAppID");
  OCMStub([(FIRApp *)app options]).andReturn(options);
  return app;
}

@end
