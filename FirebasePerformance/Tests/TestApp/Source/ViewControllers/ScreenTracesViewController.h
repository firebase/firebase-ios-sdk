// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <UIKit/UIKit.h>

/** This is a split view controller subclass that sets up everything needed to display the catalog
 *  of all the screen trace test screens available.
 */
@interface ScreenTracesViewController : UISplitViewController

NS_ASSUME_NONNULL_BEGIN

/** Initializes and sets up the children view controllers. */
- (instancetype)initAndSetup NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

NS_ASSUME_NONNULL_END

@end
