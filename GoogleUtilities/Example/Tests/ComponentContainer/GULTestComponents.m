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

#import "GULTestComponents.h"

#import <GoogleUtilities/GULComponent.h>
#import <GoogleUtilities/GULDependency.h>

#pragma mark - Standard Component

@implementation GULTestClass

/// GULTestProtocol conformance.
- (void)doSomething {
}

/// GULComponentRegistrant conformance.
+ (nonnull NSArray<GULComponent *> *)componentsToRegister {
  GULComponent *testComponent =
      [GULComponent componentWithProtocol:@protocol(GULTestProtocol)
                            creationBlock:^id _Nullable(GULComponentContainer *_Nonnull container,
                                                        BOOL *_Nonnull isCacheable) {
                              return [[GULTestClass alloc] init];
                            }];
  return @[ testComponent ];
}

/// GULComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULComponentContainer *)container {
}

@end

/// A test class that is a component registrant, a duplicate of GULTestClass.
@implementation GULTestClassDuplicate

- (void)doSomething {
}

/// GULLibrary conformance.
+ (nonnull NSArray<GULComponent *> *)componentsToRegister {
  GULComponent *testComponent =
      [GULComponent componentWithProtocol:@protocol(GULTestProtocol)
                            creationBlock:^id _Nullable(GULComponentContainer *_Nonnull container,
                                                        BOOL *_Nonnull isCacheable) {
                              return [[GULTestClassDuplicate alloc] init];
                            }];
  return @[ testComponent ];
}

/// GULComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULComponentContainer *)container {
}

@end

#pragma mark - Eager Component

@implementation GULTestClassEagerCached

/// GULTestProtocolEager conformance.
- (void)doSomethingFaster {
}

/// GULLibrary conformance.
+ (nonnull NSArray<GULComponent *> *)componentsToRegister {
  GULComponent *testComponent = [GULComponent
      componentWithProtocol:@protocol(GULTestProtocolEagerCached)
        instantiationTiming:GULInstantiationTimingAlwaysEager
               dependencies:@[]
              creationBlock:^id _Nullable(GULComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                GULTestClassEagerCached *instance = [[GULTestClassEagerCached alloc] init];
                *isCacheable = YES;
                [instance doSomethingFaster];
                return instance;
              }];
  return @[ testComponent ];
}

/// GULComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULComponentContainer *)container {
}

@end

#pragma mark - Cached Component

@implementation GULTestClassCached

/// GULLibrary conformance.
+ (nonnull NSArray<GULComponent *> *)componentsToRegister {
  GULComponent *testComponent = [GULComponent
      componentWithProtocol:@protocol(GULTestProtocolCached)
              creationBlock:^id _Nullable(GULComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                GULTestClassCached *instanceToCache = [[GULTestClassCached alloc] init];
                *isCacheable = YES;
                return instanceToCache;
              }];
  return @[ testComponent ];
}

/// GULComponentLifecycleMaintainer conformance.
- (void)containerWillBeEmptied:(GULComponentContainer *)container {
}

/// GULTestProtocolCached conformance.
- (void)cacheCow {
}

@end

#pragma mark - Test Component with Dependency

@implementation GULTestClassCachedWithDep

- (instancetype)initWithTest:(id<GULTestProtocolCached>)testInstance {
  self = [super init];
  if (self != nil) {
    self.testProperty = testInstance;
  }
  return self;
}

- (void)containerWillBeEmptied:(GULComponentContainer *)container {
  // Do something that depends on the instance from our dependency.
  [self.testProperty cacheCow];

  // Fetch from the container in the deletion function.
  id<GULTestProtocolCached> anotherInstance = GUL_COMPONENT(GULTestProtocolCached, container);
  [anotherInstance cacheCow];
}

+ (nonnull NSArray<GULComponent *> *)componentsToRegister {
  GULDependency *dep = [GULDependency dependencyWithProtocol:@protocol(GULTestProtocolCached)];
  GULComponent *testComponent = [GULComponent
      componentWithProtocol:@protocol(GULTestProtocolCachedWithDep)
        instantiationTiming:GULInstantiationTimingLazy
               dependencies:@[ dep ]
              creationBlock:^id _Nullable(GULComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                // Fetch from the container in the instantiation block.
                *isCacheable = YES;

                id<GULTestProtocolCached> test = GUL_COMPONENT(GULTestProtocolCached, container);
                GULTestClassCachedWithDep *instance =
                    [[GULTestClassCachedWithDep alloc] initWithTest:test];
                return instance;
              }];
  return @[ testComponent ];
}

@end
