// Copyright 2019 Google
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

#import "GULCCTestComponents.h"

#import <GoogleUtilitiesComponents/GULCCComponent.h>
#import <GoogleUtilitiesComponents/GULCCDependency.h>

#pragma mark - Standard Component

@implementation GULCCTestClass

/// GULCCTestProtocol conformance.
- (void)doSomething {
}

/// GULCCLibrary conformance.
+ (nonnull NSArray<GULCCComponent *> *)componentsToRegister {
  GULCCComponent *testComponent = [GULCCComponent
      componentWithProtocol:@protocol(GULCCTestProtocol)
              creationBlock:^id _Nullable(GULCCComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                return [[GULCCTestClass alloc] init];
              }];
  return @[ testComponent ];
}

/// GULCCComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULCCComponentContainer *)container {
}

@end

/// A test class that is a component registrant, a duplicate of GULCCTestClass.
@implementation GULCCTestClassDuplicate

- (void)doSomething {
}

/// GULCCLibrary conformance.
+ (nonnull NSArray<GULCCComponent *> *)componentsToRegister {
  GULCCComponent *testComponent = [GULCCComponent
      componentWithProtocol:@protocol(GULCCTestProtocol)
              creationBlock:^id _Nullable(GULCCComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                return [[GULCCTestClassDuplicate alloc] init];
              }];
  return @[ testComponent ];
}

/// GULCCComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULCCComponentContainer *)container {
}

@end

#pragma mark - Eager Component

@implementation GULCCTestClassEagerCached

/// GULCCTestProtocolEager conformance.
- (void)doSomethingFaster {
}

/// GULCCLibrary conformance.
+ (nonnull NSArray<GULCCComponent *> *)componentsToRegister {
  GULCCComponent *testComponent = [GULCCComponent
      componentWithProtocol:@protocol(GULCCTestProtocolEagerCached)
        instantiationTiming:GULCCInstantiationTimingAlwaysEager
               dependencies:@[]
              creationBlock:^id _Nullable(GULCCComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                GULCCTestClassEagerCached *instance = [[GULCCTestClassEagerCached alloc] init];
                *isCacheable = YES;
                [instance doSomethingFaster];
                return instance;
              }];
  return @[ testComponent ];
}

/// GULCCComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULCCComponentContainer *)container {
}

@end

#pragma mark - Cached Component

@implementation GULCCTestClassCached

/// GULCCLibrary conformance.
+ (nonnull NSArray<GULCCComponent *> *)componentsToRegister {
  GULCCComponent *testComponent = [GULCCComponent
      componentWithProtocol:@protocol(GULCCTestProtocolCached)
              creationBlock:^id _Nullable(GULCCComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                GULCCTestClassCached *instanceToCache = [[GULCCTestClassCached alloc] init];
                *isCacheable = YES;
                return instanceToCache;
              }];
  return @[ testComponent ];
}

/// GULCCComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULCCComponentContainer *)container {
}

/// GULCCTestProtocolCached conformance.
- (void)cacheCow {
}

@end

#pragma mark - Test Component with Dependency

@implementation GULCCTestClassCachedWithDep

- (instancetype)initWithTest:(id<GULCCTestProtocolCached>)testInstance {
  self = [super init];
  if (self != nil) {
    self.testProperty = testInstance;
  }
  return self;
}

- (void)containerWillBeEmptied:(GULCCComponentContainer *)container {
  // Do something that depends on the instance from our dependency.
  [self.testProperty cacheCow];

  // Fetch from the container in the deletion function.
  id<GULCCTestProtocolCached> anotherInstance = GUL_COMPONENT(GULCCTestProtocolCached, container);
  [anotherInstance cacheCow];
}

+ (nonnull NSArray<GULCCComponent *> *)componentsToRegister {
  GULCCDependency *dep =
      [GULCCDependency dependencyWithProtocol:@protocol(GULCCTestProtocolCached)];
  GULCCComponent *testComponent = [GULCCComponent
      componentWithProtocol:@protocol(GULCCTestProtocolCachedWithDep)
        instantiationTiming:GULCCInstantiationTimingLazy
               dependencies:@[ dep ]
              creationBlock:^id _Nullable(GULCCComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                // Fetch from the container in the instantiation block.
                *isCacheable = YES;

                id<GULCCTestProtocolCached> test =
                    GUL_COMPONENT(GULCCTestProtocolCached, container);
                GULCCTestClassCachedWithDep *instance =
                    [[GULCCTestClassCachedWithDep alloc] initWithTest:test];
                return instance;
              }];
  return @[ testComponent ];
}

@end
