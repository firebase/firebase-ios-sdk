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

#import "NetworkConnectionView.h"

/** Edge insets used by internal subviews. */
static const CGFloat kEdgeInsetsTop = 10.0f;
static const CGFloat kEdgeInsetsBottom = 10.0f;
static const CGFloat kEdgeInsetsLeft = 20.0f;
static const CGFloat kEdgeInsetsRight = 20.0f;

@interface NetworkConnectionView () {
  PerfConnectionStatus _connectionStatus;
}

@property(nonatomic) UIProgressView *progressView;

@end

@implementation NetworkConnectionView

#pragma mark - Initialization

- (instancetype)initWithCoder:(NSCoder *)coder {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

#pragma mark - Properties

- (void)setConnectionStatus:(PerfConnectionStatus)connectionStatus {
  _connectionStatus = connectionStatus;
  self.connectionStatusLabel.text = [self stringForStatus:connectionStatus];
}

- (PerfConnectionStatus)connectionStatus {
  return _connectionStatus;
}

- (void)setTitle:(NSString *)title {
  _title = title;
  [self.networkCallButton setTitle:title forState:UIControlStateNormal];
}

- (void)setProgressViewColor:(UIColor *)progressViewColor {
  _progressViewColor = progressViewColor;
  self.progressView.progressTintColor = progressViewColor;
}

- (UIProgressView *)progressView {
  if (!_progressView) {
#if TARGET_OS_TV
    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
#else
    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
#endif
    _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    _progressView.trackTintColor = [UIColor lightGrayColor];
    _progressView.progressTintColor = [UIColor blueColor];
  }
  return _progressView;
}

- (UIButton *)networkCallButton {
  if (!_networkCallButton) {
    _networkCallButton = [[UIButton alloc] init];
    _networkCallButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_networkCallButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_networkCallButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    _networkCallButton.titleLabel.font = [UIFont systemFontOfSize:12.0];

    _networkCallButton.contentEdgeInsets =
        UIEdgeInsetsMake(kEdgeInsetsTop, kEdgeInsetsLeft, kEdgeInsetsBottom, kEdgeInsetsRight);
    _networkCallButton.layer.cornerRadius = 3.0f;
    _networkCallButton.layer.borderColor = [[UIColor blackColor] CGColor];
    _networkCallButton.layer.borderWidth = 1.0f;

    [_networkCallButton setTitle:@"Make a network request" forState:UIControlStateNormal];

    [_networkCallButton addTarget:self
                           action:@selector(makeNetworkRequest:)
                 forControlEvents:UIControlEventTouchDown];
  }
  return _networkCallButton;
}

- (UILabel *)connectionStatusLabel {
  if (!_connectionStatusLabel) {
    _connectionStatusLabel = [[UILabel alloc] init];
    _connectionStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _connectionStatusLabel.text = [self stringForStatus:_connectionStatus];
    _connectionStatusLabel.textAlignment = NSTextAlignmentRight;
  }
  return _connectionStatusLabel;
}

- (void)makeNetworkRequest:(UIButton *)button {
  [self.delegate networkConnectionViewDidTapRequestButton:self];
}

- (void)createViewTree {
  [self addSubview:self.networkCallButton];
  [self addSubview:self.progressView];
  [self addSubview:self.connectionStatusLabel];
}

#pragma mark - Public methods

- (void)setProgress:(float)progress animated:(BOOL)animated {
  [self.progressView setProgress:progress animated:animated];
}

#pragma mark - View hierarchy methods

- (void)constrainViews {
  NSDictionary<NSString *, UIView *> *viewsDictionary =
      NSDictionaryOfVariableBindings(_networkCallButton, _progressView, _connectionStatusLabel);

  [self addConstraintsString:@"V:|-0-[_networkCallButton(40)]-[_progressView(2)]"
             forViewsBinding:viewsDictionary];

  [self addConstraintsString:@"H:|-5-[_networkCallButton]-4-[_connectionStatusLabel(90)]-5-|"
             forViewsBinding:viewsDictionary];

  [self addConstraintsString:@"H:|-0-[_progressView]-0-|" forViewsBinding:viewsDictionary];

  [NSLayoutConstraint activateConstraints:@[
    [_connectionStatusLabel.topAnchor constraintEqualToAnchor:_networkCallButton.topAnchor],
    [_connectionStatusLabel.bottomAnchor constraintEqualToAnchor:_networkCallButton.bottomAnchor],
  ]];
}

- (void)addConstraintsString:(NSString *)string forViewsBinding:(NSDictionary *)viewsBinding {
  NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:string
                                                                 options:kNilOptions
                                                                 metrics:nil
                                                                   views:viewsBinding];
  [self addConstraints:constraints];
}

- (void)updateConstraints {
  [super updateConstraints];
  if (self.constraints.count == 0) {
    [self constrainViews];
  }
}

- (void)didMoveToSuperview {
  [super didMoveToSuperview];
  if (self.superview != nil && self.subviews.count == 0) {
    [self createViewTree];
  }
}

#pragma mark - Private methods

- (NSString *)stringForStatus:(PerfConnectionStatus)status {
  NSString *statusString = nil;
  switch (status) {
    case ConnectionStatus_NA:
      statusString = @"N/A";
      break;
    case ConnectionStatus_Fail:
      statusString = @"Fail";
      break;
    case ConnectionStatus_Success:
      statusString = @"Success";
      break;
    default:
      NSAssert(NO, @"Unsupported status");
      break;
  }
  return statusString;
}

@end
