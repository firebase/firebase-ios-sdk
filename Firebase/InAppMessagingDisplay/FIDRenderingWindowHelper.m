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

#import "FIDRenderingWindowHelper.h"
#import "FIDBannerViewUIWindow.h"

@implementation FIDRenderingWindowHelper

+ (UIWindow *)UIWindowForModalView {
  static UIWindow *UIWindowForModal;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    if (@available(iOS 13.0, *)) {
      UIWindowScene *foregroundedScene = [[self class] foregroundedScene];
      UIWindowForModal = [[UIWindow alloc] initWithWindowScene:foregroundedScene];
    } else {
      UIWindowForModal = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    UIWindowForModal.windowLevel = UIWindowLevelNormal;
  });
  return UIWindowForModal;
}

+ (UIWindow *)UIWindowForBannerView {
  static UIWindow *UIWindowForBanner;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    if (@available(iOS 13.0, *)) {
      UIWindowScene *foregroundedScene = [[self class] foregroundedScene];
      UIWindowForBanner = [[FIDBannerViewUIWindow alloc] initWithWindowScene:foregroundedScene];
    } else {
      UIWindowForBanner =
          [[FIDBannerViewUIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    UIWindowForBanner.windowLevel = UIWindowLevelNormal;
  });

  return UIWindowForBanner;
}

+ (UIWindow *)UIWindowForImageOnlyView {
  static UIWindow *UIWindowForImageOnly;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    if (@available(iOS 13.0, *)) {
      UIWindowScene *foregroundedScene = [[self class] foregroundedScene];
      UIWindowForImageOnly = [[UIWindow alloc] initWithWindowScene:foregroundedScene];
    } else {
      UIWindowForImageOnly = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    UIWindowForImageOnly.windowLevel = UIWindowLevelNormal;
  });

  return UIWindowForImageOnly;
}

+ (UIWindowScene *)foregroundedScene API_AVAILABLE(ios(13.0)) {
  for (UIWindowScene *connectedScene in [UIApplication sharedApplication].connectedScenes) {
    if (connectedScene.activationState == UISceneActivationStateForegroundActive) {
      return connectedScene;
    }
  }
  return nil;
}
@end
