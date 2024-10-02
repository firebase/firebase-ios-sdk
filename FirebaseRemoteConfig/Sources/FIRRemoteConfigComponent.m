/*
 * Copyright 2019 Google
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

#import "FirebaseRemoteConfig/Sources/FIRRemoteConfigComponent.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

@implementation FIRRemoteConfigComponent

// Because Component now need to register two protocols (provider and interop), we need a way to
// return the same component instance for both registered protocol, this singleton pattern allow us
// to return the same component object for both registration callback.
static NSMutableDictionary<NSString *, FIRRemoteConfigComponent *> *_componentInstances = nil;

+ (FIRRemoteConfigComponent *)getComponentForApp:(FIRApp *)app {
  @synchronized(_componentInstances) {
    // need to init the dictionary first
    if (!_componentInstances) {
      _componentInstances = [[NSMutableDictionary alloc] init];
    }
    if (![_componentInstances objectForKey:app.name]) {
      _componentInstances[app.name] = [[self alloc] initWithApp:app];
    }
    return _componentInstances[app.name];
  }
  return nil;
}

+ (void)clearAllComponentInstances {
  @synchronized(_componentInstances) {
    [_componentInstances removeAllObjects];
  }
}

/// Default method for retrieving a Remote Config instance, or creating one if it doesn't exist.
- (FIRRemoteConfig *)remoteConfigForNamespace:(NSString *)remoteConfigNamespace {
  if (!remoteConfigNamespace) {
    // TODO: Throw an error? Return nil? What do we want to do?
    return nil;
  }

  // Validate the required information is available.
  FIROptions *options = self.app.options;
  NSString *errorPropertyName;
  if (options.googleAppID.length == 0) {
    errorPropertyName = @"googleAppID";
  } else if (options.GCMSenderID.length == 0) {
    errorPropertyName = @"GCMSenderID";
  } else if (options.projectID.length == 0) {
    errorPropertyName = @"projectID";
  }

  if (errorPropertyName) {
    NSString *const kFirebaseConfigErrorDomain = @"com.firebase.config";
    [NSException
         raise:kFirebaseConfigErrorDomain
        format:@"%@",
               [NSString
                   stringWithFormat:
                       @"Firebase Remote Config is missing the required %@ property from the "
                       @"configured FirebaseApp and will not be able to function properly. Please "
                       @"fix this issue to ensure that Firebase is correctly configured.",
                       errorPropertyName]];
  }

  FIRRemoteConfig *instance = self.instances[remoteConfigNamespace];
  if (!instance) {
    FIRApp *app = self.app;
    id<FIRAnalyticsInterop> analytics =
        app.isDefaultApp ? FIR_COMPONENT(FIRAnalyticsInterop, app.container) : nil;
    instance = [[FIRRemoteConfig alloc] initWithAppName:app.name
                                             FIROptions:app.options
                                              namespace:remoteConfigNamespace
                                              DBManager:[RCNConfigDBManager sharedInstance]
                                          configContent:[RCNConfigContent sharedInstance]
                                              analytics:analytics];
    self.instances[remoteConfigNamespace] = instance;
  }

  return instance;
}

/// Default initializer.
- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
    _instances = [[NSMutableDictionary alloc] initWithCapacity:1];
  }
  return self;
}

#pragma mark - Lifecycle

+ (void)load {
  // Register as an internal library to be part of the initialization process. The name comes from
  // go/firebase-sdk-platform-info.
  [FIRApp registerInternalLibrary:self withName:@"fire-rc"];
}

#pragma mark - Interoperability

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponent *rcProvider = [FIRComponent
      componentWithProtocol:@protocol(FIRRemoteConfigProvider)
        instantiationTiming:FIRInstantiationTimingAlwaysEager
              creationBlock:^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
                // Cache the component so instances of Remote Config are cached.
                *isCacheable = YES;
                return [FIRRemoteConfigComponent getComponentForApp:container.app];
              }];

  // Unlike provider needs to setup a hard dependency on remote config, interop allows an optional
  // dependency on RC
  FIRComponent *rcInterop = [FIRComponent
      componentWithProtocol:@protocol(FIRRemoteConfigInterop)
        instantiationTiming:FIRInstantiationTimingAlwaysEager
              creationBlock:^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
                // Cache the component so instances of Remote Config are cached.
                *isCacheable = YES;
                return [FIRRemoteConfigComponent getComponentForApp:container.app];
              }];
  return @[ rcProvider, rcInterop ];
}

#pragma mark - Remote Config Interop Protocol

- (void)registerRolloutsStateSubscriber:(id<FIRRolloutsStateSubscriber>)subscriber
                                    for:(NSString * _Nonnull)namespace {
  FIRRemoteConfig *instance = [self remoteConfigForNamespace:namespace];
  [instance addRemoteConfigInteropSubscriber:subscriber];
}

@end
