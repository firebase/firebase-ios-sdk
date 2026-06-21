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
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

#import "FirebaseInAppMessaging/Sources/Public/FirebaseInAppMessaging/FIRInAppMessaging.h"

#import <Foundation/Foundation.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
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

+ (void)load {
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-fiam"];
}

+ (nonnull NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    // Ensure it's cached so it returns the same instance every time fiam is called.
    *isCacheable = YES;

    // Only configure for the default FIRApp.
    if (!container.app.isDefaultApp) {
      FIRLogError(kFIRLoggerInAppMessaging, @"I-IAM170000",
                  @"In-App Messaging must be used with the default Firebase app.");
      return nil;
    }

    id<FIRAnalyticsInterop> analytics = FIR_COMPONENT(FIRAnalyticsInterop, container);
    FIRInstallations *installations = [FIRInstallations installationsWithApp:container.app];

    if (_autoBootstrapOnFIRAppInit) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170002",
                  @"Auto bootstrap Firebase in-app messaging SDK");
      [FIRInAppMessaging bootstrapIAMFromFIRApp:container.app];
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170003",
                  @"No auto bootstrap Firebase in-app messaging SDK");
    }

    return [[FIRInAppMessaging alloc] initWithAnalytics:analytics installations:installations];
  };
  FIRComponent *fiamProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRInAppMessagingInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingEagerInDefaultApp
                            creationBlock:creationBlock];

  return @[ fiamProvider ];
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

#pragma mark - Force Category Linking

extern void FIRInclude_FIRInAppMessaging_Bootstrap_Category(void);
extern void FIRInclude_UIApplication_FIRForegroundWindowScene_Category(void);
extern void FIRInclude_NSString_InterlaceStrings_Category(void);
extern void FIRInclude_UIColor_HexString_Category(void);

/// Does nothing when called, and not meant to be called.
///
/// This method forces the linker to include categories even if
/// users do not include the '-ObjC' linker flag in their project.
+ (void)noop {
  FIRInclude_FIRInAppMessaging_Bootstrap_Category();
  FIRInclude_UIApplication_FIRForegroundWindowScene_Category();
  FIRInclude_NSString_InterlaceStrings_Category();
  FIRInclude_UIColor_HexString_Category();
}

@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
