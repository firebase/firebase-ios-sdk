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

#import "FirebaseInAppMessaging/Sources/DefaultUI/Banner/FIRIAMBannerViewUIWindow.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRIAMRenderingWindowHelper.h"
#import "FirebaseInAppMessaging/Sources/Private/Util/UIApplication+FIRForegroundWindowScene.h"

@implementation FIRIAMRenderingWindowHelper

+ (UIWindow *)windowForBlockingView {
  static UIWindow *UIWindowForModal;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
      UIWindowForModal = [[self class] iOS13PlusWindow];
    } else {
      UIWindowForModal = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    UIWindowForModal.windowLevel = UIWindowLevelNormal;
  });
  return UIWindowForModal;
}

+ (UIWindow *)windowForNonBlockingView {
  static UIWindow *UIWindowForBanner;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
      UIWindowForBanner = [[self class] iOS13PlusBannerWindow];
    } else {
      UIWindowForBanner =
          [[FIRIAMBannerViewUIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    UIWindowForBanner.windowLevel = UIWindowLevelNormal;
  });

  return UIWindowForBanner;
}

+ (UIWindow *)iOS13PlusWindow API_AVAILABLE(ios(13.0)) {
  UIWindowScene *foregroundedScene = [[UIApplication sharedApplication] fir_foregroundWindowScene];
  if (foregroundedScene.delegate) {
    return [[UIWindow alloc] initWithWindowScene:foregroundedScene];
  } else {
    return [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  }
}

+ (FIRIAMBannerViewUIWindow *)iOS13PlusBannerWindow API_AVAILABLE(ios(13.0)) {
  UIWindowScene *foregroundedScene = [[UIApplication sharedApplication] fir_foregroundWindowScene];
  if (foregroundedScene.delegate) {
    return [[FIRIAMBannerViewUIWindow alloc] initWithWindowScene:foregroundedScene];
  } else {
    return [[FIRIAMBannerViewUIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  }
}

@end

#endif  // TARGET_OS_IOS
