// Copyright 2018 Google
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

#import <XCTest/XCTestCase.h>

#import <GoogleUtilitiesComponentContainer/GULComponent.h>
#import <GoogleUtilitiesComponentContainer/GULComponentContainerInternal.h>
#import <OCMock/OCMock.h>

#import "GULTestComponents.h"

/// Internally exposed methods and properties for testing.
@interface GULComponentContainer (TestInternal)

@property(nonatomic, strong) NSMutableDictionary<NSString *, GULComponentCreationBlock> *components;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *cachedInstances;

+ (void)registerAsComponentRegistrant:(Class<GULLibrary>)klass
                                inSet:(NSMutableSet<Class> *)allRegistrants;

@end

@interface GULComponentContainer (TestInternalImplementations)
- (instancetype)initWithContext:(id)context
                     components:(NSDictionary<NSString *, GULComponentCreationBlock> *)components;
@end

@implementation GULComponentContainer (TestInternalImplementations)

- (instancetype)initWithContext:(id)context
                     components:(NSDictionary<NSString *, GULComponentCreationBlock> *)components {
  self = [self initWithContext:context registrants:[[NSMutableSet alloc] init]];
  if (self) {
    self.components = [components mutableCopy];
  }
  return self;
}

@end

@interface GULComponentContainerTest : XCTestCase {
  /// Stored context, since the container has a `weak` reference to it.
  id _context;
}

@end

@implementation GULComponentContainerTest

- (void)tearDown {
  _context = nil;
  [super tearDown];
}

#pragma mark - Registration Tests

- (void)testRegisteringConformingClass {
  NSMutableSet<Class> *allRegistrants = [NSMutableSet<Class> set];
  Class testClass = [GULTestClass class];
  [GULComponentContainer registerAsComponentRegistrant:testClass inSet:allRegistrants];
  XCTAssertTrue([allRegistrants containsObject:testClass]);
}

- (void)testComponentsPopulatedOnInit {
  GULComponentContainer *container = [self containerWithRegistrants:@ [[GULTestClass class]]];

  // Verify that the block is stored.
  NSString *protocolName = NSStringFromProtocol(@protocol(GULTestProtocol));
  GULComponentCreationBlock creationBlock = container.components[protocolName];
  OCMExpect(creationBlock);
}

#pragma mark - Caching Tests

- (void)testInstanceCached {
  GULComponentContainer *container = [self containerWithRegistrants:@ [[GULTestClassCached class]]];

  // Fetch an instance for `GULTestProtocolCached`, then fetch it again to assert it's cached.
  id<GULTestProtocolCached> instance1 = GUL_COMPONENT(GULTestProtocolCached, container);
  XCTAssertNotNil(instance1);
  id<GULTestProtocolCached> instance2 = GUL_COMPONENT(GULTestProtocolCached, container);
  XCTAssertNotNil(instance2);
  XCTAssertEqual(instance1, instance2);
}

- (void)testInstanceNotCached {
  GULComponentContainer *container = [self containerWithRegistrants:@ [[GULTestClass class]]];

  // Retrieve an instance from the container, then fetch it again and ensure it's not the same
  // instance.
  id<GULTestProtocol> instance1 = GUL_COMPONENT(GULTestProtocol, container);
  XCTAssertNotNil(instance1);
  id<GULTestProtocol> instance2 = GUL_COMPONENT(GULTestProtocol, container);
  XCTAssertNotNil(instance2);
  XCTAssertNotEqual(instance1, instance2);
}

- (void)testRemoveAllCachedInstances {
  GULComponentContainer *container =
      [self containerWithRegistrants:@ [[GULTestClass class], [GULTestClassCached class],
                                        [GULTestClassEagerCached class],
                                        [GULTestClassCachedWithDep class]]];

  // Retrieve an instance of GULTestClassCached to ensure it's cached.
  id<GULTestProtocolCached> cachedInstance1 = GUL_COMPONENT(GULTestProtocolCached, container);
  id<GULTestProtocolEagerCached> eagerInstance1 =
      GUL_COMPONENT(GULTestProtocolEagerCached, container);

  // GULTestClassEagerCached and GULTestClassCached instances should be cached at this point.
  XCTAssertTrue(container.cachedInstances.count == 2);

  // Remove the instances and verify cachedInstances is empty, and that new instances returned from
  // the container don't match the old ones.
  [container removeAllCachedInstances];
  XCTAssertTrue(container.cachedInstances.count == 0);

  id<GULTestProtocolCached> cachedInstance2 = GUL_COMPONENT(GULTestProtocolCached, container);
  XCTAssertNotEqual(cachedInstance1, cachedInstance2);
  id<GULTestProtocolEagerCached> eagerInstance2 =
      GUL_COMPONENT(GULTestProtocolEagerCached, container);
  XCTAssertNotEqual(eagerInstance1, eagerInstance2);
}

#pragma mark - Instantiation Tests

- (void)testEagerInstantiation {
  // Create a container with `GULTestClassEagerCached` as a registrant, which provides the
  // implementation for `GULTestProtocolEagerCached` and requires eager instantiation as well as
  // caching so the test can verify it was eagerly instantiated.
  GULComponentContainer *container =
      [self containerWithRegistrants:@ [[GULTestClassEagerCached class]]];
  NSString *protocolName = NSStringFromProtocol(@protocol(GULTestProtocolEagerCached));
  XCTAssertNotNil(container.cachedInstances[protocolName]);
}

#pragma mark - Input Validation Tests

- (void)testProtocolAlreadyRegistered {
  // Register two classes that provide the same protocol. Only one should be stored, and there
  // should be a log stating that the protocol has already been registered. Right now there's no
  // guarantee which one will be registered first since it's an NSSet under the hood, but that could
  // change in the future.
  // TODO(wilsonryan): Assert that the log gets called warning that it's already been registered.
  GULComponentContainer *container =
      [self containerWithRegistrants:@ [[GULTestClass class], [GULTestClassDuplicate class]]];
  XCTAssert(container.components.count == 1);
}

#pragma mark - Dependency Tests

- (void)testDependencyDoesntBlock {
  /// Test a class that has a dependency, and fetching doesn't block the internal queue.
  GULComponentContainer *container = [self
      containerWithRegistrants:@ [[GULTestClassCached class], [GULTestClassCachedWithDep class]]];
  XCTAssert(container.components.count == 2);

  id<GULTestProtocolCachedWithDep> instanceWithDep =
      GUL_COMPONENT(GULTestProtocolCachedWithDep, container);
  XCTAssertNotNil(instanceWithDep);
}

- (void)testDependencyRemoveAllCachedInstancesDoesntBlock {
  /// Test a class that has a dependency, and fetching doesn't block the internal queue.
  GULComponentContainer *container = [self
      containerWithRegistrants:@ [[GULTestClassCached class], [GULTestClassCachedWithDep class]]];
  XCTAssert(container.components.count == 2);

  id<GULTestProtocolCachedWithDep> instanceWithDep =
      GUL_COMPONENT(GULTestProtocolCachedWithDep, container);
  XCTAssertNotNil(instanceWithDep);
  XCTAssertNotNil(instanceWithDep.testProperty);

  // Both `instanceWithDep` and `testProperty` should be cached now.
  XCTAssertTrue(container.cachedInstances.count == 2);

  // Remove the instances and verify cachedInstances is empty, and doesn't block the queue.
  [container removeAllCachedInstances];
  XCTAssertTrue(container.cachedInstances.count == 0);
}

#pragma mark - Convenience Methods

/// Create a container that has registered the test class.
- (GULComponentContainer *)containerWithRegistrants:(NSArray<Class> *)registrants {
  NSMutableSet<Class> *allRegistrants = [NSMutableSet<Class> set];

  // Initialize the container with the test classes.
  for (Class c in registrants) {
    [GULComponentContainer registerAsComponentRegistrant:c inSet:allRegistrants];
  }

  GULComponentContainer *container = [[GULComponentContainer alloc] initWithContext:nil
                                                                        registrants:allRegistrants];

  // Instantiate all the components that were eagerly registered now that all other properties are
  // configured.
  [container instantiateEagerComponents];

  return container;
}

@end
