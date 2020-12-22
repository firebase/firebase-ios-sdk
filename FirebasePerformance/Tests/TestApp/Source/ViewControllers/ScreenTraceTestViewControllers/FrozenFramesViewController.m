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

// Non-google3 relative import to support building with Xcode.
#import "FrozenFramesViewController.h"

/** Edge insets used by internal subviews. */
static const CGFloat kEdgeInsetsTop = 10.0f;
static const CGFloat kEdgeInsetsBottom = 10.0f;
static const CGFloat kEdgeInsetsLeft = 20.0f;
static const CGFloat kEdgeInsetsRight = 20.0f;

@interface FrozenFramesViewController ()

/** The activity indicator that is being animated on screen. */
@property(nonatomic, weak) UIActivityIndicatorView *activityIndicator;

/** The button whose action causes the main thread to sleep for 5 seconds. */
@property(nonatomic, weak) UIButton *freezeButton;

@end

@implementation FrozenFramesViewController

#pragma mark - View Life Cycle

- (void)loadView {
  UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  view.backgroundColor = [UIColor darkGrayColor];
  self.view = view;

  [self createViewTree];
  [self constrainViews];
}

- (void)viewWillAppear:(BOOL)animated {
  [self.activityIndicator startAnimating];
}

- (void)viewWillDisappear:(BOOL)animated {
  [self.activityIndicator stopAnimating];
}

#pragma mark - Private methods

/** Creates and adds the necessary subviews. */
- (void)createViewTree {
  [self addActivityIndicator];
  [self addFreezeButton];
}

/** Adds NSLayoutConstraints to the activity indicator. */
- (void)constrainActivityIndicator {
  NSArray *horizontalConstraints = [[NSLayoutConstraint
      constraintsWithVisualFormat:@"H:|-(>=20)-[_activityIndicator]-(>=20)-|"
                          options:0
                          metrics:nil
                            views:NSDictionaryOfVariableBindings(_activityIndicator)]
      arrayByAddingObject:[NSLayoutConstraint constraintWithItem:_activityIndicator
                                                       attribute:NSLayoutAttributeCenterX
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:self.view
                                                       attribute:NSLayoutAttributeCenterX
                                                      multiplier:1.f
                                                        constant:0.f]];
  NSArray *verticalConstraints = [[NSLayoutConstraint
      constraintsWithVisualFormat:@"V:|-(>=20)-[_activityIndicator]-(>=20)-|"
                          options:0
                          metrics:nil
                            views:NSDictionaryOfVariableBindings(_activityIndicator)]
      arrayByAddingObject:[NSLayoutConstraint constraintWithItem:_activityIndicator
                                                       attribute:NSLayoutAttributeCenterY
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:self.view
                                                       attribute:NSLayoutAttributeCenterY
                                                      multiplier:1.f
                                                        constant:0.f]];

  [self.view addConstraints:horizontalConstraints];
  [self.view addConstraints:verticalConstraints];
}

/** Adds NSLayoutConstraints to the freezeButton. */
- (void)constrainButton {
  NSArray *horizontalConstraints = [[NSLayoutConstraint
      constraintsWithVisualFormat:@"H:|-(>=20)-[_freezeButton]-(>=20)-|"
                          options:0
                          metrics:nil
                            views:NSDictionaryOfVariableBindings(_freezeButton)]
      arrayByAddingObject:[NSLayoutConstraint constraintWithItem:_freezeButton
                                                       attribute:NSLayoutAttributeCenterX
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:self.view
                                                       attribute:NSLayoutAttributeCenterX
                                                      multiplier:1.f
                                                        constant:0.f]];
  NSArray *verticalConstraints = [NSLayoutConstraint
      constraintsWithVisualFormat:@"V:[_freezeButton]-100-|"
                          options:0
                          metrics:nil
                            views:NSDictionaryOfVariableBindings(_freezeButton)];
  [self.view addConstraints:horizontalConstraints];
  [self.view addConstraints:verticalConstraints];
}

/** Calls all the methods that add the necessary constraints for the views on screen. */
- (void)constrainViews {
  [self constrainButton];
  [self constrainActivityIndicator];
}

/** Sets up and adds the activity indicator as a subview of the root view. */
- (void)addActivityIndicator {
  UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  activityIndicator.alpha = 1.0;
  self.activityIndicator = activityIndicator;
  [self.view addSubview:activityIndicator];
}

/** Sets up and adds the freezeButton as a subview of the root view. */
- (void)addFreezeButton {
  UIButton *freezeButton = [[UIButton alloc] init];
  freezeButton.translatesAutoresizingMaskIntoConstraints = NO;
  [freezeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  freezeButton.backgroundColor = [UIColor whiteColor];
  [freezeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
  freezeButton.titleLabel.font = [UIFont systemFontOfSize:12.0];
  freezeButton.contentEdgeInsets =
      UIEdgeInsetsMake(kEdgeInsetsTop, kEdgeInsetsLeft, kEdgeInsetsBottom, kEdgeInsetsRight);
  freezeButton.layer.cornerRadius = 3.0f;
  freezeButton.layer.borderColor = [[UIColor blackColor] CGColor];
  freezeButton.layer.borderWidth = 1.0f;

  [freezeButton setTitle:@"Stall the main thread for 5 seconds" forState:UIControlStateNormal];

  [freezeButton addTarget:self
                   action:@selector(stallMainThread)
         forControlEvents:UIControlEventTouchDown];
  self.freezeButton = freezeButton;
  [self.view addSubview:freezeButton];
}

/** Stalls the main thread for 5 seconds. */
- (void)stallMainThread {
  dispatch_async(dispatch_get_main_queue(), ^{
    [NSThread sleepForTimeInterval:5];
  });
}

@end
