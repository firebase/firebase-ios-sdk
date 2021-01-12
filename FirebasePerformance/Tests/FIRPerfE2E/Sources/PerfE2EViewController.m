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

#import "PerfE2EViewController.h"

#import "PerfE2EScreenTracesViewController.h"
#import "PerfNetworkRequestMaker.h"
#import "PerfTraceDelegate.h"
#import "PerfTraceMaker.h"

#import "FirebasePerformance/FIRPerformance.h"
#import "PerfE2EUtils.h"

static NSString *const kURLbasePath = @"fireperf-echo.appspot.com";
static const float kTraceMeanDuration = 3.0;
static const float kTraceDurationDeviation = 0.3;
static const float kNetworkRequestDelayMean = 1.0;
static const float kNetworkRequestDelayDeviation = 0.3;
static const NSInteger kNetworkResponseSizeMean = 1024;
static const NSInteger kNetworkResponseSizeDeviation = 80;
static const NSInteger kNumberTraceLoopCount = 15;
static const NSInteger kNumberNetworkRequestLoopCount = 15;

static NSInteger numberOfPendingTraces = 0;

@interface PerfE2EViewController () <PerfTraceDelegate>

/** Button to initiate the traces and network requests */
@property(nonatomic) UIButton *startTracesButton;

/** Button to navigate to a new screen to generate slow and frozen frames. */
@property(nonatomic) UIButton *testScreenTracesButton;

/** Button to navigate to a new screen to generate slow and frozen frames. */
@property(nonatomic) UILabel *pendingTraceCoungLabel;

@end

@implementation PerfE2EViewController

- (void)loadView {
  UIView *perfView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  perfView.backgroundColor = [UIColor whiteColor];
  self.view = perfView;

  [self createViewTree];
  [self constrainViews];
}

/**
 * Starts the custom trace generation and the network request generation.
 */
- (void)startTraces:(UIButton *)button {
  for (int i = 0; i < kNumberTraceLoopCount; i++) {
    [self createTraceWithInterval:1.0 numberOfTraces:32];
  }
  for (int i = 0; i < kNumberNetworkRequestLoopCount; i++) {
    [self createNetworkRequestWithInterval:1.0 numberOfRequests:32];
  }
}

/** Navigates to the screen that allows us to generate slow and forzen frames. */
- (void)navigateToSlowFramesTest:(UIButton *)button {
  PerfE2EScreenTracesViewController *screenTracesViewController =
      [[PerfE2EScreenTracesViewController alloc] init];
  [self.navigationController pushViewController:screenTracesViewController animated:YES];
}

#pragma mark - Trace delegate methods

- (void)traceStarted {
  numberOfPendingTraces++;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.pendingTraceCoungLabel
        setText:[NSString stringWithFormat:@"Pending traces count - %ld", numberOfPendingTraces]];
  });
}

- (void)traceCompleted {
  numberOfPendingTraces--;
  NSLog(@"Pending traces - %ld", numberOfPendingTraces);
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.pendingTraceCoungLabel
        setText:[NSString stringWithFormat:@"Pending traces count - %ld", numberOfPendingTraces]];
  });
}

#pragma mark - Trace creation methods

/**
 * Creates traces at regular intervals until the number of traces exceeds maxTraceCount.
 *
 * @param interval Interval at which the traces are created.
 * @param maxTraceCount Maximum number of traces to be created.
 */
- (void)createTraceWithInterval:(NSTimeInterval)interval numberOfTraces:(NSInteger)maxTraceCount {
  void (^traceCreationBlock)(NSInteger, NSTimeInterval) =
      ^(NSInteger maxTraceCount, NSTimeInterval interval) {
        __block NSInteger traceCount = 0;
        __block dispatch_source_t traceTimer =
            dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        dispatch_source_set_timer(traceTimer, DISPATCH_TIME_NOW, interval * NSEC_PER_SEC,
                                  0.02 * NSEC_PER_SEC);

        dispatch_source_set_event_handler(traceTimer, ^{
          NSString *traceName = [NSString stringWithFormat:@"t%02ld", (long)traceCount];
          CGFloat gaussianValue =
              randomGaussianValueWithMeanAndDeviation(kTraceMeanDuration, kTraceDurationDeviation);
          CGFloat traceDuration = traceCount + gaussianValue;
          NSLog(@"Creating trace with name %@ for duration %0.2fs", traceName, traceDuration);
          [PerfTraceMaker createTraceWithName:traceName duration:traceDuration delegate:self];

          traceCount++;
          if (traceCount >= maxTraceCount) {
            dispatch_source_cancel(traceTimer);
            traceTimer = nil;
            traceCount = 0;
          }
        });
        dispatch_resume(traceTimer);
      };

  dispatch_async(dispatch_get_main_queue(), ^{
    traceCreationBlock(maxTraceCount, interval);
  });
}

/**
 * Creates network requests at regular intervals until the number of requests exceeds
 * maxRequestCount.
 *
 * @param interval Interval at which the traces are created.
 * @param maxRequestCount Maximum number of traces to be created.
 */
- (void)createNetworkRequestWithInterval:(NSTimeInterval)interval
                        numberOfRequests:(NSInteger)maxRequestCount {
  void (^networkRequestBlock)(NSInteger, NSTimeInterval) =
      ^(NSInteger maxRequestCount, NSTimeInterval interval) {
        __block NSInteger requestCount = 0;
        __block dispatch_source_t networkTimer =
            dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        dispatch_source_set_timer(networkTimer, DISPATCH_TIME_NOW, interval * NSEC_PER_SEC,
                                  0.02 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(networkTimer, ^{
          requestCount++;
          if (requestCount > maxRequestCount) {
            dispatch_source_cancel(networkTimer);
            networkTimer = nil;
          } else {
            NSURLRequest *request = [self generateURLRequestWithChangingProperties];
            NSLog(@"Making network request - %@", request.URL.absoluteString);
            [PerfNetworkRequestMaker performNetworkRequest:request delegate:self];
          }
        });
        dispatch_resume(networkTimer);
      };

  dispatch_async(dispatch_get_main_queue(), ^{
    networkRequestBlock(maxRequestCount, interval);
  });
}

/**
 * Generates a URL request with random scheme, random query path, and random query parameters with a
 * random HTTP method.
 *
 * @return A valid NSURLRequest object.
 */
- (NSURLRequest *)generateURLRequestWithChangingProperties {
  CGFloat delayTime = randomGaussianValueWithMeanAndDeviation(kNetworkRequestDelayMean,
                                                              kNetworkRequestDelayDeviation);
  NSInteger responseSize = (NSInteger)randomGaussianValueWithMeanAndDeviation(
      kNetworkResponseSizeMean, kNetworkResponseSizeDeviation);

  NSString *baseURLString =
      [NSString stringWithFormat:@"%@://%@/%@/?delay=%0.2fs&size=%ld&mime=%@&status=%ld",
                                 [self getRandomURLScheme], kURLbasePath, [self getRandomQueryPath],
                                 delayTime, responseSize, [self getRandomMIMEType],
                                 [self getRandomStatusCode]];

  NSURL *baseURL = [NSURL URLWithString:baseURLString];
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:baseURL];
  [request setTimeoutInterval:5 * 60];
  [request setHTTPMethod:[self getRandomHTTPMethod]];
  return [request copy];
}

/**
 * Generates a random query path.
 *
 * @return A query path.
 */
- (NSString *)getRandomQueryPath {
  static NSArray<NSString *> *queryPaths;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queryPaths = @[
      @"some/random/path",
      @"some/path",
      @"some/path/which/keeps/growing",
    ];
  });
  int random = arc4random_uniform((int)queryPaths.count);
  NSString *queryPath = queryPaths[random];
  return queryPath;
}

/**
 * Generates a random URL scheme.
 *
 * @return A URL scheme.
 */
- (NSString *)getRandomURLScheme {
  static NSArray<NSString *> *URLSchemes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    URLSchemes = @[
      @"http",
      @"https",
    ];
  });
  int random = arc4random_uniform((int)URLSchemes.count);
  NSString *URLScheme = URLSchemes[random];
  return URLScheme;
}

/**
 * Generates a random MIME type.
 *
 * @return A MIME type.
 */
- (NSString *)getRandomMIMEType {
  static NSArray<NSString *> *MIMETypes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    MIMETypes = @[
      @"text/html", @"application/octet-stream", @"application/postscript", @"video/avi",
      @"image/png", @"text/plain"
    ];
  });
  int random = arc4random_uniform((int)MIMETypes.count);
  NSString *MIMEString = MIMETypes[random];
  return MIMEString;
}

/**
 * Generates a random HTTP status code.
 *
 * @return A HTTP status code.
 */
- (NSInteger)getRandomStatusCode {
  static NSArray<NSNumber *> *statusCodes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    statusCodes = @[ @(200), @(201), @(202), @(300), @(400), @(502), @(503), @(504) ];
  });
  int random = arc4random_uniform((int)statusCodes.count);
  NSNumber *statusCode = statusCodes[random];
  return statusCode.integerValue;
}

/**
 * Generates a random HTTP method.
 *
 * @return A HTTP method string.
 */
- (NSString *)getRandomHTTPMethod {
  static NSArray<NSString *> *HTTPMethods;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    HTTPMethods = @[ @"GET", @"POST", @"PUT", @"DELETE", @"PATCH", @"OPTIONS" ];
  });
  int random = arc4random_uniform((int)HTTPMethods.count);
  NSString *HTTPMethod = HTTPMethods[random];
  return HTTPMethod;
}

#pragma mark - View hierarchy methods

/** Adds the relevant subviews to the hierarchy. */
- (void)createViewTree {
  [self.view addSubview:self.startTracesButton];
  [self.view addSubview:self.pendingTraceCoungLabel];
  [self.view addSubview:self.testScreenTracesButton];
}

/** Applies constraints to the view elements. */
- (void)constrainViews {
  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.startTracesButton
                                                        attribute:NSLayoutAttributeCenterX
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeCenterX
                                                       multiplier:1.0
                                                         constant:0.0]];

  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.testScreenTracesButton
                                                        attribute:NSLayoutAttributeCenterX
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeCenterX
                                                       multiplier:1.0
                                                         constant:0.0]];

  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.pendingTraceCoungLabel
                                                        attribute:NSLayoutAttributeCenterX
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeCenterX
                                                       multiplier:1.0
                                                         constant:0.0]];

  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.startTracesButton
                                                        attribute:NSLayoutAttributeBottom
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.pendingTraceCoungLabel
                                                        attribute:NSLayoutAttributeTop
                                                       multiplier:1.0
                                                         constant:-20.0]];

  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.pendingTraceCoungLabel
                                                        attribute:NSLayoutAttributeCenterY
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.view
                                                        attribute:NSLayoutAttributeCenterY
                                                       multiplier:1.0
                                                         constant:0.0]];

  [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.testScreenTracesButton
                                                        attribute:NSLayoutAttributeTop
                                                        relatedBy:NSLayoutRelationEqual
                                                           toItem:self.pendingTraceCoungLabel
                                                        attribute:NSLayoutAttributeBottom
                                                       multiplier:1.0
                                                         constant:20.0]];

  NSDictionary *viewBindings = NSDictionaryOfVariableBindings(_startTracesButton);
  [self.view
      addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_startTracesButton(100)]"
                                                             options:kNilOptions
                                                             metrics:nil
                                                               views:viewBindings]];

  [self.view
      addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_startTracesButton(50)]"
                                                             options:kNilOptions
                                                             metrics:nil
                                                               views:viewBindings]];

  viewBindings = NSDictionaryOfVariableBindings(_pendingTraceCoungLabel);
  [self.view addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[_pendingTraceCoungLabel(200)]"
                                                    options:kNilOptions
                                                    metrics:nil
                                                      views:viewBindings]];

  [self.view addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"V:[_pendingTraceCoungLabel(50)]"
                                                    options:kNilOptions
                                                    metrics:nil
                                                      views:viewBindings]];

  viewBindings = NSDictionaryOfVariableBindings(_testScreenTracesButton);
  [self.view addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"H:[_testScreenTracesButton(150)]"
                                                    options:kNilOptions
                                                    metrics:nil
                                                      views:viewBindings]];

  [self.view addConstraints:[NSLayoutConstraint
                                constraintsWithVisualFormat:@"V:[_testScreenTracesButton(50)]"
                                                    options:kNilOptions
                                                    metrics:nil
                                                      views:viewBindings]];
}

#pragma mark - Lazy loaders

- (UIButton *)startTracesButton {
  if (!_startTracesButton) {
    _startTracesButton = [[UIButton alloc] init];
    _startTracesButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_startTracesButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _startTracesButton.titleLabel.font = [UIFont systemFontOfSize:12.0];

    _startTracesButton.layer.cornerRadius = 3.0f;
    _startTracesButton.layer.borderColor = [[UIColor blackColor] CGColor];
    _startTracesButton.layer.borderWidth = 1.0f;

    [_startTracesButton setTitle:@"Start traces" forState:UIControlStateNormal];

    [_startTracesButton addTarget:self
                           action:@selector(startTraces:)
                 forControlEvents:UIControlEventTouchUpInside];
  }
  return _startTracesButton;
}

- (UILabel *)pendingTraceCoungLabel {
  if (!_pendingTraceCoungLabel) {
    _pendingTraceCoungLabel = [[UILabel alloc] init];
    _pendingTraceCoungLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _pendingTraceCoungLabel.textAlignment = NSTextAlignmentCenter;
  }

  return _pendingTraceCoungLabel;
}

- (UIButton *)testScreenTracesButton {
  if (!_testScreenTracesButton) {
    _testScreenTracesButton = [[UIButton alloc] init];
    _testScreenTracesButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_testScreenTracesButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _testScreenTracesButton.titleLabel.font = [UIFont systemFontOfSize:12.0];

    _testScreenTracesButton.layer.cornerRadius = 3.0f;
    _testScreenTracesButton.layer.borderColor = [[UIColor blackColor] CGColor];
    _testScreenTracesButton.layer.borderWidth = 1.0f;

    [_testScreenTracesButton setTitle:@"Test screen traces" forState:UIControlStateNormal];

    [_testScreenTracesButton addTarget:self
                                action:@selector(navigateToSlowFramesTest:)
                      forControlEvents:UIControlEventTouchUpInside];
  }
  return _testScreenTracesButton;
}

@end
