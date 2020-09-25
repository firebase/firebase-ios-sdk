/*
 * Copyright 2017 Google
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseInAppMessaging/Sources/Public/FirebaseInAppMessaging/FIRInAppMessaging.h"

#import <Foundation/Foundation.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/FIRInAppMessagingPrivate.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayExecutor.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMRuntimeManager.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRInAppMessaging+Bootstrap.h"

static BOOL _autoBootstrapOnFIRAppInit = YES;

@implementation FIRInAppMessaging {
  BOOL _messageDisplaySuppressed;
}

// Call this to present the SDK being auto bootstrapped with other Firebase SDKs. It needs
// to be triggered before [FIRApp configure] is executed. This should only be needed for
// testing app that wants to use custom fiam SDK settings.
+ (void)disableAutoBootstrapWithFIRApp {
  _autoBootstrapOnFIRAppInit = NO;
}

// extract macro value into a C string
#define STR_FROM_MACRO(x) #x
#define STR(x) STR_FROM_MACRO(x)

+ (void)load {
  [FIRApp
      registerInternalLibrary:(Class<FIRLibrary>)self
                     withName:@"fire-fiam"
                  withVersion:[NSString stringWithUTF8String:STR(FIRInAppMessaging_LIB_VERSION)]];
}

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRDependency *analyticsDep = [FIRDependency dependencyWithProtocol:@protocol(FIRAnalyticsInterop)
                                                           isRequired:YES];
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    // Ensure it's cached so it returns the same instance every time fiam is called.
    *isCacheable = YES;
    id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, container);
    FIRInstallations *installations = [FIRInstallations installationsWithApp:container.app];
    return [[FIRInAppMessaging alloc] initWithAnalytics:analytics installations:installations];
  };
  FIRComponent *fiamProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRInAppMessagingInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingLazy
                             dependencies:@[ analyticsDep ]
                            creationBlock:creationBlock];

  return @[ fiamProvider ];
}

+ (void)configureWithApp:(FIRApp *)app {
  if (!app.isDefaultApp) {
    // Only configure for the default FIRApp.
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170000",
                @"Firebase InAppMessaging only works with the default app.");
    return;
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170001",
              @"Got notification for kFIRAppReadyToConfigureSDKNotification");
  if (_autoBootstrapOnFIRAppInit) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170002",
                @"Auto bootstrap Firebase in-app messaging SDK");
    [self bootstrapIAMFromFIRApp:app];
  } else {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170003",
                @"No auto bootstrap Firebase in-app messaging SDK");
  }
}

- (instancetype)initWithAnalytics:(id<FIRAnalyticsInterop>)analytics
                    installations:(FIRInstallations *)installations {
  if (self = [super init]) {
    _messageDisplaySuppressed = NO;
    _analytics = analytics;
    _installations = installations;
  }
  return self;
}

+ (FIRInAppMessaging *)inAppMessaging {
  FIRApp *defaultApp = [FIRApp defaultApp];  // Missing configure will be logged here.
  id<FIRInAppMessagingInstanceProvider> inAppMessaging =
      FIR_COMPONENT(FIRInAppMessagingInstanceProvider, defaultApp.container);
  return (FIRInAppMessaging *)inAppMessaging;
}

- (BOOL)messageDisplaySuppressed {
  return _messageDisplaySuppressed;
}

- (void)setMessageDisplaySuppressed:(BOOL)suppressed {
  _messageDisplaySuppressed = suppressed;
  [[FIRIAMRuntimeManager getSDKRuntimeInstance] setShouldSuppressMessageDisplay:suppressed];
}

- (BOOL)automaticDataCollectionEnabled {
  return [FIRIAMRuntimeManager getSDKRuntimeInstance].automaticDataCollectionEnabled;
}

- (void)setAutomaticDataCollectionEnabled:(BOOL)automaticDataCollectionEnabled {
  [FIRIAMRuntimeManager getSDKRuntimeInstance].automaticDataCollectionEnabled =
      automaticDataCollectionEnabled;
}

- (void)setMessageDisplayComponent:(id<FIRInAppMessagingDisplay>)messageDisplayComponent {
  _messageDisplayComponent = messageDisplayComponent;

  if (messageDisplayComponent == nil) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM290002", @"messageDisplayComponent set to nil.");
  } else {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM290001",
                @"Setting a non-nil message display component");
  }

  // Forward the setting to the display executor.
  [FIRIAMRuntimeManager getSDKRuntimeInstance].displayExecutor.messageDisplayComponent =
      messageDisplayComponent;
}

- (void)triggerEvent:(NSString *)eventName {
  [[FIRIAMRuntimeManager getSDKRuntimeInstance].displayExecutor
      checkAndDisplayNextContextualMessageForAnalyticsEvent:eventName];
}

@end

#endif  // TARGET_OS_IOS
