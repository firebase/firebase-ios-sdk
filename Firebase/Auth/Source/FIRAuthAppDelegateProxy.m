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

#import "FIRAuthAppDelegateProxy.h"

#import <GoogleUtilities/GULAppDelegateSwizzler.h>

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/** @var kProxyEnabledBundleKey
    @brief The key in application's bundle plist for whether or not proxy should be enabled.
    @remarks This key is a shared constant with Analytics and FCM.
 */
static NSString *const kProxyEnabledBundleKey = @"FirebaseAppDelegateProxyEnabled";

@implementation FIRAuthAppDelegateProxy {
  /** @var _handlers
      @brief The array of weak pointers of `id<FIRAuthAppDelegateHandler>`.
   */
  NSPointerArray *_handlers;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _handlers = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsWeakMemory];
  }
  return self;
}

- (void)addHandler:(__weak id<FIRAuthAppDelegateHandler>)handler {
  @synchronized (_handlers) {
    [_handlers addPointer:(__bridge void *)handler];
  }
}

+ (nullable instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static FIRAuthAppDelegateProxy *_Nullable sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRAuthAppDelegateProxy alloc] init];
  });
  return sharedInstance;
}

#pragma mark - UIApplicationDelegate proxy methods.

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
    [handler setAPNSToken:deviceToken];
  }
}

- (void)application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
    [handler handleAPNSTokenError:error];
  }
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
    if ([handler canHandleNotification:userInfo]) {
      completionHandler(UIBackgroundFetchResultNoData);
      return;
    };
  }
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo {
  for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
    if ([handler canHandleNotification:userInfo]) {
      return;
    };
  }
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
  return [self delegateCanHandleURL:url];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(nullable NSString *)sourceApplication
         annotation:(id)annotation {
  return [self delegateCanHandleURL:url];
}

#pragma mark - Internal Methods

/** @fn delegateCanHandleURL:
    @brief Checks for whether any of the delegates can handle the URL.
    @param url The URL in question.
    @return Whether any of the delegate can handle the URL.
 */
- (BOOL)delegateCanHandleURL:(NSURL *)url {
  for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
    if ([handler canHandleURL:url]) {
      return YES;
    };
  }
  return NO;
}

/** @fn handlers
    @brief Gets the list of handlers from `_handlers` safely.
 */
- (NSArray<id<FIRAuthAppDelegateHandler>> *)handlers {
  @synchronized (_handlers) {
    NSMutableArray<id<FIRAuthAppDelegateHandler>> *liveHandlers =
       [[NSMutableArray<id<FIRAuthAppDelegateHandler>> alloc] initWithCapacity:_handlers.count];
    for (__weak id<FIRAuthAppDelegateHandler> handler in _handlers) {
      if (handler) {
        [liveHandlers addObject:handler];
      }
    }
    if (liveHandlers.count < _handlers.count) {
      [_handlers compact];
    }
    return liveHandlers;
  }
}

@end

NS_ASSUME_NONNULL_END
