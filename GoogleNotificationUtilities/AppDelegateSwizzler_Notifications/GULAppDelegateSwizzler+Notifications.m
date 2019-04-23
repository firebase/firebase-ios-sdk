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

#import "GULAppDelegateSwizzler+Notifications.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

/** Remote notification methods selectors
 *
 *  We have to opt out of referencing APNS related App Delegate methods directly to prevent
 *  an Apple review warning email about missing Push Notification Entitlement
 *  (like here: https://github.com/firebase/firebase-ios-sdk/issues/2807). From our experience, the
 *  warning is triggered when any of the symbols is present in the application sent to review, even
 *  if the code is never executed. Because GULAppDelegateSwizzler may be used by applications that
 *  are not using APNS we have to refer to the methods indirectly using selector constructed from
 *  string.
 *
 *  NOTE: None of the methods is proxied unless it is explicitly requested by calling the method
 *  +[GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods]
 */
static NSString *const kGULDidRegisterForRemoteNotificationsSEL =
@"application:didRegisterForRemoteNotificationsWithDeviceToken:";
static NSString *const kGULDidFailToRegisterForRemoteNotificationsSEL =
@"application:didFailToRegisterForRemoteNotificationsWithError:";
static NSString *const kGULDidReceiveRemoteNotificationSEL =
@"application:didReceiveRemoteNotification:";
static NSString *const kGULDidReceiveRemoteNotificationWithCompletionSEL =
@"application:didReceiveRemoteNotification:fetchCompletionHandler:";

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
  SEL didRegisterForRemoteNotificationsSEL =
  NSSelectorFromString(kGULDidRegisterForRemoteNotificationsSEL);
  SEL didRegisterForRemoteNotificationsDonorSEL = @selector(application:
                                                            donor_didRegisterForRemoteNotificationsWithDeviceToken:);

  [self proxyDestinationSelector:didRegisterForRemoteNotificationsSEL
implementationsFromSourceSelector:didRegisterForRemoteNotificationsDonorSEL
                       fromClass:[GULAppDelegateSwizzler class]
                         toClass:appDelegateSubClass
                       realClass:realClass
storeDestinationImplementationTo:realImplementationsBySelector];

  // For application:didFailToRegisterForRemoteNotificationsWithError:
  SEL didFailToRegisterForRemoteNotificationsSEL =
  NSSelectorFromString(kGULDidFailToRegisterForRemoteNotificationsSEL);
  SEL didFailToRegisterForRemoteNotificationsDonorSEL = @selector(application:
                                                                  donor_didFailToRegisterForRemoteNotificationsWithError:);

  [self proxyDestinationSelector:didFailToRegisterForRemoteNotificationsSEL
implementationsFromSourceSelector:didFailToRegisterForRemoteNotificationsDonorSEL
                       fromClass:[GULAppDelegateSwizzler class]
                         toClass:appDelegateSubClass
                       realClass:realClass
storeDestinationImplementationTo:realImplementationsBySelector];

  // For application:didReceiveRemoteNotification:
  SEL didReceiveRemoteNotificationSEL = NSSelectorFromString(kGULDidReceiveRemoteNotificationSEL);
  SEL didReceiveRemoteNotificationDonotSEL = @selector(application:
                                                       donor_didReceiveRemoteNotification:);

  [self proxyDestinationSelector:didReceiveRemoteNotificationSEL
implementationsFromSourceSelector:didReceiveRemoteNotificationDonotSEL
                       fromClass:[GULAppDelegateSwizzler class]
                         toClass:appDelegateSubClass
                       realClass:realClass
storeDestinationImplementationTo:realImplementationsBySelector];

  // For application:didReceiveRemoteNotification:fetchCompletionHandler:
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
  if ([GULAppEnvironmentUtil isIOS7OrHigher]) {
    SEL didReceiveRemoteNotificationWithCompletionSEL =
    NSSelectorFromString(kGULDidReceiveRemoteNotificationWithCompletionSEL);
    SEL didReceiveRemoteNotificationWithCompletionDonorSEL =
    @selector(application:donor_didReceiveRemoteNotification:fetchCompletionHandler:);
    if ([appDelegate respondsToSelector:didReceiveRemoteNotificationWithCompletionSEL]) {
      // Only add the application:didReceiveRemoteNotification:fetchCompletionHandler: method if
      // the original AppDelegate implements it.
      // This fixes a bug if an app only implements application:didReceiveRemoteNotification:
      // (if we add the method with completion, iOS sees that one exists and does not call
      // the method without the completion, which in this case is the only one the app implements).

      [self proxyDestinationSelector:didReceiveRemoteNotificationWithCompletionSEL
   implementationsFromSourceSelector:didReceiveRemoteNotificationWithCompletionDonorSEL
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
donor_didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  SEL methodSelector = NSSelectorFromString(kGULDidRegisterForRemoteNotificationsSEL);

  NSValue *didRegisterForRemoteNotificationsIMPPointer =
  [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidRegisterForRemoteNotificationsIMP didRegisterForRemoteNotificationsIMP =
  [didRegisterForRemoteNotificationsIMPPointer pointerValue];

  // Notify interceptors.
  [GULAppDelegateSwizzler
   notifyInterceptorsWithMethodSelector:methodSelector
   callback:^(id<UIApplicationDelegate> interceptor) {
     NSInvocation *invocation = [GULAppDelegateSwizzler
                                 appDelegateInvocationForSelector:methodSelector];
     [invocation setTarget:interceptor];
     [invocation setSelector:methodSelector];
     [invocation setArgument:(void *)(&application) atIndex:2];
     [invocation setArgument:(void *)(&deviceToken) atIndex:3];
     [invocation invoke];
   }];
  // Call the real implementation if the real App Delegate has any.
  if (didRegisterForRemoteNotificationsIMP) {
    didRegisterForRemoteNotificationsIMP(self, methodSelector, application, deviceToken);
  }
}

- (void)application:(UIApplication *)application
donor_didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  SEL methodSelector = NSSelectorFromString(kGULDidFailToRegisterForRemoteNotificationsSEL);
  NSValue *didFailToRegisterForRemoteNotificationsIMPPointer =
  [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidFailToRegisterForRemoteNotificationsIMP didFailToRegisterForRemoteNotificationsIMP =
  [didFailToRegisterForRemoteNotificationsIMPPointer pointerValue];

  // Notify interceptors.
  [GULAppDelegateSwizzler
   notifyInterceptorsWithMethodSelector:methodSelector
   callback:^(id<UIApplicationDelegate> interceptor) {
     NSInvocation *invocation = [GULAppDelegateSwizzler
                                 appDelegateInvocationForSelector:methodSelector];
     [invocation setTarget:interceptor];
     [invocation setSelector:methodSelector];
     [invocation setArgument:(void *)(&application) atIndex:2];
     [invocation setArgument:(void *)(&error) atIndex:3];
     [invocation invoke];
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
donor_didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  SEL methodSelector = NSSelectorFromString(kGULDidReceiveRemoteNotificationWithCompletionSEL);
  NSValue *didReceiveRemoteNotificationWithCompletionIMPPointer =
  [GULAppDelegateSwizzler originalImplementationForSelector:methodSelector object:self];
  GULRealDidReceiveRemoteNotificationWithCompletionIMP
  didReceiveRemoteNotificationWithCompletionIMP =
  [didReceiveRemoteNotificationWithCompletionIMPPointer pointerValue];

  // Notify interceptors.
  [GULAppDelegateSwizzler
   notifyInterceptorsWithMethodSelector:methodSelector
   callback:^(id<UIApplicationDelegate> interceptor) {
     NSInvocation *invocation = [GULAppDelegateSwizzler
                                 appDelegateInvocationForSelector:methodSelector];
     [invocation setTarget:interceptor];
     [invocation setSelector:methodSelector];
     [invocation setArgument:(void *)(&application) atIndex:2];
     [invocation setArgument:(void *)(&userInfo) atIndex:3];
     [invocation setArgument:(void *)(&completionHandler) atIndex:4];
     [invocation invoke];
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
donor_didReceiveRemoteNotification:(NSDictionary *)userInfo {
  SEL methodSelector = NSSelectorFromString(kGULDidReceiveRemoteNotificationSEL);
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
     NSInvocation *invocation = [GULAppDelegateSwizzler
                                 appDelegateInvocationForSelector:methodSelector];
     [invocation setTarget:interceptor];
     [invocation setSelector:methodSelector];
     [invocation setArgument:(void *)(&application) atIndex:2];
     [invocation setArgument:(void *)(&userInfo) atIndex:3];
     [invocation invoke];
   }];
#pragma clang diagnostic pop
  // Call the real implementation if the real App Delegate has any.
  if (didReceiveRemoteNotificationIMP) {
    didReceiveRemoteNotificationIMP(self, methodSelector, application, userInfo);
  }
}

+ (nullable NSInvocation *)appDelegateInvocationForSelector:(SEL)selector {
  struct objc_method_description methodDescription =
  protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES);
  if (methodDescription.types == NULL) {
    return nil;
  }

  NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:methodDescription.types];
  return [NSInvocation invocationWithMethodSignature:signature];
}

+ (void)resetProxyOriginalDelegateIncludingAPNSMethodsOnceToken {
  sProxyAppDelegateRemoteNotificationOnceToken = 0;
}

@end
