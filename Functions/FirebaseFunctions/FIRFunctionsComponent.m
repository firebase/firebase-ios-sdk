// Copyright 2021 Google LLC
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

#import <os/lock.h>

#import "Functions/FirebaseFunctions/FIRFunctionsComponent.h"

#import "Functions/FirebaseFunctions/FIRFunctions_Private.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

@interface FIRFunctionsComponent () <FIRLibrary, FIRFunctionsProvider>

/// A map of active instances, grouped by app. Keys are FIRApp names and values are arrays
/// containing all instances of FIRFunctions associated with the given app.
@property(nonatomic) NSMutableDictionary<NSString *, NSMutableArray<FIRFunctions *> *> *instances;

/// Internal intializer.
- (instancetype)initWithApp:(FIRApp *)app;

@end

@implementation FIRFunctionsComponent {
  os_unfair_lock _instancesLock;
}

#pragma mark - Initialization

- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
    _instances = [NSMutableDictionary dictionary];
    _instancesLock = OS_UNFAIR_LOCK_INIT;
  }
  return self;
}

#pragma mark - Lifecycle

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-fun"];
}

#pragma mark - FIRComponentRegistrant

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    return [[self alloc] initWithApp:container.app];
  };
  FIRDependency *auth = [FIRDependency dependencyWithProtocol:@protocol(FIRAuthInterop)
                                                   isRequired:NO];
  FIRComponent *internalProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRFunctionsProvider)
                      instantiationTiming:FIRInstantiationTimingLazy
                             dependencies:@[ auth ]
                            creationBlock:creationBlock];
  return @[ internalProvider ];
}

#pragma mark - Instance management

- (void)appWillBeDeleted:(FIRApp *)app {
  NSString *appName = app.name;
  if (appName == nil) {
    return;
  }

  os_unfair_lock_lock(&_instancesLock);
  [self.instances removeObjectForKey:appName];
  os_unfair_lock_unlock(&_instancesLock);
}

#pragma mark - FIRFunctionsProvider Conformance

- (FIRFunctions *)functionsForApp:(FIRApp *)app
                           region:(NSString *)region
                     customDomain:(NSString *_Nullable)customDomain
                             type:(Class)cls {
  os_unfair_lock_lock(&_instancesLock);
  NSArray<FIRFunctions *> *associatedInstances = [self instances][app.name];
  if (associatedInstances.count > 0) {
    for (FIRFunctions *instance in associatedInstances) {
      // Domains may be nil, so handle with care
      BOOL equalDomains = NO;
      if (instance.customDomain != nil) {
        equalDomains = [customDomain isEqualToString:instance.customDomain];
      } else {
        equalDomains = customDomain == nil;
      }
      if ([instance.region isEqualToString:region] && equalDomains) {
        os_unfair_lock_unlock(&_instancesLock);
        return instance;
      }
    }
  }

  FIRFunctions *newInstance = [[cls alloc] initWithApp:app region:region customDomain:customDomain];

  if (self.instances[app.name] == nil) {
    NSMutableArray *array = [NSMutableArray arrayWithObject:newInstance];
    self.instances[app.name] = array;
  } else {
    [self.instances[app.name] addObject:newInstance];
  }
  os_unfair_lock_unlock(&_instancesLock);
  return newInstance;
}

@end
