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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMActionURLFollower.h"

@interface FIRIAMActionURLFollower ()
@property(nonatomic, readonly, nonnull, copy) NSSet<NSString *> *appCustomURLSchemesSet;
@property(nonatomic, readonly) BOOL isOldAppDelegateOpenURLDefined;
@property(nonatomic, readonly) BOOL isNewAppDelegateOpenURLDefined;
@property(nonatomic, readonly) BOOL isContinueUserActivityMethodDefined;

@property(nonatomic, readonly, nullable) id<UIApplicationDelegate> appDelegate;
@property(nonatomic, readonly, nonnull) UIApplication *mainApplication;
@end

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
      // We can not dispatch sychronously to main queue if we are already in main queue. That
      // can cause deadlock.
      URLFollower = [[FIRIAMActionURLFollower alloc]
          initWithCustomURLSchemeArray:customSchemeURLs
                       withApplication:UIApplication.sharedApplication];
    } else {
      // If we are not on main thread, dispatch it to main queue since it invovles calling UIKit
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
  } else if ([self isCustomSchemeForCurrentApp:actionURL]) {
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
// @returns YES if that delegate method is defined and returns YES.
- (BOOL)followURLWithAppDelegateOpenURLActivity:(NSURL *)url {
  if (self.isNewAppDelegateOpenURLDefined) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM210008",
                @"iOS 9+ version of App Delegate's application:openURL:options: method detected");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
    return [self.appDelegate application:self.mainApplication openURL:url options:@{}];
#pragma clang pop
  }

  // if we come here, we can try to trigger the older version of openURL method on the app's
  // delegate
  if (self.isOldAppDelegateOpenURLDefined) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240009",
                @"iOS 9 below version of App Delegate's openURL method detected");
    NSString *appBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    BOOL handled = [self.appDelegate application:self.mainApplication
                                         openURL:url
                               sourceApplication:appBundleIdentifier
                                      annotation:@{}];
    return handled;
  }

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240010",
              @"No approriate openURL method defined for App Delegate");
  return NO;
}

// Try to handle the url as a universal link by triggering
// application:continueUserActivity:restorationHandler: on App's delegate object directly.
// @returns YES if that delegate method is defined and seeing a YES being returned from
// trigging it
- (BOOL)followURLWithContinueUserActivity:(NSURL *)url {
  if (self.isContinueUserActivityMethodDefined) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240004",
                @"App delegate responds to application:continueUserActivity:restorationHandler:."
                 "Simulating action url opening from a web browser.");
    NSUserActivity *userActivity =
        [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
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
  } else {
    // fallback to the older version of openURL
    BOOL success = [self.mainApplication openURL:url];
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM240007", @"openURL result is %d", success);
    completion(success);
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
