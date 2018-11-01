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

#import "FIRDatabaseComponent.h"

#import "FIRDatabase_Private.h"

#import <FirebaseAuthInterop/FIRAuthInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRComponentRegistrant.h>
#import <FirebaseCore/FIRDependency.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRDatabase ()

@end

@interface FIRDatabaseComponent () <FIRComponentRegistrant>
/// Internal intializer.
- (instancetype)initWithApp:(FIRApp *)app;
@end

@implementation FIRDatabaseComponent

#pragma mark - Initialization

- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
  }
  return self;
}

#pragma mark - Lifecycle

+ (void)load {
  [FIRComponentContainer registerAsComponentRegistrant:self];
}

#pragma mark - FIRComponentRegistrant

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *authDep =
      [FIRDependency dependencyWithProtocol:@protocol(FIRAuthInterop) isRequired:NO];
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
        return [[FIRDatabaseComponent alloc] initWithApp:container.app];
      };
  FIRComponent *databaseProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRDatabaseProvider)
                      instantiationTiming:FIRInstantiationTimingLazy
                             dependencies:@[ authDep ]
                            creationBlock:creationBlock];
  return @[ databaseProvider ];
}

#pragma mark - FIRDatabaseProvider Conformance

- (FIRDatabase *)databaseForApp:(FIRApp *)app URL:(NSString *)url {
  id<FIRAuthInterop> auth = FIR_COMPONENT(FIRAuthInterop, self.app.container);
  return [FIRDatabase databaseForApp:app URL:url];
}

@end

NS_ASSUME_NONNULL_END
