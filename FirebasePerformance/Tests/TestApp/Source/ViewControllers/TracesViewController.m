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

#pragma mark - Private Methods

#pragma mark - View hierarchy methods

- (void)constrainViews {
  [self addConstraintsString:@"H:|-40-[_addTraceButton]-40-|"
             forViewsBinding:NSDictionaryOfVariableBindings(_addTraceButton)];

  [self addConstraintsString:@"V:|-60-[_addTraceButton(40)]-10-[_contentView]-|"
             forViewsBinding:NSDictionaryOfVariableBindings(_addTraceButton, _contentView)];

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
