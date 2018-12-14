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

#import "FIRTestComponents.h"

#import <FirebaseCore/FIRComponent.h>

#pragma mark - Standard Component

@implementation FIRTestClass

/// FIRTestProtocol conformance.
- (void)doSomething {
}

/// FIRComponentRegistrant conformance.
+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *testComponent =
      [FIRComponent componentWithProtocol:@protocol(FIRTestProtocol)
                            creationBlock:^id _Nullable(FIRComponentContainer *_Nonnull container,
                                                        BOOL *_Nonnull isCacheable) {
                              return [[FIRTestClass alloc] init];
                            }];
  return @[ testComponent ];
}

/// FIRComponentLifecycleMaintainer conformance.
- (void)appWillBeDeleted:(FIRApp *)app {
}

@end

/// A test class that is a component registrant, a duplicate of FIRTestClass.
@implementation FIRTestClassDuplicate

- (void)doSomething {
}

/// FIRLibrary conformance.
+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *testComponent =
      [FIRComponent componentWithProtocol:@protocol(FIRTestProtocol)
                            creationBlock:^id _Nullable(FIRComponentContainer *_Nonnull container,
                                                        BOOL *_Nonnull isCacheable) {
                              return [[FIRTestClassDuplicate alloc] init];
                            }];
  return @[ testComponent ];
}

/// FIRComponentLifecycleMaintainer conformance.
- (void)appWillBeDeleted:(FIRApp *)app {
}

@end

#pragma mark - Eager Component

@implementation FIRTestClassEagerCached

/// FIRTestProtocolEager conformance.
- (void)doSomethingFaster {
}

/// FIRLibrary conformance.
+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *testComponent = [FIRComponent
      componentWithProtocol:@protocol(FIRTestProtocolEagerCached)
        instantiationTiming:FIRInstantiationTimingAlwaysEager
               dependencies:@[]
              creationBlock:^id _Nullable(FIRComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                FIRTestClassEagerCached *instance = [[FIRTestClassEagerCached alloc] init];
                *isCacheable = YES;
                [instance doSomethingFaster];
                return instance;
              }];
  return @[ testComponent ];
}

/// FIRComponentLifecycleMaintainer conformance.
- (void)appWillBeDeleted:(FIRApp *)app {
}

- (void)doSomething {
}

@end

#pragma mark - Cached Component

@implementation FIRTestClassCached

/// FIRLibrary conformance.
+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *testComponent = [FIRComponent
      componentWithProtocol:@protocol(FIRTestProtocolCached)
              creationBlock:^id _Nullable(FIRComponentContainer *_Nonnull container,
                                          BOOL *_Nonnull isCacheable) {
                FIRTestClassCached *instanceToCache = [[FIRTestClassCached alloc] init];
                *isCacheable = YES;
                return instanceToCache;
              }];
  return @[ testComponent ];
}

/// FIRComponentLifecycleMaintainer conformance.
- (void)appWillBeDeleted:(FIRApp *)app {
}

- (void)doSomething {
}

@end
