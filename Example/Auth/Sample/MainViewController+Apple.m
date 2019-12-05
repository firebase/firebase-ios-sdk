/*
 * Copyright 2019 Google
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

#import "MainViewController+Apple.h"

#import <AuthenticationServices/AuthenticationServices.h>

#import "AppManager.h"
#import "MainViewController+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MainViewController (Apple)

- (StaticContentTableViewSection *)appleAuthSection API_AVAILABLE(ios(13.0)) {
  return [StaticContentTableViewSection sectionWithTitle:@"Apple Auth" cells:@[]];
}

@end

NS_ASSUME_NONNULL_END
