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
#if TARGET_OS_IOS

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/DefaultUI/Banner/FIRIAMBannerViewController.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/Card/FIRIAMCardViewController.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRCore+InAppMessagingDisplay.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRIAMDefaultDisplayImpl.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRIAMRenderingWindowHelper.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/ImageOnly/FIRIAMImageOnlyViewController.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/Modal/FIRIAMModalViewController.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/FIRIAMTimeFetcher.h"
#import "FirebaseInAppMessaging/Sources/Public/FirebaseInAppMessaging/FIRInAppMessaging.h"

@implementation FIRIAMDefaultDisplayImpl

+ (void)load {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveConfigureSDKNotification:)
                                               name:kFIRAppReadyToConfigureSDKNotification
                                             object:nil];
}

+ (void)didReceiveConfigureSDKNotification:(NSNotification *)notification {
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID100010",
              @"Got notification for kFIRAppReadyToConfigureSDKNotification. Setting display "
               "component on headless SDK.");

  FIRIAMDefaultDisplayImpl *display = [[FIRIAMDefaultDisplayImpl alloc] init];
  [FIRInAppMessaging inAppMessaging].messageDisplayComponent = display;
}

+ (NSBundle *)getViewResourceBundle {
  static NSBundle *resourceBundle;
  static dispatch_once_t onceToken;
  Class myClass = [self class];

  dispatch_once(&onceToken, ^{
    NSString *bundledResource;

    // When using SPM, Xcode scopes resources to a target, creating a bundle.
#if SWIFT_PACKAGE
    // FIAM only provides default UIs for iOS. FIAM for tvOS will not attempt to provide a default
    // display.
    bundledResource = @"Firebase_FirebaseInAppMessaging_iOS";
#else
    bundledResource = @"InAppMessagingDisplayResources";
#endif  // SWIFT_PACKAGE

    NSBundle *containingBundle;
    NSURL *bundleURL;
    // The containing bundle is different whether FIAM is statically or dynamically linked.
    for (containingBundle in @[ [NSBundle mainBundle], [NSBundle bundleForClass:myClass] ]) {
      bundleURL = [containingBundle URLForResource:bundledResource withExtension:@"bundle"];
      if (bundleURL != nil) break;
    }

    if (bundleURL == nil) {
      FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100007",
                    @"FIAM Display Resource bundle "
                     "is missing: not contained within bundle %@",
                    containingBundle);
      return;
    }

    resourceBundle = [NSBundle bundleWithURL:bundleURL];

    if (resourceBundle == nil) {
      FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100007",
                    @"FIAM Display Resource bundle "
                     "is missing: not contained within bundle %@",
                    containingBundle);
    }
  });
  return resourceBundle;
}

+ (void)displayCardViewWithMessageDefinition:(FIRInAppMessagingCardDisplay *)cardMessage
                             displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSBundle *resourceBundle = [self getViewResourceBundle];

    if (resourceBundle == nil) {
      NSError *error =
          [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                              code:FIAMDisplayRenderErrorTypeUnspecifiedError
                          userInfo:@{NSLocalizedDescriptionKey : @"Resource bundle is missing."}];
      [displayDelegate displayErrorForMessage:cardMessage error:error];
      return;
    }

    FIRIAMTimerWithNSDate *timeFetcher = [[FIRIAMTimerWithNSDate alloc] init];
    FIRIAMCardViewController *cardVC =
        [FIRIAMCardViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                               displayMessage:cardMessage
                                                              displayDelegate:displayDelegate
                                                                  timeFetcher:timeFetcher];

    if (cardVC == nil) {
      FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100011",
                    @"View controller can not be created.");
      NSError *error = [NSError
          errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                     code:FIAMDisplayRenderErrorTypeUnspecifiedError
                 userInfo:@{NSLocalizedDescriptionKey : @"View controller could not be created"}];
      [displayDelegate displayErrorForMessage:cardMessage error:error];
      return;
    }

    UIWindow *displayUIWindow = [FIRIAMRenderingWindowHelper windowForBlockingView];
    displayUIWindow.rootViewController = cardVC;
    [displayUIWindow setHidden:NO];
  });
}

+ (void)displayModalViewWithMessageDefinition:(FIRInAppMessagingModalDisplay *)modalMessage
                              displayDelegate:
                                  (id<FIRInAppMessagingDisplayDelegate>)displayDelegate {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSBundle *resourceBundle = [self getViewResourceBundle];

    if (resourceBundle == nil) {
      NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                           code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                       userInfo:@{@"message" : @"resource bundle is missing"}];
      [displayDelegate displayErrorForMessage:modalMessage error:error];
      return;
    }

    FIRIAMTimerWithNSDate *timeFetcher = [[FIRIAMTimerWithNSDate alloc] init];
    FIRIAMModalViewController *modalVC =
        [FIRIAMModalViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                                displayMessage:modalMessage
                                                               displayDelegate:displayDelegate
                                                                   timeFetcher:timeFetcher];

    if (modalVC == nil) {
      FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100004",
                    @"View controller can not be created.");
      NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                           code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                       userInfo:@{}];
      [displayDelegate displayErrorForMessage:modalMessage error:error];
      return;
    }

    UIWindow *displayUIWindow = [FIRIAMRenderingWindowHelper windowForBlockingView];
    displayUIWindow.rootViewController = modalVC;
    [displayUIWindow setHidden:NO];
  });
}

+ (void)displayBannerViewWithMessageDefinition:(FIRInAppMessagingBannerDisplay *)bannerMessage
                               displayDelegate:
                                   (id<FIRInAppMessagingDisplayDelegate>)displayDelegate {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSBundle *resourceBundle = [self getViewResourceBundle];

    if (resourceBundle == nil) {
      NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                           code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                       userInfo:@{}];
      [displayDelegate displayErrorForMessage:bannerMessage error:error];
      return;
    }

    FIRIAMTimerWithNSDate *timeFetcher = [[FIRIAMTimerWithNSDate alloc] init];
    FIRIAMBannerViewController *bannerVC =
        [FIRIAMBannerViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                                 displayMessage:bannerMessage
                                                                displayDelegate:displayDelegate
                                                                    timeFetcher:timeFetcher];

    if (bannerVC == nil) {
      FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100008",
                    @"Banner view controller can not be created.");
      NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                           code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                       userInfo:@{}];
      [displayDelegate displayErrorForMessage:bannerMessage error:error];
      return;
    }

    UIWindow *displayUIWindow = [FIRIAMRenderingWindowHelper windowForNonBlockingView];
    displayUIWindow.rootViewController = bannerVC;
    [displayUIWindow setHidden:NO];
  });
}

+ (void)displayImageOnlyViewWithMessageDefinition:
            (FIRInAppMessagingImageOnlyDisplay *)imageOnlyMessage
                                  displayDelegate:
                                      (id<FIRInAppMessagingDisplayDelegate>)displayDelegate {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSBundle *resourceBundle = [self getViewResourceBundle];

    if (resourceBundle == nil) {
      NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                           code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                       userInfo:@{}];
      [displayDelegate displayErrorForMessage:imageOnlyMessage error:error];
      return;
    }

    FIRIAMTimerWithNSDate *timeFetcher = [[FIRIAMTimerWithNSDate alloc] init];
    FIRIAMImageOnlyViewController *imageOnlyVC =
        [FIRIAMImageOnlyViewController instantiateViewControllerWithResourceBundle:resourceBundle
                                                                    displayMessage:imageOnlyMessage
                                                                   displayDelegate:displayDelegate
                                                                       timeFetcher:timeFetcher];

    if (imageOnlyVC == nil) {
      FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100006",
                    @"Image only view controller can not be created.");
      NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                           code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                       userInfo:@{}];
      [displayDelegate displayErrorForMessage:imageOnlyMessage error:error];
      return;
    }

    UIWindow *displayUIWindow = [FIRIAMRenderingWindowHelper windowForBlockingView];
    displayUIWindow.rootViewController = imageOnlyVC;
    [displayUIWindow setHidden:NO];
  });
}

#pragma mark - protocol FIRInAppMessagingDisplay
- (void)displayMessage:(FIRInAppMessagingDisplayMessage *)messageForDisplay
       displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate {
  if ([messageForDisplay isKindOfClass:[FIRInAppMessagingModalDisplay class]]) {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID100000", @"Display a modal message.");
    [self.class displayModalViewWithMessageDefinition:(FIRInAppMessagingModalDisplay *)
                                                          messageForDisplay
                                      displayDelegate:displayDelegate];

  } else if ([messageForDisplay isKindOfClass:[FIRInAppMessagingBannerDisplay class]]) {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID100001", @"Display a banner message.");
    [self.class displayBannerViewWithMessageDefinition:(FIRInAppMessagingBannerDisplay *)
                                                           messageForDisplay
                                       displayDelegate:displayDelegate];
  } else if ([messageForDisplay isKindOfClass:[FIRInAppMessagingImageOnlyDisplay class]]) {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID100002", @"Display an image only message.");
    [self.class displayImageOnlyViewWithMessageDefinition:(FIRInAppMessagingImageOnlyDisplay *)
                                                              messageForDisplay
                                          displayDelegate:displayDelegate];
  } else if ([messageForDisplay isKindOfClass:[FIRInAppMessagingCardDisplay class]]) {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID100009", @"Display a card message.");
    [self.class displayCardViewWithMessageDefinition:(FIRInAppMessagingCardDisplay *)
                                                         messageForDisplay
                                     displayDelegate:displayDelegate];

  } else {
    FIRLogWarning(kFIRLoggerInAppMessagingDisplay, @"I-FID100003",
                  @"Unknown message type %@ "
                   "Don't know how to handle it.",
                  messageForDisplay.class);
    NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingDisplayErrorDomain
                                         code:FIAMDisplayRenderErrorTypeUnspecifiedError
                                     userInfo:@{}];
    [displayDelegate displayErrorForMessage:messageForDisplay error:error];
  }
}
@end

#endif  // TARGET_OS_IOS
