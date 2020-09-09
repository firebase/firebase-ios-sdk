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

@implementation FIRIAMBannerViewUIWindow

// For banner view message, we still allow the user to interact with the app's underlying view
// outside banner view's visible area.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  if (self.rootViewController && self.rootViewController.view) {
    return CGRectContainsPoint(self.rootViewController.view.frame, point);
  } else {
    return NO;
  }
}
@end

#endif  // TARGET_OS_IOS
