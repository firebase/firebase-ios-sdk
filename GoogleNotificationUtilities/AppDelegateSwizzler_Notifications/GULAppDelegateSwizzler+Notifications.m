// Copyright 2019 Google LLC
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
#import "TargetConditionals.h"

#if TARGET_OS_IOS || TARGET_OS_TV

#import <GoogleNotificationUtilities/GULAppDelegateSwizzler+Notifications.h>

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#import <GoogleUtilities/GULAppDelegateSwizzler_Private.h>
#import <GoogleUtilities/GULAppEnvironmentUtil.h>

typedef void (*GULRealDidRegisterForRemoteNotificationsIMP)(id, SEL, UIApplication *, NSData *);

typedef void (*GULRealDidFailToRegisterForRemoteNotificationsIMP)(id,
                                                                  SEL,
                                                                  UIApplication *,
                                                                  NSError *);

typedef void (*GULRealDidReceiveRemoteNotificationIMP)(id, SEL, UIApplication *, NSDictionary *);

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
// This is needed to for the library to be warning free on iOS versions < 7.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
typedef void (*GULRealDidReceiveRemoteNotificationWithCompletionIMP)(
    id, SEL, UIApplication *, NSDictionary *, void (^)(UIBackgroundFetchResult));
#pragma clang diagnostic pop
#endif  // __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000

@implementation GULAppDelegateSwizzler (Notifications)

static dispatch_once_t sProxyAppDelegateRemoteNotificationOnceToken;

+ (void)proxyOriginalDelegateIncludingAPNSMethods {
  if ([GULAppEnvironmentUtil isAppExtension]) {
    return;
  }

  [self proxyOriginalDelegate];

  dispatch_once(&sProxyAppDelegateRemoteNotificationOnceToken, ^{
    id<UIApplicationDelegate> appDelegate = [GULAppDelegateSwizzler sharedApplication].delegate;

    NSMutableDictionary *realImplementationsBySelector =
        [[self originalImplementationBySelectorString] mutableCopy];

    [self proxyRemoteNotificationsMethodsWithAppDelegateSubClass:[self appDelegateSubclass]
                                                       realClass:[self originalAppDelegateClass]
                                                     appDelegate:appDelegate
                                   realImplementationsBySelector:realImplementationsBySelector];

    [self setOriginalImplementationBySelectorString:[realImplementationsBySelector copy]];
    [self reassignAppDelegate];
  });
}

+ (void)proxyRemoteNotificationsMethodsWithAppDelegateSubClass:(Class)appDelegateSubClass
                                                     realClass:(Class)realClass
                                                   appDelegate:(id)appDelegate
                                 realImplementationsBySelector:
                                     (NSMutableDictionary *)realImplementationsBySelector {
  if (realClass == nil || appDelegateSubClass == nil || appDelegate == nil ||
      realImplementationsBySelector == nil) {
    // The App Delegate has not been swizzled.
    return;
  }

  // For application:didRegisterForRemoteNotificationsWithDeviceToken:
  SEL didRegisterForRemoteNotificationsSEL = @selector(application:
                  didRegisterForRemoteNotificationsWithDeviceToken:);
  [self proxyDestinationSelector:didRegisterForRemoteNotificationsSEL
      implementationsFromSourceSelector:didRegisterForRemoteNotificationsSEL
                              fromClass:[GULAppDelegateSwizzler class]
                                toClass:appDelegateSubClass
                              realClass:realClass
       storeDestinationImplementationTo:realImplementationsBySelector];

  // For application:didFailToRegisterForRemoteNotificationsWithError:
  SEL didFailToRegisterForRemoteNotificationsSEL = @selector(application:
                        didFailToRegisterForRemoteNotificationsWithError:);
  [self proxyDestinationSelector:didFailToRegisterForRemoteNotificationsSEL
      implementationsFromSourceSelector:didFailToRegisterForRemoteNotificationsSEL
                              fromClass:[GULAppDelegateSwizzler class]
                                toClass:appDelegateSubClass
                              realClass:realClass
       storeDestinationImplementationTo:realImplementationsBySelector];

  // For application:didReceiveRemoteNotification:
  SEL didReceiveRemoteNotificationSEL = @selector(application:didReceiveRemoteNotification:);
  [self proxyDestinationSelector:didReceiveRemoteNotificationSEL
      implementationsFromSourceSelector:didReceiveRemoteNotificationSEL
                              fromClass:[GULAppDelegateSwizzler class]
                                toClass:appDelegateSubClass
                              realClass:realClass
       storeDestinationImplementationTo:realImplementationsBySelector];

  // For application:didReceiveRemoteNotification:fetchCompletionHandler:
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
  if ([GULAppEnvironmentUtil isIOS7OrHigher]) {
    SEL didReceiveRemoteNotificationWithCompletionSEL =
        @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
    if ([appDelegate respondsToSelector:didReceiveRemoteNotificationWithCompletionSEL]) {
      // Only add the application:didReceiveRemoteNotification:fetchCompletionHandler: method if
      // the original AppDelegate implements it.
      // This fixes a bug if an app only implements application:didReceiveRemoteNotification:
      // (if we add the method with completion, iOS sees that one exists and does not call
      // the method without the completion, which in this case is the only one the app implements).

      [self proxyDestinationSelector:didReceiveRemoteNotificationWithCompletionSEL
          implementationsFromSourceSelector:didReceiveRemoteNotificationWithCompletionSEL
                                  fromClass:[GULAppDelegateSwizzler class]
                                    toClass:appDelegateSubClass
                                  realClass:realClass
           storeDestinationImplementationTo:realImplementationsBySelector];
    }
  }
#endif  // __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
}

#pragma mark - [Donor Methods] Remote Notifications

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  SEL methodSelector = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);

  NSValue *didRegisterForRemoteNotificationsIMPPointer =
      [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidRegisterForRemoteNotificationsIMP didRegisterForRemoteNotificationsIMP =
      [didRegisterForRemoteNotificationsIMPPointer pointerValue];

  // Notify interceptors.
  [GULAppDelegateSwizzler
      notifyInterceptorsWithMethodSelector:methodSelector
                                  callback:^(id<UIApplicationDelegate> interceptor) {
                                    [interceptor application:application
                                        didRegisterForRemoteNotificationsWithDeviceToken:
                                            deviceToken];
                                  }];
  // Call the real implementation if the real App Delegate has any.
  if (didRegisterForRemoteNotificationsIMP) {
    didRegisterForRemoteNotificationsIMP(self, methodSelector, application, deviceToken);
  }
}

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  SEL methodSelector = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
  NSValue *didFailToRegisterForRemoteNotificationsIMPPointer =
      [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidFailToRegisterForRemoteNotificationsIMP didFailToRegisterForRemoteNotificationsIMP =
      [didFailToRegisterForRemoteNotificationsIMPPointer pointerValue];

  // Notify interceptors.
  [GULAppDelegateSwizzler
      notifyInterceptorsWithMethodSelector:methodSelector
                                  callback:^(id<UIApplicationDelegate> interceptor) {
                                    [interceptor application:application
                                        didFailToRegisterForRemoteNotificationsWithError:error];
                                  }];
  // Call the real implementation if the real App Delegate has any.
  if (didFailToRegisterForRemoteNotificationsIMP) {
    didFailToRegisterForRemoteNotificationsIMP(self, methodSelector, application, error);
  }
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
// This is needed to for the library to be warning free on iOS versions < 7.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  SEL methodSelector = @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
  NSValue *didReceiveRemoteNotificationWithCompletionIMPPointer =
      [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidReceiveRemoteNotificationWithCompletionIMP
      didReceiveRemoteNotificationWithCompletionIMP =
          [didReceiveRemoteNotificationWithCompletionIMPPointer pointerValue];

  // Notify interceptors.
  [GULAppDelegateSwizzler
      notifyInterceptorsWithMethodSelector:methodSelector
                                  callback:^(id<UIApplicationDelegate> interceptor) {
                                    [interceptor application:application
                                        didReceiveRemoteNotification:userInfo
                                              fetchCompletionHandler:completionHandler];
                                  }];
  // Call the real implementation if the real App Delegate has any.
  if (didReceiveRemoteNotificationWithCompletionIMP) {
    didReceiveRemoteNotificationWithCompletionIMP(self, methodSelector, application, userInfo,
                                                  completionHandler);
  }
}
#pragma clang diagnostic pop
#endif  // __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
  SEL methodSelector = @selector(application:didReceiveRemoteNotification:);
  NSValue *didReceiveRemoteNotificationIMPPointer =
      [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidReceiveRemoteNotificationIMP didReceiveRemoteNotificationIMP =
      [didReceiveRemoteNotificationIMPPointer pointerValue];

  // Notify interceptors.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [GULAppDelegateSwizzler
      notifyInterceptorsWithMethodSelector:methodSelector
                                  callback:^(id<UIApplicationDelegate> interceptor) {
                                    [interceptor application:application
                                        didReceiveRemoteNotification:userInfo];
                                  }];
#pragma clang diagnostic pop
  // Call the real implementation if the real App Delegate has any.
  if (didReceiveRemoteNotificationIMP) {
    didReceiveRemoteNotificationIMP(self, methodSelector, application, userInfo);
  }
}

+ (void)resetProxyOriginalDelegateIncludingAPNSMethodsOnceToken {
  sProxyAppDelegateRemoteNotificationOnceToken = 0;
}

@end

#endif // TARGET_OS_IOS || TARGET_OS_TV
