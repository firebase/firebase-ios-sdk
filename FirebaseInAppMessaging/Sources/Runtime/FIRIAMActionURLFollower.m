/*
 * Copyright 2018 Google
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMActionURLFollower.h"

NS_EXTENSION_UNAVAILABLE("Firebase In App Messaging is not supported for iOS extensions.")
@interface FIRIAMActionURLFollower ()
@property(nonatomic, readonly, nonnull, copy) NSSet<NSString *> *appCustomURLSchemesSet;
@property(nonatomic, readonly) BOOL isOldAppDelegateOpenURLDefined;
@property(nonatomic, readonly) BOOL isNewAppDelegateOpenURLDefined;
@property(nonatomic, readonly) BOOL isContinueUserActivityMethodDefined;

@property(nonatomic, readonly, nullable) id<UIApplicationDelegate> appDelegate;
@property(nonatomic, readonly, nonnull) UIApplication *mainApplication;
@end

NS_EXTENSION_UNAVAILABLE("Firebase In App Messaging is not supported for iOS extensions.")
@implementation FIRIAMActionURLFollower

+ (FIRIAMActionURLFollower *)actionURLFollower {
  static FIRIAMActionURLFollower *URLFollower;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    NSMutableArray<NSString *> *customSchemeURLs = [[NSMutableArray alloc] init];

    // Reading the custom url list from the environment.
    NSBundle *appBundle = [NSBundle mainBundle];
    if (appBundle) {
      id URLTypesID = [appBundle objectForInfoDictionaryKey:@"CFBundleURLTypes"];
      if ([URLTypesID isKindOfClass:[NSArray class]]) {
        NSArray *urlTypesArray = (NSArray *)URLTypesID;

        for (id nextURLType in urlTypesArray) {
          if ([nextURLType isKindOfClass:[NSDictionary class]]) {
            NSDictionary *nextURLTypeDict = (NSDictionary *)nextURLType;
            id nextSchemeArray = nextURLTypeDict[@"CFBundleURLSchemes"];
            if (nextSchemeArray && [nextSchemeArray isKindOfClass:[NSArray class]]) {
              [customSchemeURLs addObjectsFromArray:nextSchemeArray];
            }
          }
        }
      }
    }
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM300010",
                @"Detected %d custom URL schemes from environment", (int)customSchemeURLs.count);

    if ([NSThread isMainThread]) {
      // We can not dispatch synchronously to main queue if we are already in main queue. That
      // can cause deadlock.
      URLFollower = [[FIRIAMActionURLFollower alloc]
          initWithCustomURLSchemeArray:customSchemeURLs
                       withApplication:UIApplication.sharedApplication];
    } else {
      // If we are not on main thread, dispatch it to main queue since it involves calling UIKit
      // methods, which are required to be carried out on main queue.
      dispatch_sync(dispatch_get_main_queue(), ^{
        URLFollower = [[FIRIAMActionURLFollower alloc]
            initWithCustomURLSchemeArray:customSchemeURLs
                         withApplication:UIApplication.sharedApplication];
      });
    }
  });
  return URLFollower;
}

- (instancetype)initWithCustomURLSchemeArray:(NSArray<NSString *> *)customURLScheme
                             withApplication:(UIApplication *)application {
  if (self = [super init]) {
    _appCustomURLSchemesSet = [NSSet setWithArray:customURLScheme];
    _mainApplication = application;
    _appDelegate = [application delegate];

    if (_appDelegate) {
      _isOldAppDelegateOpenURLDefined = [_appDelegate
          respondsToSelector:@selector(application:openURL:sourceApplication:annotation:)];

      _isNewAppDelegateOpenURLDefined =
          [_appDelegate respondsToSelector:@selector(application:openURL:options:)];

      _isContinueUserActivityMethodDefined = [_appDelegate
          respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)];
    }
  }
  return self;
}

- (void)followActionURL:(NSURL *)actionURL withCompletionBlock:(void (^)(BOOL success))completion {
  // So this is the logic of the url following flow
  //  1 If it's a http or https link
  //     1.1 If delegate implements application:continueUserActivity:restorationHandler: and calling
  //       it returns YES: the flow stops here: we have finished the url-following action
  //     1.2 In other cases: fall through to step 3
  //  2 If the URL scheme matches any element in appCustomURLSchemes
  //     2.1 Triggers application:openURL:options: or
  //     application:openURL:sourceApplication:annotation:
  //          depending on their availability.
  //  3 Use UIApplication openURL: or openURL:options:completionHandler: to have iOS system to deal
  //     with the url following.
  //
  //  The rationale for doing step 1 and 2 instead of simply doing step 3 for all cases are:
  //     I)  calling UIApplication openURL with the universal link targeted for current app would
  //         not cause the link being treated as a universal link. See apple doc at
  // https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html
  //         So step 1 is trying to handle this gracefully
  //     II) If there are other apps on the same device declaring the same custom url scheme as for
  //         the current app, doing step 3 directly have the risk of triggering another app for
  //         handling the custom scheme url: See the note about "If more than one third-party" from
  // https://developer.apple.com/library/content/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html
  //         So step 2 is to optimize user experience by short-circuiting the engagement with iOS
  //         system

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240007", @"Following action url %@", actionURL);

  if ([self.class isHttpOrHttpsScheme:actionURL]) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240001", @"Try to treat it as a universal link.");
    if ([self followURLWithContinueUserActivity:actionURL]) {
      completion(YES);
      return;  // following the url has been fully handled by App Delegate's
               // continueUserActivity method
    }
    if ([self followURLWithSceneContinueUserActivity:actionURL]) {
      completion(YES);
      return;  // following the url has been fully handled by Scene Delegate's
               // continueUserActivity method
    }
  } else if ([self isCustomSchemeForCurrentApp:actionURL]) {
    // for scene delegates, we can't reasonably support this. as such, we just follow
    // apple's security guidance of "developers should use universal links instead".
    // if folks want to use url schemes, it's up to them to properly support them.
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240002", @"Custom URL scheme matches.");
    if ([self followURLWithAppDelegateOpenURLActivity:actionURL]) {
      completion(YES);
      return;  // following the url has been fully handled by App Delegate's openURL method
    }
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240003", @"Open the url via iOS.");
  [self followURLViaIOS:actionURL withCompletionBlock:completion];
}

// Try to handle the url as a custom scheme url link by triggering
// application:openURL:options: on App's delegate object directly.
// @return YES if that delegate method is defined and returns YES.
- (BOOL)followURLWithAppDelegateOpenURLActivity:(NSURL *)url {
  if (self.isNewAppDelegateOpenURLDefined) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM210008",
                @"iOS 9+ version of App Delegate's application:openURL:options: method detected");
    return [self.appDelegate application:self.mainApplication openURL:url options:@{}];
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240010",
              @"No appropriate openURL method defined for App Delegate");
  return NO;
}

// Try to handle the url as a universal link by triggering
// application:continueUserActivity:restorationHandler: on App's delegate object directly.
// @return YES if that delegate method is defined and seeing a YES being returned from
// trigging it
- (BOOL)followURLWithContinueUserActivity:(NSURL *)url {
  if (self.isContinueUserActivityMethodDefined) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240004",
                @"App delegate responds to application:continueUserActivity:restorationHandler:."
                 "Simulating action url opening from a web browser.");
    // Use string literal to ensure compatibility with Xcode 26 and iOS 18
    NSString *browsingWebType = @"NSUserActivityTypeBrowsingWeb";
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:browsingWebType];
    userActivity.webpageURL = url;
    BOOL handled = [self.appDelegate application:self.mainApplication
                            continueUserActivity:userActivity
                              restorationHandler:^(NSArray *restorableObjects) {
                                // mimic system behavior of triggering restoreUserActivityState:
                                // method on each element of restorableObjects
                                for (id nextRestoreObject in restorableObjects) {
                                  if ([nextRestoreObject isKindOfClass:[UIResponder class]]) {
                                    UIResponder *responder = (UIResponder *)nextRestoreObject;
                                    [responder restoreUserActivityState:userActivity];
                                  }
                                }
                              }];
    if (handled) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240005",
                  @"App handling acton URL returns YES, no more further action taken");
    } else {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240004", @"App handling acton URL returns NO.");
    }
    return handled;
  } else {
    return NO;
  }
}

// Try to handle the url as a universal link by triggering
// scene:continueUserActivity: on any active scene delegate object directly.
// @return YES if an scene delegate implementing that method was found and
// invoked
- (BOOL)followURLWithSceneContinueUserActivity:(NSURL *)url {
  NSString *browsingWebType = @"NSUserActivityTypeBrowsingWeb";
  NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:browsingWebType];
  userActivity.webpageURL = url;

  __block BOOL handled = NO;
  void (^executionBlock)(void) = ^{
    NSSet<UIScene *> *connectedScenes = self.mainApplication.connectedScenes;
    UIScene *targetScene = nil;
    id<UISceneDelegate> targetDelegate = nil;
    for (UIScene *scene in connectedScenes) {
      id<UISceneDelegate> sceneDelegate = scene.delegate;
      if ([sceneDelegate respondsToSelector:@selector(scene:continueUserActivity:)]) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
          targetScene = scene;
          targetDelegate = sceneDelegate;
          break;
        } else if (scene.activationState == UISceneActivationStateForegroundInactive) {
          // a scene in the `ForegroundInactive` state is visible and loaded
          // in the foreground, but is temporarily not receiving touch events for
          // whatever reason (eg; because a system dialog, permission prompt,
          // or notification center overlay is covering it).
          // So we fall back to any scene in this state, if we don't find
          // a better alternative (a scene that's in the foreground and also
          // active).
          targetScene = scene;
          targetDelegate = sceneDelegate;
        }
      }
    }

    if (targetScene && targetDelegate) {
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240004",
                  @"Scene delegate responds to scene:continueUserActivity."
                   "Simulating action url opening.");
      [targetDelegate scene:targetScene continueUserActivity:userActivity];
      handled = YES;
      // since scene:continueUserActivity: returns void, we assume it is handled
      // once we find an active scene delegate implementing it.
    }
  };

  if ([NSThread isMainThread]) {
    executionBlock();
  } else {
    // shouldn't happen in our cases, but might happen if the developer
    // invokes the display delegate methods from a background thread in
    // a custom UI component or something akin
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM240011",
                  @"URL following was triggered on a background thread. Moving to main thread.");
    dispatch_sync(dispatch_get_main_queue(), executionBlock);
  }
  return handled;
}

- (void)followURLViaIOS:(NSURL *)url withCompletionBlock:(void (^)(BOOL success))completion {
  if ([self.mainApplication respondsToSelector:@selector(openURL:options:completionHandler:)]) {
    NSDictionary *options = @{};
    [self.mainApplication
                  openURL:url
                  options:options
        completionHandler:^(BOOL success) {
          FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240006", @"openURL result is %d", success);
          completion(success);
        }];
  }
}

- (BOOL)isCustomSchemeForCurrentApp:(NSURL *)url {
  NSString *schemeInLowerCase = [url.scheme lowercaseString];
  return [self.appCustomURLSchemesSet containsObject:schemeInLowerCase];
}

+ (BOOL)isHttpOrHttpsScheme:(NSURL *)url {
  NSString *schemeInLowerCase = [url.scheme lowercaseString];
  return
      [schemeInLowerCase isEqualToString:@"https"] || [schemeInLowerCase isEqualToString:@"http"];
}
@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
