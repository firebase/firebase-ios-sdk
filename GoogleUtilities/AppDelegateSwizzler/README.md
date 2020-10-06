# App Delegate Swizzler

## Overview

The App Delegate Swizzler swizzles certain methods on the AppDelegate and allows interested parties
(for eg. other SDKs like Firebase Analytics) to register listeners when certain App Delegate methods
are called.

The App Delegate Swizzler uses [isa swizzling](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOImplementation.html)
to create a dynamic subclass of the app delegate class and add methods to it that have the logic to
add multiple "interceptors".

Adding interceptors to the following methods is currently supported by the App Delegate Swizzler.

* `- (BOOL)application:openURL:options:` [Reference](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623112-application?language=objc)

Note: This method is added only if the original app delegate implements it. This prevents a bug
where if an app only implements application:openURL:sourceApplication:annotation: and if we add the
`options` method, iOS sees that the `options` method exists and so does not call the
`sourceApplication` method, which causes the app developer's logic in `sourceApplication` to not be
called.

* `- (BOOL)application:openURL:sourceApplication:annotation:`
    [Reference](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623073-application?language=objc)

* `- (void)application:handleEventsForBackgroundURLSession:completionHandler:`
    [Reference](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622941-application?language=objc)

* `- (BOOL)application:continueUserActivity:restorationHandler:`
    [Reference](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623072-application?language=objc)

We are looking into adding support for more methods as we need them.

## Adopting the swizzler

To start using the app delegate swizzler to intercept app delegate methods do the following:

The following assumes that you are an SDK that ships using Cocoapods and need to react to one of the
app delegate methods listed above.

1. Add a dependency to the app delegate swizzler - `GoogleUtilities/AppDelegateSwizzler:~> 5.2`. We
follow Semantic Versioning.

2. Create an interceptor class that implements the `UIApplicationDelegate` and implements the
methods you want to intercept. For eg.

MYAppDelegateInterceptor.h

```objc

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// An instance of this class is meant to be registered as an AppDelegate interceptor, and
/// implements the logic that my SDK needs to perform when certain app delegate methods are invoked.
@interface MYAppDelegateInterceptor : NSObject <UIApplicationDelegate>

/// Returns the MYAppDelegateInterceptor singleton.
/// Always register just this singleton as the app delegate interceptor. This instance is
/// retained. The App Delegate Swizzler only retains weak references and so this is needed.
+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END

```

MYAppDelegateInterceptor.m

```objc
#import "MYAppDelegateInterceptor.h"

@implementation MYAppDelegateInterceptor

+ (instancetype)sharedInstance {
  static dispatch_once_t once;
  static MYAppDelegateInterceptor *sharedInstance;
  dispatch_once(&once, ^{
    sharedInstance = [[MYAppDelegateInterceptor alloc] init];
  });
  return sharedInstance;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
            options:(NSDictionary<NSString *, id> *)options {

  [MYInterestingClass doSomething];

  // Results of this are ORed and NO doesn't affect other delegate interceptors' result.
  return NO;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {

    [MYInterestingClass doSomething];

  // Results of this are ORed and NO doesn't affect other delegate interceptors' result.
  return NO;
}

#pragma mark - Network overridden handler methods

- (void)application:(UIApplication *)application
    handleEventsForBackgroundURLSession:(NSString *)identifier
                      completionHandler:(void (^)(void))completionHandler {

  // Note: Interceptors are not responsible for (and should not) call the completion handler.
  [MYInterestingClass doSomething];
}

#pragma mark - User Activities overridden handler methods

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray *restorableObjects))restorationHandler {

  [MYInterestingClass doSomething];

  // Results of this are ORed and NO doesn't affect other delegate interceptors' result.
  return NO;
}

@end
```

3. Register your interceptor when it makes sense to do so.

For eg.

```objc

// MYInterestingClass.m

#import "GoogleUtilities/AppDelegateSwizzler/Public/GoogleUtilities/GULAppDelegateSwizzler.h"

...

- (void)someInterestingMethod {
    ...

    // Calling this ensures that the app delegate is proxied (has no effect if some other SDK has
    // already done it).
    [GULAppDelegateSwizzler proxyOriginalDelegate];

    MYAppDelegateInterceptor *interceptor = [MYAppDelegateInterceptor sharedInstance];
    [GULAppDelegateSwizzler registerAppDelegateInterceptor:interceptor];
}
```
## Swizzling of App Delegate APNS methods

Swizzling of the APNS related App Delegate methods may lead to an Apple review warning email about
missing Push Notification Entitlement during the app review process
(like here: https://github.com/firebase/firebase-ios-sdk/issues/2807) if Push Notifications are
actually not used by the app. To avoid the warning the methods below are not swizzled
by `[GULAppDelegateSwizzler proxyOriginalDelegate]`:

```objc

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo;

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler;
```

If you need to swizzle these methods you can call
`[GULAppDelegateSwizzler proxyOriginalDelegateIncludingAPNSMethods]`. The method can be safely
called instead or after `[GULAppDelegateSwizzler proxyOriginalDelegate]`.

## Disabling App Delegate Swizzling by App Developers

Sometimes app developers that consume our SDKs prefer that we do not swizzle the app delegate. We've
added support for developers to disable any sort of app delegate swizzling that we may do, and this
is achieved by adding the Plist flag `GoogleUtilitiesAppDelegateProxyEnabled` to `NO` (Boolean). If
this is set, even if you call `[GULAppDelegateSwizzler proxyOriginalDelegate]`, it won't have any
effect.
