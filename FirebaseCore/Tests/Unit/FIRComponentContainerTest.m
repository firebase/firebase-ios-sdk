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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

#import "FirebaseCore/Sources/FIRComponentContainerInternal.h"
#import "FirebaseCore/Sources/Private/FIRComponentType.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseCore/Tests/Unit/FIRTestComponents.h"
#import "SharedTestUtilities/FIROptionsMock.h"

/// Internally exposed methods and properties for testing.
@interface FIRComponentContainer (TestInternal)

@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRComponentCreationBlock> *components;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *cachedInstances;

+ (void)registerAsComponentRegistrant:(Class<FIRLibrary>)klass
                                inSet:(NSMutableSet<Class> *)allRegistrants;
- (instancetype)initWithApp:(FIRApp *)app registrants:(NSMutableSet<Class> *)allRegistrants;
@end

@interface FIRComponentContainer (TestInternalImplementations)
- (instancetype)initWithApp:(FIRApp *)app
                 components:(NSDictionary<NSString *, FIRComponentCreationBlock> *)components;
@end

@implementation FIRComponentContainer (TestInternalImplementations)

- (instancetype)initWithApp:(FIRApp *)app
                 components:(NSDictionary<NSString *, FIRComponentCreationBlock> *)components {
  self = [self initWithApp:app registrants:[[NSMutableSet alloc] init]];
  if (self) {
    self.components = [components mutableCopy];
  }
  return self;
}

@end

@interface FIRComponentContainerTest : FIRTestCase {
  FIRApp *_hostApp;
}

@end

@implementation FIRComponentContainerTest

- (void)tearDown {
  _hostApp = nil;
  [super tearDown];
}

#pragma mark - Registration Tests

- (void)testRegisteringConformingClass {
  NSMutableSet<Class> *allRegistrants = [NSMutableSet<Class> set];
  Class testClass = [FIRTestClass class];
  [FIRComponentContainer registerAsComponentRegistrant:testClass inSet:allRegistrants];
  XCTAssertTrue([allRegistrants containsObject:testClass]);
}

- (void)testComponentsPopulatedOnInit {
  FIRComponentContainer *container = [self containerWithRegistrants:@[ [FIRTestClass class] ]];

  // Verify that the block is stored.
  NSString *protocolName = NSStringFromProtocol(@protocol(FIRTestProtocol));
  FIRComponentCreationBlock creationBlock = container.components[protocolName];
  XCTAssertNotNil(creationBlock);
}

#pragma mark - Caching Tests

- (void)testInstanceCached {
  FIRComponentContainer *container =
      [self containerWithRegistrants:@[ [FIRTestClassCached class] ]];

  // Fetch an instance for `FIRTestProtocolCached`, then fetch it again to assert it's cached.
  id<FIRTestProtocolCached> instance1 = FIR_COMPONENT(FIRTestProtocolCached, container);
  XCTAssertNotNil(instance1);
  id<FIRTestProtocolCached> instance2 = FIR_COMPONENT(FIRTestProtocolCached, container);
  XCTAssertNotNil(instance2);
  XCTAssertEqual(instance1, instance2);
}

- (void)testInstanceNotCached {
  FIRComponentContainer *container = [self containerWithRegistrants:@[ [FIRTestClass class] ]];

  // Retrieve an instance from the container, then fetch it again and ensure it's not the same
  // instance.
  id<FIRTestProtocol> instance1 = FIR_COMPONENT(FIRTestProtocol, container);
  XCTAssertNotNil(instance1);
  id<FIRTestProtocol> instance2 = FIR_COMPONENT(FIRTestProtocol, container);
  XCTAssertNotNil(instance2);
  XCTAssertNotEqual(instance1, instance2);
}

- (void)testRemoveAllCachedInstances {
  FIRComponentContainer *container = [self containerWithRegistrants:@[
    [FIRTestClass class], [FIRTestClassCached class], [FIRTestClassEagerCached class],
    [FIRTestClassCachedWithDep class]
  ]];

  // Retrieve an instance of FIRTestClassCached to ensure it's cached.
  id<FIRTestProtocolCached> cachedInstance1 = FIR_COMPONENT(FIRTestProtocolCached, container);
  id<FIRTestProtocolEagerCached> eagerInstance1 =
      FIR_COMPONENT(FIRTestProtocolEagerCached, container);

  // FIRTestClassEagerCached and FIRTestClassCached instances should be cached at this point.
  XCTAssertTrue(container.cachedInstances.count == 2);

  // Remove the instances and verify cachedInstances is empty, and that new instances returned from
  // the container don't match the old ones.
  [container removeAllCachedInstances];
  XCTAssertTrue(container.cachedInstances.count == 0);

  id<FIRTestProtocolCached> cachedInstance2 = FIR_COMPONENT(FIRTestProtocolCached, container);
  XCTAssertNotEqual(cachedInstance1, cachedInstance2);
  id<FIRTestProtocolEagerCached> eagerInstance2 =
      FIR_COMPONENT(FIRTestProtocolEagerCached, container);
  XCTAssertNotEqual(eagerInstance1, eagerInstance2);
}

- (void)testRemoveAllComponents {
  FIRComponentContainer *container = [self containerWithRegistrants:@[
    [FIRTestClass class], [FIRTestClassCached class], [FIRTestClassEagerCached class],
    [FIRTestClassCachedWithDep class]
  ]];

  // Retrieve an instance of FIRTestClassCached to ensure it's cached.
  id<FIRTestProtocolCached> cachedInstance1 = FIR_COMPONENT(FIRTestProtocolCached, container);
  XCTAssertNotNil(cachedInstance1);
  id<FIRTestProtocolEagerCached> eagerInstance1 =
      FIR_COMPONENT(FIRTestProtocolEagerCached, container);
  XCTAssertNotNil(eagerInstance1);

  // FIRTestClassEagerCached and FIRTestClassCached instances should be cached at this point.
  XCTAssertTrue(container.cachedInstances.count == 2);

  // Remove all components.
  [container removeAllComponents];

  // Remove the instances.
  [container removeAllCachedInstances];

  // Verify that no new instances are created.
  id<FIRTestProtocolCached> cachedInstance2 = FIR_COMPONENT(FIRTestProtocolCached, container);
  XCTAssertNil(cachedInstance2);
  id<FIRTestProtocolEagerCached> eagerInstance2 =
      FIR_COMPONENT(FIRTestProtocolEagerCached, container);
  XCTAssertNil(eagerInstance2);
}

#pragma mark - Instantiation Tests

- (void)testEagerInstantiation {
  // Create a container with `FIRTestClassEagerCached` as a registrant, which provides the
  // implementation for `FIRTestProtocolEagerCached` and requires eager instantiation as well as
  // caching so the test can verify it was eagerly instantiated.
  FIRComponentContainer *container =
      [self containerWithRegistrants:@[ [FIRTestClassEagerCached class] ]];
  NSString *protocolName = NSStringFromProtocol(@protocol(FIRTestProtocolEagerCached));
  XCTAssertNotNil(container.cachedInstances[protocolName]);
}

#pragma mark - Input Validation Tests

- (void)testProtocolAlreadyRegistered {
  // Register two classes that provide the same protocol. Only one should be stored, and there
  // should be a log stating that the protocol has already been registered. Right now there's no
  // guarantee which one will be registered first since it's an NSSet under the hood, but that could
  // change in the future.
  // TODO(wilsonryan): Assert that the log gets called warning that it's already been registered.
  FIRComponentContainer *container =
      [self containerWithRegistrants:@[ [FIRTestClass class], [FIRTestClassDuplicate class] ]];
  XCTAssert(container.components.count == 1);
}

#pragma mark - Dependency Tests

- (void)testDependencyDoesntBlock {
  /// Test a class that has a dependency, and fetching doesn't block the internal queue.
  FIRComponentContainer *container = [self
      containerWithRegistrants:@[ [FIRTestClassCached class], [FIRTestClassCachedWithDep class] ]];
  XCTAssert(container.components.count == 2);

  id<FIRTestProtocolCachedWithDep> instanceWithDep =
      FIR_COMPONENT(FIRTestProtocolCachedWithDep, container);
  XCTAssertNotNil(instanceWithDep);
}

- (void)testDependencyRemoveAllCachedInstancesDoesntBlock {
  /// Test a class that has a dependency, and fetching doesn't block the internal queue.
  FIRComponentContainer *container = [self
      containerWithRegistrants:@[ [FIRTestClassCached class], [FIRTestClassCachedWithDep class] ]];
  XCTAssert(container.components.count == 2);

  id<FIRTestProtocolCachedWithDep> instanceWithDep =
      FIR_COMPONENT(FIRTestProtocolCachedWithDep, container);
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
- (FIRComponentContainer *)containerWithRegistrants:(NSArray<Class> *)registrants {
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:kGoogleAppID
                                                    GCMSenderID:kGCMSenderID];
  _hostApp = [[FIRApp alloc] initInstanceWithName:@"fake_app" options:options];
  NSMutableSet<Class> *allRegistrants = [NSMutableSet<Class> set];

  // Initialize the container with the test classes.
  for (Class c in registrants) {
    [FIRComponentContainer registerAsComponentRegistrant:c inSet:allRegistrants];
  }

  // Override the app's container with the newly instantiated container.
  FIRComponentContainer *container = [[FIRComponentContainer alloc] initWithApp:_hostApp
                                                                    registrants:allRegistrants];
  _hostApp.container = container;

  // Instantiate all the components that were eagerly registered now that all other properties are
  // configured.
  [container instantiateEagerComponents];

  return container;
}

@end
