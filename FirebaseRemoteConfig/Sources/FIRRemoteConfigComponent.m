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

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRComponent.h>
#import <FirebaseCore/FIRComponentContainer.h>
#import <FirebaseCore/FIRDependency.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"

#ifndef FIRRemoteConfig_VERSION
#error "FIRRemoteConfig_VERSION is not defined: \
add -DFIRRemoteConfig_VERSION=... to the build invocation"
#endif

#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x

@implementation FIRRemoteConfigComponent

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
  }

  if (errorPropertyName) {
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
  [FIRApp registerInternalLibrary:self
                         withName:@"fire-rc"
                      withVersion:[NSString stringWithUTF8String:STR(FIRRemoteConfig_VERSION)]];
}

#pragma mark - Interoperability

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *analyticsDep = [FIRDependency dependencyWithProtocol:@protocol(FIRAnalyticsInterop)
                                                           isRequired:NO];
  FIRComponent *rcProvider = [FIRComponent
      componentWithProtocol:@protocol(FIRRemoteConfigProvider)
        instantiationTiming:FIRInstantiationTimingAlwaysEager
               dependencies:@[ analyticsDep ]
              creationBlock:^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
                // Cache the component so instances of Remote Config are cached.
                *isCacheable = YES;
                return [[FIRRemoteConfigComponent alloc] initWithApp:container.app];
              }];
  return @[ rcProvider ];
}

@end
