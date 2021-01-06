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

#import "ScreenTracesViewController.h"
#import "ScreenTracesTestScreensListViewController.h"

@interface ScreenTracesViewController () <UISplitViewControllerDelegate>

@end

@implementation ScreenTracesViewController

- (instancetype)init {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

- (instancetype)initAndSetup {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    ScreenTracesTestScreensListViewController *masterView =
        [[ScreenTracesTestScreensListViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController *masterNav =
        [[UINavigationController alloc] initWithRootViewController:masterView];
    self.viewControllers = @[ masterNav ];
    self.delegate = self;
  }
  return self;
}

@end
