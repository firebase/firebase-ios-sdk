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

#import "FIRMessagingRemoteNotificationsProxy.h"

#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#import "FIRMessagingConstants.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingUtilities.h"
#import "FIRMessaging_Private.h"

static const BOOL kDefaultAutoRegisterEnabledValue = YES;
static void * UserNotificationObserverContext = &UserNotificationObserverContext;

static NSString *kUserNotificationWillPresentSelectorString =
    @"userNotificationCenter:willPresentNotification:withCompletionHandler:";
static NSString *kUserNotificationDidReceiveResponseSelectorString =
    @"userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:";
static NSString *kReceiveDataMessageSelectorString = @"messaging:didReceiveMessage:";

@interface FIRMessagingRemoteNotificationsProxy ()

@property(strong, nonatomic) NSMutableDictionary<NSString *, NSValue *> *originalAppDelegateImps;
@property(strong, nonatomic) NSMutableDictionary<NSString *, NSArray *> *swizzledSelectorsByClass;

@property(nonatomic) BOOL didSwizzleMethods;
@property(nonatomic) BOOL didSwizzleAppDelegateMethods;

@property(nonatomic) BOOL hasSwizzledUserNotificationDelegate;
@property(nonatomic) BOOL isObservingUserNotificationDelegateChanges;

@property(strong, nonatomic) id userNotificationCenter;
@property(strong, nonatomic) id currentUserNotificationCenterDelegate;

@end

@implementation FIRMessagingRemoteNotificationsProxy

+ (BOOL)canSwizzleMethods {
  id canSwizzleValue =
      [[NSBundle mainBundle]
          objectForInfoDictionaryKey: kFIRMessagingRemoteNotificationsProxyEnabledInfoPlistKey];
  if (canSwizzleValue && [canSwizzleValue isKindOfClass:[NSNumber class]]) {
    NSNumber *canSwizzleNumberValue = (NSNumber *)canSwizzleValue;
    return canSwizzleNumberValue.boolValue;
  } else {
    return kDefaultAutoRegisterEnabledValue;
  }
}

+ (void)swizzleMethods {
  [[FIRMessagingRemoteNotificationsProxy sharedProxy] swizzleMethodsIfPossible];
}

+ (instancetype)sharedProxy {
  static FIRMessagingRemoteNotificationsProxy *proxy;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    proxy = [[FIRMessagingRemoteNotificationsProxy alloc] init];
  });
  return proxy;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _originalAppDelegateImps = [[NSMutableDictionary alloc] init];
    _swizzledSelectorsByClass = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self unswizzleAllMethods];
  self.swizzledSelectorsByClass = nil;
  [self.originalAppDelegateImps removeAllObjects];
  self.originalAppDelegateImps = nil;
  [self removeUserNotificationCenterDelegateObserver];
}

- (void)swizzleMethodsIfPossible {
  // Already swizzled.
  if (self.didSwizzleMethods) {
    return;
  }

  UIApplication *application = FIRMessagingUIApplication();
  if (!application) {
    return;
  }
  NSObject<UIApplicationDelegate> *appDelegate = [application delegate];
  [self swizzleAppDelegateMethods:appDelegate];

  // Add KVO listener on [UNUserNotificationCenter currentNotificationCenter]'s delegate property
  Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
  if (notificationCenterClass) {
    // We are linked against iOS 10 SDK or above
    id notificationCenter = getNamedPropertyFromObject(notificationCenterClass,
                                                       @"currentNotificationCenter",
                                                       notificationCenterClass);
    if (notificationCenter) {
      [self listenForDelegateChangesInUserNotificationCenter:notificationCenter];
    }
  }

  self.didSwizzleMethods = YES;
}

- (void)unswizzleAllMethods {
  for (NSString *className in self.swizzledSelectorsByClass) {
    Class klass = NSClassFromString(className);
    NSArray *selectorStrings = self.swizzledSelectorsByClass[className];
    for (NSString *selectorString in selectorStrings) {
      SEL selector = NSSelectorFromString(selectorString);
      [self unswizzleSelector:selector inClass:klass];
    }
  }
  [self.swizzledSelectorsByClass removeAllObjects];
}

- (void)swizzleAppDelegateMethods:(id<UIApplicationDelegate>)appDelegate {
  if (![appDelegate conformsToProtocol:@protocol(UIApplicationDelegate)]) {
    return;
  }
  Class appDelegateClass = [appDelegate class];

  BOOL didSwizzleAppDelegate = NO;
  // Message receiving handler for iOS 9, 8, 7 devices (both display notification and data message).
  SEL remoteNotificationSelector =
      @selector(application:didReceiveRemoteNotification:);

  SEL remoteNotificationWithFetchHandlerSelector =
      @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);

  // For recording when APNS tokens are registered (or fail to register)
  SEL registerForAPNSFailSelector =
      @selector(application:didFailToRegisterForRemoteNotificationsWithError:);

  SEL registerForAPNSSuccessSelector =
      @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);


  // Receive Remote Notifications.
  BOOL selectorWithFetchHandlerImplemented = NO;
  if ([appDelegate respondsToSelector:remoteNotificationWithFetchHandlerSelector]) {
    selectorWithFetchHandlerImplemented = YES;
    [self swizzleSelector:remoteNotificationWithFetchHandlerSelector
                  inClass:appDelegateClass
       withImplementation:(IMP)FCM_swizzle_appDidReceiveRemoteNotificationWithHandler
               inProtocol:@protocol(UIApplicationDelegate)];
    didSwizzleAppDelegate = YES;
  }

  if ([appDelegate respondsToSelector:remoteNotificationSelector] ||
      !selectorWithFetchHandlerImplemented) {
    [self swizzleSelector:remoteNotificationSelector
                  inClass:appDelegateClass
       withImplementation:(IMP)FCM_swizzle_appDidReceiveRemoteNotification
               inProtocol:@protocol(UIApplicationDelegate)];
    didSwizzleAppDelegate = YES;
  }

  // For data message from MCS.
  SEL receiveDataMessageSelector = NSSelectorFromString(kReceiveDataMessageSelectorString);
  if ([appDelegate respondsToSelector:receiveDataMessageSelector]) {
    [self swizzleSelector:receiveDataMessageSelector
                   inClass:appDelegateClass
        withImplementation:(IMP)FCM_swizzle_messagingDidReceiveMessage
                inProtocol:@protocol(UIApplicationDelegate)];
    didSwizzleAppDelegate = YES;
  }

  // Receive APNS token
  [self swizzleSelector:registerForAPNSSuccessSelector
                inClass:appDelegateClass
     withImplementation:(IMP)FCM_swizzle_appDidRegisterForRemoteNotifications
             inProtocol:@protocol(UIApplicationDelegate)];

  [self swizzleSelector:registerForAPNSFailSelector
                inClass:appDelegateClass
     withImplementation:(IMP)FCM_swizzle_appDidFailToRegisterForRemoteNotifications
             inProtocol:@protocol(UIApplicationDelegate)];

  self.didSwizzleAppDelegateMethods = didSwizzleAppDelegate;
}

- (void)listenForDelegateChangesInUserNotificationCenter:(id)notificationCenter {
  Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
  if (![notificationCenter isKindOfClass:notificationCenterClass]) {
    return;
  }
  id delegate = getNamedPropertyFromObject(notificationCenter, @"delegate", nil);
  Protocol *delegateProtocol = NSProtocolFromString(@"UNUserNotificationCenterDelegate");
  if ([delegate conformsToProtocol:delegateProtocol]) {
    // Swizzle this object now, if available
    [self swizzleUserNotificationCenterDelegate:delegate];
  }
  // Add KVO observer for "delegate" keyPath for future changes
  [self addDelegateObserverToUserNotificationCenter:notificationCenter];
}

#pragma mark - UNNotificationCenter Swizzling

- (void)swizzleUserNotificationCenterDelegate:(id _Nonnull)delegate {
  if (self.currentUserNotificationCenterDelegate == delegate) {
    // Via pointer-check, compare if we have already swizzled this item.
    return;
  }
  Protocol *userNotificationCenterProtocol =
      NSProtocolFromString(@"UNUserNotificationCenterDelegate");
  if ([delegate conformsToProtocol:userNotificationCenterProtocol]) {
    SEL willPresentNotificationSelector =
        NSSelectorFromString(kUserNotificationWillPresentSelectorString);
    // Swizzle the optional method
    // "userNotificationCenter:willPresentNotification:withCompletionHandler:", if it is
    // implemented. Do not swizzle otherwise, as an implementation *will* be created, which will
    // fool iOS into thinking that this method is implemented, and therefore not send notifications
    // to the fallback method in the app delegate
    // "application:didReceiveRemoteNotification:fetchCompletionHandler:".
    if ([delegate respondsToSelector:willPresentNotificationSelector]) {
      [self swizzleSelector:willPresentNotificationSelector
                    inClass:[delegate class]
         withImplementation:(IMP)FCM_swizzle_willPresentNotificationWithHandler
                 inProtocol:userNotificationCenterProtocol];
    }
    SEL didReceiveNotificationResponseSelector =
        NSSelectorFromString(kUserNotificationDidReceiveResponseSelectorString);
    if ([delegate respondsToSelector:didReceiveNotificationResponseSelector]) {
      [self swizzleSelector:didReceiveNotificationResponseSelector
                    inClass:[delegate class]
         withImplementation:(IMP)FCM_swizzle_didReceiveNotificationResponseWithHandler
                 inProtocol:userNotificationCenterProtocol];
    }
    self.currentUserNotificationCenterDelegate = delegate;
    self.hasSwizzledUserNotificationDelegate = YES;
  }
}

- (void)unswizzleUserNotificationCenterDelegate:(id _Nonnull)delegate {
  if (self.currentUserNotificationCenterDelegate != delegate) {
    // We aren't swizzling this delegate, so don't do anything.
    return;
  }
  SEL willPresentNotificationSelector =
      NSSelectorFromString(kUserNotificationWillPresentSelectorString);
  // Call unswizzle methods, even if the method was not implemented (it will fail gracefully).
  [self unswizzleSelector:willPresentNotificationSelector
                  inClass:[self.currentUserNotificationCenterDelegate class]];
  SEL didReceiveNotificationResponseSelector =
      NSSelectorFromString(kUserNotificationDidReceiveResponseSelectorString);
  [self unswizzleSelector:didReceiveNotificationResponseSelector
                  inClass:[self.currentUserNotificationCenterDelegate class]];
  self.currentUserNotificationCenterDelegate = nil;
  self.hasSwizzledUserNotificationDelegate = NO;
}

#pragma mark - KVO for UNUserNotificationCenter

- (void)addDelegateObserverToUserNotificationCenter:(id)userNotificationCenter {
  [self removeUserNotificationCenterDelegateObserver];
  @try {
    [userNotificationCenter addObserver:self
                             forKeyPath:NSStringFromSelector(@selector(delegate))
                                options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                context:UserNotificationObserverContext];
    self.userNotificationCenter = userNotificationCenter;
    self.isObservingUserNotificationDelegateChanges = YES;
  } @catch (NSException *exception) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeRemoteNotificationsProxy000,
                            @"Encountered exception trying to add a KVO observer for "
                            @"UNUserNotificationCenter's 'delegate' property: %@",
                            exception);
  } @finally {

  }
}

- (void)removeUserNotificationCenterDelegateObserver {
  if (!self.userNotificationCenter) {
    return;
  }
  @try {
    [self.userNotificationCenter removeObserver:self
                                 forKeyPath:NSStringFromSelector(@selector(delegate))
                                    context:UserNotificationObserverContext];
    self.userNotificationCenter = nil;
    self.isObservingUserNotificationDelegateChanges = NO;
  } @catch (NSException *exception) {
    FIRMessagingLoggerError(kFIRMessagingMessageCodeRemoteNotificationsProxy001,
                            @"Encountered exception trying to remove a KVO observer for "
                            @"UNUserNotificationCenter's 'delegate' property: %@",
                            exception);
  } @finally {

  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
  if (context == UserNotificationObserverContext) {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(delegate))]) {
      id oldDelegate = change[NSKeyValueChangeOldKey];
      if (oldDelegate && oldDelegate != [NSNull null]) {
        [self unswizzleUserNotificationCenterDelegate:oldDelegate];
      }
      id newDelegate = change[NSKeyValueChangeNewKey];
      if (newDelegate && newDelegate != [NSNull null]) {
        [self swizzleUserNotificationCenterDelegate:newDelegate];
      }
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

#pragma mark - NSProxy methods

- (void)saveOriginalImplementation:(IMP)imp forSelector:(SEL)selector {
  if (imp && selector) {
    NSValue *IMPValue = [NSValue valueWithPointer:imp];
    NSString *selectorString = NSStringFromSelector(selector);
    self.originalAppDelegateImps[selectorString] = IMPValue;
  }
}

- (IMP)originalImplementationForSelector:(SEL)selector {
  NSString *selectorString = NSStringFromSelector(selector);
  NSValue *implementation_value = self.originalAppDelegateImps[selectorString];
  if (!implementation_value) {
    return nil;
  }

  IMP imp;
  [implementation_value getValue:&imp];
  return imp;
}

- (void)trackSwizzledSelector:(SEL)selector ofClass:(Class)klass {
  NSString *className = NSStringFromClass(klass);
  NSString *selectorString = NSStringFromSelector(selector);
  NSArray *selectors = self.swizzledSelectorsByClass[selectorString];
  if (selectors) {
    selectors = [selectors arrayByAddingObject:selectorString];
  } else {
    selectors = @[selectorString];
  }
  self.swizzledSelectorsByClass[className] = selectors;
}

- (void)removeImplementationForSelector:(SEL)selector {
  NSString *selectorString = NSStringFromSelector(selector);
  [self.originalAppDelegateImps removeObjectForKey:selectorString];
}

- (void)swizzleSelector:(SEL)originalSelector
                inClass:(Class)klass
     withImplementation:(IMP)swizzledImplementation
             inProtocol:(Protocol *)protocol {
  Method originalMethod = class_getInstanceMethod(klass, originalSelector);

  if (originalMethod) {
    // This class implements this method, so replace the original implementation
    // with our new implementation and save the old implementation.

    IMP __original_method_implementation =
        method_setImplementation(originalMethod, swizzledImplementation);

    IMP __nonexistant_method_implementation = [self nonExistantMethodImplementationForClass:klass];

    if (__original_method_implementation &&
        __original_method_implementation != __nonexistant_method_implementation &&
        __original_method_implementation != swizzledImplementation) {
      [self saveOriginalImplementation:__original_method_implementation
                           forSelector:originalSelector];
    }
  } else {
    // The class doesn't have this method, so add our swizzled implementation as the
    // original implementation of the original method.
    struct objc_method_description method_description =
        protocol_getMethodDescription(protocol, originalSelector, NO, YES);

    BOOL methodAdded = class_addMethod(klass,
                                       originalSelector,
                                       swizzledImplementation,
                                       method_description.types);
    if (!methodAdded) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeRemoteNotificationsProxyMethodNotAdded,
                              @"Could not add method for %@ to class %@",
                              NSStringFromSelector(originalSelector),
                              NSStringFromClass(klass));
    }
  }
  [self trackSwizzledSelector:originalSelector ofClass:klass];
}

- (void)unswizzleSelector:(SEL)selector inClass:(Class)klass {

  Method swizzledMethod = class_getInstanceMethod(klass, selector);
  if (!swizzledMethod) {
    // This class doesn't seem to have this selector as an instance method? Bail out.
    return;
  }

  IMP original_imp = [self originalImplementationForSelector:selector];
  if (original_imp) {
    // Restore the original implementation as the current implementation
    method_setImplementation(swizzledMethod, original_imp);
    [self removeImplementationForSelector:selector];
  } else {
    // This class originally did not have an implementation for this selector.

    // We can't actually remove methods in Objective C 2.0, but we could set
    // its method to something non-existent. This should give us the same
    // behavior as if the method was not implemented.
    // See: http://stackoverflow.com/a/8276527/9849

    IMP nonExistantMethodImplementation = [self nonExistantMethodImplementationForClass:klass];
    method_setImplementation(swizzledMethod, nonExistantMethodImplementation);
  }
}

#pragma mark - Reflection Helpers

// This is useful to generate from a stable, "known missing" selector, as the IMP can be compared
// in case we are setting an implementation for a class that was previously "unswizzled" into a
// non-existant implementation.
- (IMP)nonExistantMethodImplementationForClass:(Class)klass {
  SEL nonExistantSelector = NSSelectorFromString(@"aNonExistantMethod");
  IMP nonExistantMethodImplementation = class_getMethodImplementation(klass, nonExistantSelector);
  return nonExistantMethodImplementation;
}

// A safe, non-leaky way return a property object by its name
id getNamedPropertyFromObject(id object, NSString *propertyName, Class klass) {
  SEL selector = NSSelectorFromString(propertyName);
  if (![object respondsToSelector:selector]) {
    return nil;
  }
  if (!klass) {
    klass = [NSObject class];
  }
  // Suppress clang warning about leaks in performSelector
  // The alternative way to perform this is to invoke
  // the method as a block (see http://stackoverflow.com/a/20058585),
  // but this approach sometimes returns incomplete objects.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
  id property = [object performSelector:selector];
#pragma clang diagnostic pop
  if (![property isKindOfClass:klass]) {
    return nil;
  }
  return property;
}

#pragma mark - Swizzled Methods

void FCM_swizzle_appDidReceiveRemoteNotification(id self,
                                                 SEL _cmd,
                                                 UIApplication *app,
                                                 NSDictionary *userInfo) {
  [[FIRMessaging messaging] appDidReceiveMessage:userInfo];

  IMP original_imp =
      [[FIRMessagingRemoteNotificationsProxy sharedProxy] originalImplementationForSelector:_cmd];
  if (original_imp) {
    ((void (*)(id, SEL, UIApplication *, NSDictionary *))original_imp)(self,
                                                                       _cmd,
                                                                       app,
                                                                       userInfo);
  }
}

void FCM_swizzle_appDidReceiveRemoteNotificationWithHandler(
    id self, SEL _cmd, UIApplication *app, NSDictionary *userInfo,
    void (^handler)(UIBackgroundFetchResult)) {

  [[FIRMessaging messaging] appDidReceiveMessage:userInfo];

  IMP original_imp =
      [[FIRMessagingRemoteNotificationsProxy sharedProxy] originalImplementationForSelector:_cmd];
  if (original_imp) {
    ((void (*)(id, SEL, UIApplication *, NSDictionary *,
               void (^)(UIBackgroundFetchResult)))original_imp)(
        self, _cmd, app, userInfo, handler);
  }
}

/**
 * Swizzle the notification handler for iOS 10+ devices.
 * Signature of original handler is as below:
 * - (void)userNotificationCenter:(UNUserNotificationCenter *)center
 *        willPresentNotification:(UNNotification *)notification
 *          withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
 * In order to make FCM SDK compile and compatible with iOS SDKs before iOS 10, hide the
 * parameter types from the swizzling implementation.
 */
void FCM_swizzle_willPresentNotificationWithHandler(
    id self, SEL _cmd, id center, id notification, void (^handler)(NSUInteger)) {

  FIRMessagingRemoteNotificationsProxy *proxy = [FIRMessagingRemoteNotificationsProxy sharedProxy];
  IMP original_imp = [proxy originalImplementationForSelector:_cmd];

  void (^callOriginalMethodIfAvailable)(void) = ^{
    if (original_imp) {
      ((void (*)(id, SEL, id, id, void (^)(NSUInteger)))original_imp)(
          self, _cmd, center, notification, handler);
    }
    return;
  };

  Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
  Class notificationClass = NSClassFromString(@"UNNotification");
  if (!notificationCenterClass || !notificationClass) {
    // Can't find UserNotifications framework. Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
  }

  if (!center || ![center isKindOfClass:[notificationCenterClass class]]) {
    // Invalid parameter type from the original method.
    // Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
    return;
  }

  if (!notification || ![notification isKindOfClass:[notificationClass class]]) {
    // Invalid parameter type from the original method.
    // Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
    return;
  }

  if (!handler) {
    // Invalid parameter type from the original method.
    // Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
    return;
  }

  // Attempt to access the user info
  id notificationUserInfo = userInfoFromNotification(notification);

  if (!notificationUserInfo) {
    // Could not access notification.request.content.userInfo.
    callOriginalMethodIfAvailable();
    return;
  }

  [[FIRMessaging messaging] appDidReceiveMessage:notificationUserInfo];
  // Execute the original implementation.
  callOriginalMethodIfAvailable();
}

/**
 * Swizzle the notification handler for iOS 10+ devices.
 * Signature of original handler is as below:
 * - (void)userNotificationCenter:(UNUserNotificationCenter *)center
 *     didReceiveNotificationResponse:(UNNotificationResponse *)response
 *     withCompletionHandler:(void (^)(void))completionHandler
 * In order to make FCM SDK compile and compatible with iOS SDKs before iOS 10, hide the
 * parameter types from the swizzling implementation.
 */
void FCM_swizzle_didReceiveNotificationResponseWithHandler(
    id self, SEL _cmd, id center, id response, void (^handler)(void)) {

  FIRMessagingRemoteNotificationsProxy *proxy = [FIRMessagingRemoteNotificationsProxy sharedProxy];
  IMP original_imp = [proxy originalImplementationForSelector:_cmd];

  void (^callOriginalMethodIfAvailable)(void) = ^{
    if (original_imp) {
      ((void (*)(id, SEL, id, id, void (^)(void)))original_imp)(
          self, _cmd, center, response, handler);
    }
    return;
  };

  Class notificationCenterClass = NSClassFromString(@"UNUserNotificationCenter");
  Class responseClass = NSClassFromString(@"UNNotificationResponse");
  if (!center || ![center isKindOfClass:[notificationCenterClass class]]) {
    // Invalid parameter type from the original method.
    // Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
    return;
  }

  if (!response || ![response isKindOfClass:[responseClass class]]) {
    // Invalid parameter type from the original method.
    // Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
    return;
  }

  if (!handler) {
    // Invalid parameter type from the original method.
    // Do not swizzle, just execute the original method.
    callOriginalMethodIfAvailable();
    return;
  }

  // Try to access the response.notification property
  SEL notificationSelector = NSSelectorFromString(@"notification");
  if (![response respondsToSelector:notificationSelector]) {
    // Cannot access the .notification property.
    callOriginalMethodIfAvailable();
    return;
  }
  id notificationClass = NSClassFromString(@"UNNotification");
  id notification = getNamedPropertyFromObject(response, @"notification", notificationClass);

  // With a notification object, use the common code to reach deep into notification
  // (notification.request.content.userInfo)
  id notificationUserInfo = userInfoFromNotification(notification);
  if (!notificationUserInfo) {
    // Could not access notification.request.content.userInfo.
    callOriginalMethodIfAvailable();
    return;
  }

  [[FIRMessaging messaging] appDidReceiveMessage:notificationUserInfo];
  // Execute the original implementation.
  callOriginalMethodIfAvailable();
}

id userInfoFromNotification(id notification) {

  // Select the userInfo field from UNNotification.request.content.userInfo.
  SEL requestSelector = NSSelectorFromString(@"request");
  if (![notification respondsToSelector:requestSelector]) {
    // Cannot access the request property.
    return nil;
  }
  Class requestClass = NSClassFromString(@"UNNotificationRequest");
  id notificationRequest = getNamedPropertyFromObject(notification, @"request", requestClass);

  SEL notificationContentSelector = NSSelectorFromString(@"content");
  if (!notificationRequest
      || ![notificationRequest respondsToSelector:notificationContentSelector]) {
    // Cannot access the content property.
    return nil;
  }
  Class contentClass = NSClassFromString(@"UNNotificationContent");
  id notificationContent = getNamedPropertyFromObject(notificationRequest,
                                                      @"content",
                                                      contentClass);

  SEL notificationUserInfoSelector = NSSelectorFromString(@"userInfo");
  if (!notificationContent
      || ![notificationContent respondsToSelector:notificationUserInfoSelector]) {
    // Cannot access the userInfo property.
    return nil;
  }
  id notificationUserInfo = getNamedPropertyFromObject(notificationContent,
                                                       @"userInfo",
                                                       [NSDictionary class]);

  if (!notificationUserInfo) {
    // This is not the expected notification handler.
    return nil;
  }

  return notificationUserInfo;
}

void FCM_swizzle_messagingDidReceiveMessage(id self, SEL _cmd, FIRMessaging *message,
                                            FIRMessagingRemoteMessage *remoteMessage) {
  [[FIRMessaging messaging] appDidReceiveMessage:remoteMessage.appData];

  IMP original_imp =
      [[FIRMessagingRemoteNotificationsProxy sharedProxy] originalImplementationForSelector:_cmd];
  if (original_imp) {
    ((void (*)(id, SEL, FIRMessaging *, FIRMessagingRemoteMessage *))original_imp)(
        self, _cmd, message, remoteMessage);
  }
}

void FCM_swizzle_appDidFailToRegisterForRemoteNotifications(id self,
                                                            SEL _cmd,
                                                            UIApplication *app,
                                                            NSError *error) {
  // Log the fact that we failed to register for remote notifications
  FIRMessagingLoggerError(kFIRMessagingMessageCodeRemoteNotificationsProxyAPNSFailed,
                          @"Error in "
                          @"application:didFailToRegisterForRemoteNotificationsWithError: %@",
                          error.localizedDescription);
  IMP original_imp =
      [[FIRMessagingRemoteNotificationsProxy sharedProxy] originalImplementationForSelector:_cmd];
  if (original_imp) {
    ((void (*)(id, SEL, UIApplication *, NSError *))original_imp)(self, _cmd, app, error);
  }
}

void FCM_swizzle_appDidRegisterForRemoteNotifications(id self,
                                                      SEL _cmd,
                                                      UIApplication *app,
                                                      NSData *deviceToken) {
  // Pass the APNSToken along to FIRMessaging (and auto-detect the token type)
  [FIRMessaging messaging].APNSToken = deviceToken;

  IMP original_imp =
      [[FIRMessagingRemoteNotificationsProxy sharedProxy] originalImplementationForSelector:_cmd];
  if (original_imp) {
    ((void (*)(id, SEL, UIApplication *, NSData *))original_imp)(self, _cmd, app, deviceToken);
  }
}

@end
