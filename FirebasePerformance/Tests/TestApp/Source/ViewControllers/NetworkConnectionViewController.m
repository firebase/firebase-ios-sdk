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
#import "NetworkConnectionViewController.h"
#import "../Models/PerfLogger.h"
#import "../Views/NetworkConnectionView.h"
#import "NetworkConnectionViewController+Accessibility.h"

@interface NetworkConnectionViewController () <NetworkConnectionViewDelegate>

// Models
@property(nonatomic, strong) id<NetworkConnection> connection;
@property(nonatomic, copy) NSString *connectionTitle;

// Views
@property(nonatomic) UILabel *endpointLabel;
@property(nonatomic, weak) NetworkConnectionView *connectionView;

@end

@implementation NetworkConnectionViewController

#pragma mark - Initialization

- (nonnull instancetype)initWithNetworkConnection:(nonnull id<NetworkConnection>)connection
                                            title:(nonnull NSString *)title {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.connection = connection;
    self.connectionTitle = title;
  }
  return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

#pragma mark - View life cycle

- (void)loadView {
  UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  view.backgroundColor = [UIColor whiteColor];
  view.translatesAutoresizingMaskIntoConstraints = NO;
  self.view = view;

  [self createViewTree];
  [self constrainViews];
}

#pragma mark - Private methods

- (void)createViewTree {
  NetworkConnectionView *connectionView = [[NetworkConnectionView alloc] init];
  connectionView.translatesAutoresizingMaskIntoConstraints = NO;
  connectionView.title = self.connectionTitle;

  AccessibilityItem *item = [NetworkConnectionViewController
      statusLabelAccessibilityItemWithConnectionName:self.connectionTitle];

  connectionView.connectionStatusLabel.accessibilityIdentifier = item.accessibilityID;
  connectionView.connectionStatusLabel.accessibilityLabel = item.accessibilityLabel;

  [self.view addSubview:connectionView];
  connectionView.delegate = self;
  self.connectionView = connectionView;
}

- (void)constrainViews {
  NSDictionary *viewsDict = NSDictionaryOfVariableBindings(_connectionView);

  NSArray *horizontal = [NSLayoutConstraint constraintsWithVisualFormat:@"|-[_connectionView]-|"
                                                                options:0
                                                                metrics:nil
                                                                  views:viewsDict];
  [self.view addConstraints:horizontal];

  NSArray *vertical = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[_connectionView]-|"
                                                              options:0
                                                              metrics:nil
                                                                views:viewsDict];
  [self.view addConstraints:vertical];
}

/**
 * Determines if the autopush endpoint should be used.
 *
 * @return BOOL stating if the autopush endpoint should be used.
 */
- (BOOL)shouldUseAutoPushEndpoint {
  BOOL autopushEndpoint = NO;
#ifdef FPR_AUTOPUSH_ENDPOINT
  autopushEndpoint = YES;
#endif
  return autopushEndpoint;
}

- (UILabel *)endpointLabel {
  if (!_endpointLabel) {
    _endpointLabel = [[UILabel alloc] init];
    _endpointLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _endpointLabel.textAlignment = NSTextAlignmentRight;
    _endpointLabel.accessibilityLabel = @"Endpoint";
    if ([self shouldUseAutoPushEndpoint]) {
      _endpointLabel.text = @"autopush";
    } else {
      _endpointLabel.text = @"prod";
    }
  }
  return _endpointLabel;
}

- (void)updateUIForOperationCompleted {
  PerfLog(@"Operation completed - update UI");
  self.connectionView.networkCallButton.enabled = YES;
  [self.connectionView setProgress:1.0 animated:YES];
}

#pragma mark - NetworkConnectionViewDelegate

- (void)networkConnectionViewDidTapRequestButton:(NetworkConnectionView *)connectionView {
  [self.connectionView setProgress:0.f animated:NO];
  self.connectionView.networkCallButton.enabled = NO;
  self.connectionView.connectionStatus = ConnectionStatus_NA;
  self.connectionView.progressViewColor = [UIColor blueColor];

  dispatch_after(0.f, dispatch_get_main_queue(), ^{
    [self.connectionView setProgress:0.5f animated:YES];
  });
  __weak NetworkConnectionViewController *weakSelf = self;

  PerfLog(@"Start perform network request");
  [self.connection
      makeNetworkRequestWithSuccessCallback:^{
        PerfLog(@"Network operation complited with success");
        dispatch_async(dispatch_get_main_queue(), ^{
          [weakSelf updateUIForOperationCompleted];
          weakSelf.connectionView.progressViewColor = [UIColor greenColor];
          self.connectionView.connectionStatus = ConnectionStatus_Success;
          PerfLog(@"Label text changed to success");
        });
      }
      failureCallback:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          PerfLog(@"Network operation complited with fail: %@", error.localizedDescription);
          [weakSelf updateUIForOperationCompleted];
          weakSelf.connectionView.progressViewColor = [UIColor redColor];
          self.connectionView.connectionStatus = ConnectionStatus_Fail;
          PerfLog(@"Label text changed to success");
        });
      }];
}

@end
