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

#import <FirebaseCore/FIRAppEnvironmentUtil.h>

#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

/** @var kProxyEnabledBundleKey
    @brief The key in application's bundle plist for whether or not proxy should be enabled.
    @remarks This key is a shared constant with Analytics and FCM.
 */
static NSString *const kProxyEnabledBundleKey = @"FirebaseAppDelegateProxyEnabled";

/** @fn noop
    @brief A function that does nothing.
    @remarks This is used as the placeholder for unimplemented UApplicationDelegate methods,
        because once we added a method there is no way to remove it from the class.
 */
#if !OBJC_OLD_DISPATCH_PROTOTYPES
static void noop(void) {
}
#else
static id noop(id object, SEL cmd, ...) {
  return nil;
}
#endif

/** @fn isIOS9orLater
    @brief Checks whether the iOS version is 9 or later.
    @returns Whether the iOS version is 9 or later.
 */
static BOOL isIOS9orLater() {
#if defined(__IPHONE_11_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0)
  if (@available(iOS 9.0, *)) {
    return YES;
  }
  return NO;
#else
  // UIApplicationOpenURLOptionsAnnotationKey is only available on iOS 9+.
  return &UIApplicationOpenURLOptionsAnnotationKey != NULL;
#endif
}

@implementation FIRAuthAppDelegateProxy {
  /** @var _appDelegate
      @brief The application delegate whose method is being swizzled.
   */
  id<UIApplicationDelegate> _appDelegate;

  /** @var _orginalImplementationsBySelector
      @brief A map from selectors to original implementations that have been swizzled.
   */
  NSMutableDictionary<NSValue *, NSValue *> *_originalImplementationsBySelector;

  /** @var _handlers
      @brief The array of weak pointers of `id<FIRAuthAppDelegateHandler>`.
   */
  NSPointerArray *_handlers;
}

- (nullable instancetype)initWithApplication:(nullable UIApplication *)application {
  self = [super init];
  if (self) {
    id proxyEnabled = [[NSBundle mainBundle] objectForInfoDictionaryKey:kProxyEnabledBundleKey];
    if ([proxyEnabled isKindOfClass:[NSNumber class]] && !((NSNumber *)proxyEnabled).boolValue) {
      return nil;
    }
    _appDelegate = application.delegate;
    if (![_appDelegate conformsToProtocol:@protocol(UIApplicationDelegate)]) {
      return nil;
    }
    _originalImplementationsBySelector = [[NSMutableDictionary<NSValue *, NSValue *> alloc] init];
    _handlers = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsWeakMemory];

    // Swizzle the methods.
    __weak FIRAuthAppDelegateProxy *weakSelf = self;
    SEL registerDeviceTokenSelector =
        @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
    [self replaceSelector:registerDeviceTokenSelector
                withBlock:^(id object, UIApplication* application, NSData *deviceToken) {
      [weakSelf object:object
                                                  selector:registerDeviceTokenSelector
                                               application:application
          didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    }];
    SEL failToRegisterRemoteNotificationSelector =
        @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
    [self replaceSelector:failToRegisterRemoteNotificationSelector
                withBlock:^(id object, UIApplication* application, NSError *error) {
      [weakSelf object:object
                                                  selector:failToRegisterRemoteNotificationSelector
                                               application:application
          didFailToRegisterForRemoteNotificationsWithError:error];
    }];
    SEL receiveNotificationSelector = @selector(application:didReceiveRemoteNotification:);
    SEL receiveNotificationWithHandlerSelector =
        @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);
    if ([_appDelegate respondsToSelector:receiveNotificationWithHandlerSelector] ||
        ![_appDelegate respondsToSelector:receiveNotificationSelector]) {
      // Replace the modern selector which is available on iOS 7 and above.
      [self replaceSelector:receiveNotificationWithHandlerSelector
                  withBlock:^(id object, UIApplication *application, NSDictionary *notification,
                              void (^completionHandler)(UIBackgroundFetchResult)) {
        [weakSelf object:object
                                selector:receiveNotificationWithHandlerSelector
                             application:application
            didReceiveRemoteNotification:notification
                  fetchCompletionHandler:completionHandler];
      }];
    } else {
      // Replace the deprecated selector because this is the only one that the client app uses.
      [self replaceSelector:receiveNotificationSelector
                  withBlock:^(id object, UIApplication *application, NSDictionary *notification) {
        [weakSelf object:object
                                selector:receiveNotificationSelector
                             application:application
            didReceiveRemoteNotification:notification];
      }];
    }
    SEL openURLOptionsSelector = @selector(application:openURL:options:);
    SEL openURLAnnotationSelector = @selector(application:openURL:sourceApplication:annotation:);
    SEL handleOpenURLSelector = @selector(application:handleOpenURL:);
    if (isIOS9orLater() &&
        ([_appDelegate respondsToSelector:openURLOptionsSelector] ||
         (![_appDelegate respondsToSelector:openURLAnnotationSelector] &&
          ![_appDelegate respondsToSelector:handleOpenURLSelector]))) {
      // Replace the modern selector which is avaliable on iOS 9 and above because this is the one
      // that the client app uses or the client app doesn't use any of them.
      [self replaceSelector:openURLOptionsSelector
                  withBlock:^BOOL(id object, UIApplication *application, NSURL *url,
                                  NSDictionary *options) {
        return [weakSelf object:object
                       selector:openURLOptionsSelector
                    application:application
                        openURL:url
                        options:options];
       }];
    } else if ([_appDelegate respondsToSelector:openURLAnnotationSelector] ||
               ![_appDelegate respondsToSelector:handleOpenURLSelector]) {
      // Replace the longer form of the deprecated selectors on iOS 8 and below because this is the
      // one that the client app uses or the client app doesn't use either of the applicable ones.
      [self replaceSelector:openURLAnnotationSelector
                  withBlock:^(id object, UIApplication *application, NSURL *url,
                              NSString *sourceApplication, id annotation) {
        return [weakSelf object:object
                       selector:openURLAnnotationSelector
                    application:application
                        openURL:url
              sourceApplication:sourceApplication
                     annotation:annotation];
       }];
    } else {
      // Replace the shorter form of the deprecated selectors on iOS 8 and below because this is
      // the only one that the client app uses.
      [self replaceSelector:handleOpenURLSelector
                  withBlock:^(id object, UIApplication *application, NSURL *url) {
        return [weakSelf object:object
                       selector:handleOpenURLSelector
                    application:application
                  handleOpenURL:url];
       }];
    }
    // Reset the application delegate to clear the system cache that indicates whether each of the
    // openURL: methods is implemented on the application delegate.
    application.delegate = nil;
    application.delegate = _appDelegate;
  }
  return self;
}

- (void)dealloc {
  for (NSValue *selector in _originalImplementationsBySelector) {
    IMP implementation = _originalImplementationsBySelector[selector].pointerValue;
    Method method = class_getInstanceMethod([_appDelegate class], selector.pointerValue);
    imp_removeBlock(method_setImplementation(method, implementation));
  }
}

- (void)addHandler:(__weak id<FIRAuthAppDelegateHandler>)handler {
  @synchronized (_handlers) {
    [_handlers addPointer:(__bridge void *)handler];
  }
}

+ (nullable instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static FIRAuthAppDelegateProxy *_Nullable sharedInstance;
  // iOS App extensions should not call [UIApplication sharedApplication], even if UIApplication
  // responds to it.
  static Class applicationClass = nil;
  dispatch_once(&onceToken, ^{
    if (![FIRAppEnvironmentUtil isAppExtension]) {
      Class cls = NSClassFromString(@"UIApplication");
      if (cls && [cls respondsToSelector:NSSelectorFromString(@"sharedApplication")]) {
        applicationClass = cls;
      }
    }
    UIApplication *application = [applicationClass sharedApplication];
    sharedInstance = [[self alloc] initWithApplication:application];
  });
  return sharedInstance;
}

#pragma mark - UIApplicationDelegate proxy methods.

- (void)object:(id)object
                                            selector:(SEL)selector
                                         application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  if (object == _appDelegate) {
    for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
      [handler setAPNSToken:deviceToken];
    }
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef void (*Implmentation)(id, SEL, UIApplication*, NSData *);
    ((Implmentation)originalImplementation)(object, selector, application, deviceToken);
  }
}

- (void)object:(id)object
                                            selector:(SEL)selector
                                         application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  if (object == _appDelegate) {
    for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
      [handler handleAPNSTokenError:error];
    }
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef void (*Implmentation)(id, SEL, UIApplication *, NSError *);
    ((Implmentation)originalImplementation)(object, selector, application, error);
  }
}

- (void)object:(id)object
                        selector:(SEL)selector
                     application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)notification
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  if (object == _appDelegate) {
    for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
      if ([handler canHandleNotification:notification]) {
        completionHandler(UIBackgroundFetchResultNoData);
        return;
      };
    }
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef void (*Implmentation)(id, SEL, UIApplication*, NSDictionary *,
                                  void (^)(UIBackgroundFetchResult));
    ((Implmentation)originalImplementation)(object, selector, application, notification,
                                            completionHandler);
  }
}

- (void)object:(id)object
                        selector:(SEL)selector
                     application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)notification {
  if (object == _appDelegate) {
    for (id<FIRAuthAppDelegateHandler> handler in [self handlers]) {
      if ([handler canHandleNotification:notification]) {
        return;
      };
    }
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef void (*Implmentation)(id, SEL, UIApplication*, NSDictionary *);
    ((Implmentation)originalImplementation)(object, selector, application, notification);
  }
}

- (BOOL)object:(id)object
       selector:(SEL)selector
    application:(UIApplication *)application
        openURL:(NSURL *)url
        options:(NSDictionary *)options {
  if (object == _appDelegate && [self delegateCanHandleURL:url]) {
    return YES;
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef BOOL (*Implmentation)(id, SEL, UIApplication*, NSURL *, NSDictionary *);
    return ((Implmentation)originalImplementation)(object, selector, application, url, options);
  }
  return NO;
}

- (BOOL)object:(id)object
             selector:(SEL)selector
          application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
  if (object == _appDelegate && [self delegateCanHandleURL:url]) {
    return YES;
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef BOOL (*Implmentation)(id, SEL, UIApplication*, NSURL *, NSString *, id);
    return ((Implmentation)originalImplementation)(object, selector, application, url,
                                                   sourceApplication, annotation);
  }
  return NO;
}

- (BOOL)object:(id)object
         selector:(SEL)selector
      application:(UIApplication *)application
    handleOpenURL:(NSURL *)url {
  if (object == _appDelegate && [self delegateCanHandleURL:url]) {
    return YES;
  }
  IMP originalImplementation = [self originalImplementationForSelector:selector];
  if (originalImplementation && originalImplementation != &noop) {
    typedef BOOL (*Implmentation)(id, SEL, UIApplication*, NSURL *);
    return ((Implmentation)originalImplementation)(object, selector, application, url);
  }
  return NO;
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

/** @fn replaceSelector:withBlock:
    @brief replaces the implementation for a method of `_appDelegate` specified by a selector.
    @param selector The selector for the method.
    @param block The block as the new implementation of the method.
 */
- (void)replaceSelector:(SEL)selector withBlock:(id)block {
  Method originalMethod = class_getInstanceMethod([_appDelegate class], selector);
  IMP newImplementation = imp_implementationWithBlock(block);
  IMP originalImplementation;
  if (originalMethod) {
    originalImplementation = method_setImplementation(originalMethod, newImplementation) ?: &noop;
  } else {
    // The original method was not implemented in the class, add it with the new implementation.
    struct objc_method_description methodDescription =
        protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES);
    class_addMethod([_appDelegate class], selector, newImplementation, methodDescription.types);
    originalImplementation = &noop;
  }
  _originalImplementationsBySelector[[NSValue valueWithPointer:selector]] =
      [NSValue valueWithPointer:originalImplementation];
}

/** @fn originalImplementationForSelector:
    @brief Gets the original implementation for the given selector.
    @param selector The selector for the method that has been replaced.
    @return The original implementation if there was one.
 */
- (IMP)originalImplementationForSelector:(SEL)selector {
  return _originalImplementationsBySelector[[NSValue valueWithPointer:selector]].pointerValue;
}

@end

NS_ASSUME_NONNULL_END
