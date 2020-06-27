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

#import <XCTest/XCTest.h>

#import <GoogleUtilitiesComponents/GULCCComponent.h>
#import <GoogleUtilitiesComponents/GULCCComponentContainerInternal.h>

#import "GULCCTestComponents.h"

/// Internally exposed methods and properties for testing.
@interface GULCCComponentContainer (TestInternal)

@property(nonatomic, strong)
    NSMutableDictionary<NSString *, GULCCComponentCreationBlock> *components;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *cachedInstances;

+ (void)registerAsComponentRegistrant:(Class<GULCCLibrary>)klass
                                inSet:(NSMutableSet<Class> *)allRegistrants;

@end

@interface GULCCComponentContainer (TestInternalImplementations)
- (instancetype)initWithContext:(id)context
                     components:(NSDictionary<NSString *, GULCCComponentCreationBlock> *)components;
@end

@implementation GULCCComponentContainer (TestInternalImplementations)

- (instancetype)initWithContext:(id)context
                     components:
                         (NSDictionary<NSString *, GULCCComponentCreationBlock> *)components {
  self = [self initWithContext:context registrants:[[NSMutableSet alloc] init]];
  if (self) {
    self.components = [components mutableCopy];
  }
  return self;
}

@end

@interface GULCCComponentContainerTest : XCTestCase {
  /// Stored context, since the container has a `weak` reference to it.
  id _context;
}

@end

@implementation GULCCComponentContainerTest

- (void)tearDown {
  _context = nil;
  [super tearDown];
}

#pragma mark - Registration Tests

- (void)testRegisteringConformingClass {
  NSMutableSet<Class> *allRegistrants = [NSMutableSet<Class> set];
  Class testClass = [GULCCTestClass class];
  [GULCCComponentContainer registerAsComponentRegistrant:testClass inSet:allRegistrants];
  XCTAssertTrue([allRegistrants containsObject:testClass]);
}

- (void)testComponentsPopulatedOnInit {
  GULCCComponentContainer *container = [self containerWithRegistrants:@[ [GULCCTestClass class] ]];

  // Verify that the block is stored.
  NSString *protocolName = NSStringFromProtocol(@protocol(GULCCTestProtocol));
  GULCCComponentCreationBlock creationBlock = container.components[protocolName];
  XCTAssertNotNil(creationBlock);
}

#pragma mark - Caching Tests

- (void)testInstanceCached {
  GULCCComponentContainer *container =
      [self containerWithRegistrants:@[ [GULCCTestClassCached class] ]];

  // Fetch an instance for `GULCCTestProtocolCached`, then fetch it again to assert it's cached.
  id<GULCCTestProtocolCached> instance1 = GUL_COMPONENT(GULCCTestProtocolCached, container);
  XCTAssertNotNil(instance1);
  id<GULCCTestProtocolCached> instance2 = GUL_COMPONENT(GULCCTestProtocolCached, container);
  XCTAssertNotNil(instance2);
  XCTAssertEqual(instance1, instance2);
}

- (void)testInstanceNotCached {
  GULCCComponentContainer *container = [self containerWithRegistrants:@[ [GULCCTestClass class] ]];

  // Retrieve an instance from the container, then fetch it again and ensure it's not the same
  // instance.
  id<GULCCTestProtocol> instance1 = GUL_COMPONENT(GULCCTestProtocol, container);
  XCTAssertNotNil(instance1);
  id<GULCCTestProtocol> instance2 = GUL_COMPONENT(GULCCTestProtocol, container);
  XCTAssertNotNil(instance2);
  XCTAssertNotEqual(instance1, instance2);
}

- (void)testRemoveAllCachedInstances {
  GULCCComponentContainer *container = [self containerWithRegistrants:@[
    [GULCCTestClass class], [GULCCTestClassCached class], [GULCCTestClassEagerCached class],
    [GULCCTestClassCachedWithDep class]
  ]];

  // Retrieve an instance of GULCCTestClassCached to ensure it's cached.
  id<GULCCTestProtocolCached> cachedInstance1 = GUL_COMPONENT(GULCCTestProtocolCached, container);
  id<GULCCTestProtocolEagerCached> eagerInstance1 =
      GUL_COMPONENT(GULCCTestProtocolEagerCached, container);

  // GULCCTestClassEagerCached and GULCCTestClassCached instances should be cached at this point.
  XCTAssertTrue(container.cachedInstances.count == 2);

  // Remove the instances and verify cachedInstances is empty, and that new instances returned from
  // the container don't match the old ones.
  [container removeAllCachedInstances];
  XCTAssertTrue(container.cachedInstances.count == 0);

  id<GULCCTestProtocolCached> cachedInstance2 = GUL_COMPONENT(GULCCTestProtocolCached, container);
  XCTAssertNotEqual(cachedInstance1, cachedInstance2);
  id<GULCCTestProtocolEagerCached> eagerInstance2 =
      GUL_COMPONENT(GULCCTestProtocolEagerCached, container);
  XCTAssertNotEqual(eagerInstance1, eagerInstance2);
}

#pragma mark - Instantiation Tests

- (void)testEagerInstantiation {
  // Create a container with `GULCCTestClassEagerCached` as a registrant, which provides the
  // implementation for `GULCCTestProtocolEagerCached` and requires eager instantiation as well as
  // caching so the test can verify it was eagerly instantiated.
  GULCCComponentContainer *container =
      [self containerWithRegistrants:@[ [GULCCTestClassEagerCached class] ]];
  NSString *protocolName = NSStringFromProtocol(@protocol(GULCCTestProtocolEagerCached));
  XCTAssertNotNil(container.cachedInstances[protocolName]);
}

#pragma mark - Input Validation Tests

- (void)testProtocolAlreadyRegistered {
  // Register two classes that provide the same protocol. Only one should be stored, and there
  // should be a log stating that the protocol has already been registered. Right now there's no
  // guarantee which one will be registered first since it's an NSSet under the hood, but that could
  // change in the future.
  // TODO(wilsonryan): Assert that the log gets called warning that it's already been registered.
  GULCCComponentContainer *container =
      [self containerWithRegistrants:@[ [GULCCTestClass class], [GULCCTestClassDuplicate class] ]];
  XCTAssert(container.components.count == 1);
}

#pragma mark - Dependency Tests

- (void)testDependencyDoesntBlock {
  /// Test a class that has a dependency, and fetching doesn't block the internal queue.
  GULCCComponentContainer *container = [self containerWithRegistrants:@[
    [GULCCTestClassCached class], [GULCCTestClassCachedWithDep class]
  ]];
  XCTAssert(container.components.count == 2);

  id<GULCCTestProtocolCachedWithDep> instanceWithDep =
      GUL_COMPONENT(GULCCTestProtocolCachedWithDep, container);
  XCTAssertNotNil(instanceWithDep);
}

- (void)testDependencyRemoveAllCachedInstancesDoesntBlock {
  /// Test a class that has a dependency, and fetching doesn't block the internal queue.
  GULCCComponentContainer *container = [self containerWithRegistrants:@[
    [GULCCTestClassCached class], [GULCCTestClassCachedWithDep class]
  ]];
  XCTAssert(container.components.count == 2);

  id<GULCCTestProtocolCachedWithDep> instanceWithDep =
      GUL_COMPONENT(GULCCTestProtocolCachedWithDep, container);
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
- (GULCCComponentContainer *)containerWithRegistrants:(NSArray<Class> *)registrants {
  NSMutableSet<Class> *allRegistrants = [NSMutableSet<Class> set];

  // Initialize the container with the test classes.
  for (Class c in registrants) {
    [GULCCComponentContainer registerAsComponentRegistrant:c inSet:allRegistrants];
  }

  GULCCComponentContainer *container =
      [[GULCCComponentContainer alloc] initWithContext:nil registrants:allRegistrants];

  // Instantiate all the components that were eagerly registered now that all other properties are
  // configured.
  [container instantiateEagerComponents];

  return container;
}

@end
