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
#import "NetworkRequestsViewController.h"
#import "../Networking/NetworkConnectionsFactory.h"
#import "NetworkConnectionViewController.h"

static NSString *const kConnectionsConfigurationFileName = @"network_connections";

static const CGFloat kNetworkConnectionViewHeight = 70.f;
static const CGFloat kConnectionsListTopOffset = 30.f;

@interface NetworkRequestsViewController ()

@property(nonatomic, strong) NSMutableArray<UIViewController *> *connectionControllers;
@property(nonatomic, weak) UIScrollView *scrollView;
@property(nonatomic, strong) NSDictionary<NSString *, id<NetworkConnection>> *titleConnectionPairs;

@end

@implementation NetworkRequestsViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.titleConnectionPairs = [NetworkConnectionsFactory
        titleConnectionPairsFromConfigFile:kConnectionsConfigurationFileName];

    self.connectionControllers = [[NSMutableArray alloc] init];
  }
  return self;
}

#pragma mark - View Life Cycle

- (void)loadView {
  UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  view.backgroundColor = [UIColor whiteColor];
  self.view = view;

  [self createViewTree];
  [self constrainViews];
}

#pragma mark - Private methods

- (CGSize)scrollContentViewSize {
  return CGSizeMake(
      [UIScreen mainScreen].bounds.size.width,
      self.titleConnectionPairs.count * kNetworkConnectionViewHeight + kConnectionsListTopOffset);
}

- (void)createViewTree {
  UIScrollView *scrollView = [[UIScrollView alloc] init];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;

  CGSize contentViewSize = [self scrollContentViewSize];
  UIView *contentView = [[UIView alloc]
      initWithFrame:CGRectMake(0., 0., contentViewSize.width, contentViewSize.height)];

  [self.view addSubview:scrollView];
  self.scrollView = scrollView;
  scrollView.scrollEnabled = YES;
  scrollView.contentSize = contentViewSize;
  scrollView.accessibilityIdentifier = @"RequestsScrollView";

  [self.titleConnectionPairs enumerateKeysAndObjectsUsingBlock:^(
                                 NSString *_Nonnull title,
                                 id<NetworkConnection> _Nonnull connection, BOOL *_Nonnull stop) {
    NetworkConnectionViewController *connectionController =
        [[NetworkConnectionViewController alloc] initWithNetworkConnection:connection title:title];
    [self.connectionControllers addObject:connectionController];
    [contentView addSubview:connectionController.view];
  }];

  [scrollView addSubview:contentView];
}

- (void)constraintScrollView {
  NSArray *horizontalConstraints =
      [NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[_scrollView]-0-|"
                                              options:0
                                              metrics:nil
                                                views:NSDictionaryOfVariableBindings(_scrollView)];
  [self.view addConstraints:horizontalConstraints];

  NSArray *verticalConstraints =
      [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_scrollView]"
                                              options:0
                                              metrics:nil
                                                views:NSDictionaryOfVariableBindings(_scrollView)];

  [self.view addConstraints:verticalConstraints];

  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_scrollView
                                                        attribute:NSLayoutAttributeBottom
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.bottomLayoutGuide
                                                        attribute:NSLayoutAttributeTop
                                                       multiplier:1.0
                                                         constant:0.0]];
}

- (void)constrainViews {
  [self constraintScrollView];

  __block UIView *previousView = nil;

  [self.connectionControllers enumerateObjectsUsingBlock:^(
                                  UIViewController *_Nonnull connectionController, NSUInteger idx,
                                  BOOL *_Nonnull stop) {
    UIView *connectionView = connectionController.view;
    connectionView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.scrollView addConstraints:[self horizontalConstraintsForConnectionView:connectionView]];

    [self.scrollView addConstraints:[self verticalConstraintsForConnectionView:connectionView
                                                          previousViewIfExists:previousView]];

    previousView = connectionView;
  }];
}

- (NSArray *)horizontalConstraintsForConnectionView:(UIView *)connectionView {
  return [NSLayoutConstraint
      constraintsWithVisualFormat:@"|-0-[connectionView]-0-|"
                          options:0
                          metrics:nil
                            views:NSDictionaryOfVariableBindings(connectionView)];
}

- (NSArray *)verticalConstraintsForConnectionView:(UIView *)connectionView
                             previousViewIfExists:(UIView *)previousView {
  NSArray *constraints = nil;

  NSDictionary *metrics = @{
    @"viewHeight" : @(kNetworkConnectionViewHeight),
    @"topOffset" : @(kConnectionsListTopOffset)
  };

  NSString *visualFormat = nil;

  if (previousView) {
    NSDictionary *viewsBindings = NSDictionaryOfVariableBindings(connectionView, previousView);
    visualFormat = @"V:[previousView]-0-[connectionView(viewHeight)]";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:viewsBindings];
  } else {
    NSDictionary *viewsBindings = NSDictionaryOfVariableBindings(connectionView);
    visualFormat = @"V:|-(topOffset)-[connectionView(viewHeight)]";
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:visualFormat
                                                          options:0
                                                          metrics:metrics
                                                            views:viewsBindings];
  }

  return constraints;
}

@end
