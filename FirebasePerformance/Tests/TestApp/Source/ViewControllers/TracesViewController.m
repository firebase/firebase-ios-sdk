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
#import "TracesViewController.h"
#import "../Models/AccessibilityItem.h"
#import "../Models/PerfLogger.h"
#import "../Views/PerfTraceView+Accessibility.h"
#import "../Views/PerfTraceView.h"
#import "TracesViewController+Accessibility.h"

#import "FIRCrashlytics.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

/** Edge insets used by internal subviews. */
static const CGFloat kEdgeInsetsTop = 10.0f;
static const CGFloat kEdgeInsetsBottom = 10.0f;
static const CGFloat kEdgeInsetsLeft = 20.0f;
static const CGFloat kEdgeInsetsRight = 20.0f;

@interface TracesViewController () <PerfTraceViewDelegate>

/** The scroll view where all the PerfTraceViews are added. */
@property(nonatomic) UIScrollView *contentView;

/** Button to add a new PerfTraceView. */
@property(nonatomic) UIButton *addTraceButton;

/** Button to add a new PerfTraceView. */
@property(nonatomic) UIButton *crashButton;

/** Button to add a new PerfTraceView. */
@property(nonatomic) UIButton *nonFatalButton;

/** A counter to maintain the number of traces created. Used for the unique names for traces. */
@property(nonatomic, assign) NSInteger traceCounter;

/** The most recently created PerfTraceView. */
@property(nonatomic) PerfTraceView *recentTraceView;

/**
 * The bottom constraint which manages the content size of the content view (UIScrollView). This is
 * usually the constraint of the most recently added PerfTraceView's bottom to be equal to the
 * bottom of the content view.
 */
@property(nonatomic) NSLayoutConstraint *bottomConstraint;

@end

@implementation TracesViewController

#pragma mark - View life cycle

- (void)loadView {
  UIView *perfView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  perfView.backgroundColor = [UIColor whiteColor];
  self.view = perfView;

  [self createViewTree];
  [self constrainViews];
}

#pragma mark - Properties

- (UIScrollView *)contentView {
  if (!_contentView) {
    _contentView = [[UIScrollView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    _contentView.backgroundColor = [UIColor whiteColor];
    _contentView.showsHorizontalScrollIndicator = NO;
    _contentView.showsVerticalScrollIndicator = YES;
    _contentView.accessibilityLabel = @"ContentView";
  }
  return _contentView;
}

- (UIButton *)addTraceButton {
  if (!_addTraceButton) {
    _addTraceButton = [[UIButton alloc] init];
    _addTraceButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_addTraceButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_addTraceButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    _addTraceButton.titleLabel.font = [UIFont systemFontOfSize:12.0];

    _addTraceButton.contentEdgeInsets =
        UIEdgeInsetsMake(kEdgeInsetsTop, kEdgeInsetsLeft, kEdgeInsetsBottom, kEdgeInsetsRight);
    _addTraceButton.layer.cornerRadius = 3.0f;
    _addTraceButton.layer.borderColor = [[UIColor blackColor] CGColor];
    _addTraceButton.layer.borderWidth = 1.0f;

    [_addTraceButton setTitle:@"Add trace" forState:UIControlStateNormal];

    AccessibilityItem *item = [[self class] addTraceAccessibilityItem];

    _addTraceButton.accessibilityIdentifier = item.accessibilityID;
    _addTraceButton.accessibilityLabel = item.accessibilityLabel;

    [_addTraceButton addTarget:self
                        action:@selector(createAndPositionNewTraceView:)
              forControlEvents:UIControlEventTouchDown];
  }
  return _addTraceButton;
}

- (UIButton *)crashButton {
  if (!_crashButton) {
    _crashButton = [[UIButton alloc] init];
    _crashButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_crashButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_crashButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    _crashButton.titleLabel.font = [UIFont systemFontOfSize:12.0];

    _crashButton.contentEdgeInsets =
        UIEdgeInsetsMake(kEdgeInsetsTop, kEdgeInsetsLeft, kEdgeInsetsBottom, kEdgeInsetsRight);
    _crashButton.layer.cornerRadius = 3.0f;
    _crashButton.layer.borderColor = [[UIColor blackColor] CGColor];
    _crashButton.layer.borderWidth = 1.0f;

    [_crashButton setTitle:@"Crash - Perflytics!" forState:UIControlStateNormal];

    [_crashButton addTarget:self
                     action:@selector(crashButtonTapped:)
           forControlEvents:UIControlEventTouchUpInside];
  }
  return _crashButton;
}

- (UIButton *)nonFatalButton {
  if (!_nonFatalButton) {
    _nonFatalButton = [[UIButton alloc] init];
    _nonFatalButton.translatesAutoresizingMaskIntoConstraints = NO;

    [_nonFatalButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_nonFatalButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    _nonFatalButton.titleLabel.font = [UIFont systemFontOfSize:12.0];

    _nonFatalButton.contentEdgeInsets =
        UIEdgeInsetsMake(kEdgeInsetsTop, kEdgeInsetsLeft, kEdgeInsetsBottom, kEdgeInsetsRight);
    _nonFatalButton.layer.cornerRadius = 3.0f;
    _nonFatalButton.layer.borderColor = [[UIColor blackColor] CGColor];
    _nonFatalButton.layer.borderWidth = 1.0f;

    [_nonFatalButton setTitle:@"Non-Fatal - Perflytics!" forState:UIControlStateNormal];

    [_nonFatalButton addTarget:self
                        action:@selector(nonFatalButtonTapped:)
              forControlEvents:UIControlEventTouchUpInside];
  }
  return _nonFatalButton;
}

- (IBAction)crashButtonTapped:(id)sender {
  NSObject *object = [[NSObject alloc] init];
  [object performSelector:@selector(crashTheApp)];
}

- (IBAction)nonFatalButtonTapped:(id)sender {
  NSURLSession *session = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  NSURL *URL = [NSURL URLWithString:@"https://wifi.google.com"];
  NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:URL];
  urlRequest.timeoutInterval = 2.0;
  NSURLSessionDataTask *dataTask =
      [session dataTaskWithRequest:urlRequest
                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                   NSLog(@"Network request complete.");
                   if (error) {
                     [[FIRCrashlytics crashlytics] recordError:error];
                   } else {
                     NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                     if (httpResponse.statusCode != 200) {
                       NSDictionary *userInfo = @{
                         @"Content-Type" : httpResponse.MIMEType,
                         @"Referrer" : [httpResponse valueForHTTPHeaderField:@"referrer-policy"]
                       };
                       NSError *responseError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                                    code:httpResponse.statusCode
                                                                userInfo:userInfo];
                       [[FIRCrashlytics crashlytics] recordError:responseError];
                     }
                   }
                 }];

  [dataTask resume];
}

#pragma mark - Private Methods

#pragma mark - View hierarchy methods

- (void)constrainViews {
  [self addConstraintsString:@"H:|-40-[_addTraceButton]-40-|"
             forViewsBinding:NSDictionaryOfVariableBindings(_addTraceButton)];

  [self addConstraintsString:@"V:|-60-[_addTraceButton(40)]-10-[_crashButton(40)]-10-[_"
                             @"nonFatalButton(40)]-10-[_contentView]-|"
             forViewsBinding:NSDictionaryOfVariableBindings(_addTraceButton, _crashButton,
                                                            _nonFatalButton, _contentView)];

  [self addConstraintsString:@"H:|-40-[_crashButton]-40-|"
             forViewsBinding:NSDictionaryOfVariableBindings(_crashButton)];

  [self addConstraintsString:@"H:|-40-[_nonFatalButton]-40-|"
             forViewsBinding:NSDictionaryOfVariableBindings(_nonFatalButton)];

  [self addConstraintsString:@"H:|[_contentView]|"
             forViewsBinding:NSDictionaryOfVariableBindings(_contentView)];
}

- (void)addConstraintsString:(NSString *)string forViewsBinding:(NSDictionary *)viewsBinding {
  NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:string
                                                                 options:kNilOptions
                                                                 metrics:nil
                                                                   views:viewsBinding];
  [self.view addConstraints:constraints];
}

- (void)createViewTree {
  [self.view addSubview:self.contentView];
  [self.view addSubview:self.addTraceButton];
  [self.view addSubview:self.crashButton];
  [self.view addSubview:self.nonFatalButton];
}

/**
 * Creates a new trace and adds a PerfTraceView in the view hierarchy.
 *
 * @param button Button that initiated the request.
 */
- (void)createAndPositionNewTraceView:(UIButton *)button {
  PerfTraceView *traceView = [self createTraceView];

  if (!traceView) {
    NSLog(@"Trace creation disabled.");
    return;
  }

  [self.contentView addSubview:traceView];

  // Add constraints to position the new trace view at the bottom of the list of trace views.
  if (self.recentTraceView) {
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.recentTraceView
                                                                 attribute:NSLayoutAttributeTop
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:traceView
                                                                 attribute:NSLayoutAttributeBottom
                                                                multiplier:1.0f
                                                                  constant:10.0f]];

    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:traceView
                                                                 attribute:NSLayoutAttributeLeft
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.recentTraceView
                                                                 attribute:NSLayoutAttributeLeft
                                                                multiplier:1.0f
                                                                  constant:0.0f]];

    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:traceView
                                                                 attribute:NSLayoutAttributeRight
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.recentTraceView
                                                                 attribute:NSLayoutAttributeRight
                                                                multiplier:1.0f
                                                                  constant:0.0f]];
  } else {
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.contentView
                                                                 attribute:NSLayoutAttributeBottom
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:traceView
                                                                 attribute:NSLayoutAttributeBottom
                                                                multiplier:1.0
                                                                  constant:10.0f]];

    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:traceView
                                                                 attribute:NSLayoutAttributeLeft
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeLeft
                                                                multiplier:1.0f
                                                                  constant:10.0f]];

    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:traceView
                                                                 attribute:NSLayoutAttributeRight
                                                                 relatedBy:NSLayoutRelationEqual
                                                                    toItem:self.contentView
                                                                 attribute:NSLayoutAttributeRight
                                                                multiplier:1.0f
                                                                  constant:-10.0f]];
  }

  [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:traceView
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.contentView
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.0f
                                                                constant:0.0f]];

  if (self.bottomConstraint) {
    [self.contentView removeConstraint:self.bottomConstraint];
  }
  self.bottomConstraint = [NSLayoutConstraint constraintWithItem:traceView
                                                       attribute:NSLayoutAttributeTop
                                                       relatedBy:NSLayoutRelationEqual
                                                          toItem:self.contentView
                                                       attribute:NSLayoutAttributeTop
                                                      multiplier:1.0f
                                                        constant:10.0f];

  [self.contentView addConstraint:self.bottomConstraint];

  self.recentTraceView = traceView;
}

/**
 * Creates a new PerfTraceView object with a valid unique name and returns back the object.
 *
 * @return Instance of PerfTraceView.
 */
- (PerfTraceView *)createTraceView {
  PerfLog(@"Create trace view");
  PerfTraceView *traceView = nil;
  NSString *traceName = [NSString stringWithFormat:@"Trace %ld", ++self.traceCounter];
  FIRTrace *trace = [[FIRPerformance sharedInstance] traceWithName:traceName];
  if (trace) {
    [trace start];
    traceView = [[PerfTraceView alloc] initWithTrace:trace frame:CGRectZero];
    traceView.accessibilityLabel = @"traceView";
    traceView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:0.5f];
    traceView.translatesAutoresizingMaskIntoConstraints = NO;
    traceView.delegate = self;
  } else {
    --self.traceCounter;
  }
  return traceView;
}

#pragma mark - PerfTraceViewDelegate methods

- (void)perfTraceViewTraceStopped:(PerfTraceView *)traceView {
  PerfLog(@"Stop trace");
  [traceView.trace stop];
}

@end
