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

+ (UIWindow *)uiWindowForModalView {
  static UIWindow *uiWindowForModal;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    UIWindow *appWindow = [[[UIApplication sharedApplication] delegate] window];
    uiWindowForModal = [[UIWindow alloc] initWithFrame:[appWindow frame]];
    uiWindowForModal.windowLevel = UIWindowLevelNormal;
  });
  return uiWindowForModal;
}

+ (UIWindow *)uiWindowForBannerView {
  static UIWindow *uiWindowForBanner;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    UIWindow *appWindow = [[[UIApplication sharedApplication] delegate] window];
    uiWindowForBanner = [[FIDBannerViewUIWindow alloc] initWithFrame:[appWindow frame]];
    uiWindowForBanner.windowLevel = UIWindowLevelNormal;
  });

  return uiWindowForBanner;
}

+ (UIWindow *)uiWindowForImageOnlyView {
  static UIWindow *uiWindowForImageOnly;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    UIWindow *appWindow = [[[UIApplication sharedApplication] delegate] window];
    uiWindowForImageOnly = [[UIWindow alloc] initWithFrame:[appWindow frame]];
    uiWindowForImageOnly.windowLevel = UIWindowLevelNormal;
  });

  return uiWindowForImageOnly;
}
@end
