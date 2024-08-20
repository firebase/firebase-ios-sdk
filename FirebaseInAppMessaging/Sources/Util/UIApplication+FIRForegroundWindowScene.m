/*
 * Copyright 2023 Google LLC
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

#import "FirebaseInAppMessaging/Sources/Private/Util/UIApplication+FIRForegroundWindowScene.h"

@implementation UIApplication (FIRForegroundWindowScene)

- (nullable UIWindowScene *)fir_foregroundWindowScene {
  for (UIScene *connectedScene in [UIApplication sharedApplication].connectedScenes) {
    // Direct check for UIWindowScene class is required to avoid return an instance of another
    // UIScene subclass. It may be an instance of CPTemplateApplicationScene or
    // CPTemplateApplicationDashboardScene in case of CarPlay. This check fixes the following crash:
    // https://github.com/firebase/firebase-ios-sdk/issues/9376
    if ([connectedScene isKindOfClass:[UIWindowScene class]] &&
        connectedScene.activationState == UISceneActivationStateForegroundActive) {
      return (UIWindowScene *)connectedScene;
    }
  }
  return nil;
}

@end

/// Stub used to force the linker to include the categories in this file.
void FIRInclude_UIApplication_FIRForegroundWindowScene_Category(void) {
}

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
