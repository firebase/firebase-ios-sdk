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

#import "PerfTraceView.h"

#import "PerfTraceView+Accessibility.h"

@interface PerfTraceView ()

// Views in the view hierarchy.

/** A label for the trace name. */
@property(nonatomic) UILabel *nameLabel;

/** A button that will stop the currently running trace. */
@property(nonatomic) UIButton *stopTraceButton;

/** A button to start a new stage on the currently running trace. */
@property(nonatomic) UIButton *stageButton;

/** A button to increment a metric on the currently running trace. */
@property(nonatomic) UIButton *metricOneButton;

/** A button to increment a second metric on the currently running trace. */
@property(nonatomic) UIButton *metricTwoButton;

/** A button to add a custom attribute to the currently running trace. */
@property(nonatomic) UIButton *customAttributeButton;

/** A label for the current stage state. */
@property(nonatomic) UILabel *recentStageLabel;

// State preserving properties.

/** The current trace. */
@property(nonatomic, readwrite, copy) FIRTrace *trace;

/** The current stage number. */
@property(nonatomic, assign) NSInteger stageNumber;

/** The current value of metric one. */
@property(nonatomic, assign) NSInteger metricOneValue;

/** The current value of metric two. */
@property(nonatomic, assign) NSInteger metricTwoValue;

/** The current custom attribute counter used for their names. */
@property(nonatomic, assign) NSInteger customAttributeCounter;

/** The current custom attribute value to be added to the trade. */
@property(nonatomic) NSString *customAttributeValue;

/** The timestamp of when the trace started for UI labeling purposes. */
@property(nonatomic) NSDate *traceDate;

// Helper properties.
@property(nonatomic) NSLayoutConstraint *bottomConstraint;

/**
 * Picks a custom attribute value from a constant list of values and sets the property.
 * It also auto increments the custom attribute name and updates the button's title.
 */
- (void)chooseCustomAttribute;

@end

@implementation PerfTraceView

#pragma mark - Initialization

- (instancetype)initWithFrame:(CGRect)frame {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  NSAssert(NO, @"Not a valid initializer.");
  return nil;
}

- (instancetype)initWithTrace:(FIRTrace *)trace frame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _trace = trace;
    _traceDate = [NSDate date];
  }
  return self;
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
    [_metricOneButton setTitle:@"metric1 - 0" forState:UIControlStateNormal];
    [_metricTwoButton setTitle:@"metric2 - 0" forState:UIControlStateNormal];
    _nameLabel.text = _trace.name;
    [self chooseCustomAttribute];
  }
}

#pragma mark - Control methods

- (void)stopTrace:(UIButton *)button {
  self.nameLabel.text = [NSString stringWithFormat:@"%@ - %0.2fs", self.trace.name,
                                                   (-1 * [self.traceDate timeIntervalSinceNow])];
  [self.delegate perfTraceViewTraceStopped:self];
  self.trace = nil;
  [self disableActions];
}

/** @brief: Disables all the actionable elements on the view. */
- (void)disableActions {
  self.stopTraceButton.enabled = NO;
  self.metricOneButton.enabled = NO;
  self.metricTwoButton.enabled = NO;
  self.stageButton.enabled = NO;
}

/**
 * Creates new Stage in the trace and adds it to the visual list of stages created.
 *
 * @param button Button that initiated the request.
 */
- (void)createStage:(UIButton *)button {
  NSString *stageName = [NSString stringWithFormat:@"Stage%zd", self.stageNumber];

  NSString *stageNameLabelText = [NSString
      stringWithFormat:@"%@ - %0.2fs", stageName, (-1 * [self.traceDate timeIntervalSinceNow])];

  UILabel *currentLabel = self.recentStageLabel;
  self.recentStageLabel = [self newStageLabel];
  self.recentStageLabel.text = stageNameLabelText;
  [self addSubview:self.recentStageLabel];

  // Stage feature is currently disabled.
  // [self.trace startStageNamed:stageName];

  if (currentLabel) {
    [NSLayoutConstraint activateConstraints:@[
      [self.recentStageLabel.topAnchor constraintEqualToAnchor:currentLabel.bottomAnchor
                                                      constant:10.0f],
      [self.recentStageLabel.leftAnchor constraintEqualToAnchor:currentLabel.leftAnchor],
    ]];
  } else {
    [NSLayoutConstraint activateConstraints:@[
      [self.recentStageLabel.topAnchor
          constraintEqualToAnchor:self.customAttributeButton.bottomAnchor
                         constant:10.0f],
      [self.recentStageLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
    ]];
  }

  if (self.bottomConstraint) {
    [self removeConstraint:self.bottomConstraint];
  }
  self.bottomConstraint =
      [self.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.recentStageLabel.bottomAnchor
                                                     constant:5.0f];
  [self addConstraint:self.bottomConstraint];

  self.stageNumber++;
}

/**
 * Action for incrementing metric one.
 *
 * @param button The button object where the action took place.
 */
- (void)incrementMetricOne:(UIButton *)button {
  self.metricOneValue++;
  [self.trace incrementMetric:@"metric1" byInt:1];
  NSString *stringValue = [NSString stringWithFormat:@"metric1 - %zd", self.metricOneValue];
  [self.metricOneButton setTitle:stringValue forState:UIControlStateNormal];
}

/**
 * Action for incrementing metric two.
 *
 * @param button The button object where the action took place.
 */
- (void)incrementMetricTwo:(UIButton *)button {
  self.metricTwoValue++;
  [self.trace incrementMetric:@"metric2" byInt:1];
  NSString *stringValue = [NSString stringWithFormat:@"metric2 - %zd", self.metricTwoValue];
  [self.metricTwoButton setTitle:stringValue forState:UIControlStateNormal];
}

/**
 * Action for adding a custom attribute onto the trace.
 *
 * @param button The button object where the action took place.
 */
- (void)addCustomAttribute:(UIButton *)button {
  NSString *attrName = [NSString stringWithFormat:@"attr%d", (int)_customAttributeCounter];
  [self.trace setValue:_customAttributeValue forAttribute:attrName];
  ++_customAttributeCounter;
  [self chooseCustomAttribute];
}

#pragma mark - View hierarchy

/** @brief Creates the view hierarchy for the PerfTraceView. */
- (void)createViewTree {
  [self addSubview:self.nameLabel];
  [self addSubview:self.stopTraceButton];
  [self addSubview:self.stageButton];
  [self addSubview:self.metricOneButton];
  [self addSubview:self.metricTwoButton];
  [self addSubview:self.customAttributeButton];
}

/** @brief Constrains for the views inside PerfTraceView. */
- (void)constrainViews {
  [NSLayoutConstraint activateConstraints:@[
    [self.nameLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:5.0f],
    [self.nameLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],

    // Position adding a stage button and stop trace button.
    [self.stopTraceButton.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor
                                                   constant:10.0f],
    [self.stageButton.centerYAnchor constraintEqualToAnchor:self.stopTraceButton.centerYAnchor],
    [self.stopTraceButton.widthAnchor constraintEqualToAnchor:self.stageButton.widthAnchor],
    [self.stageButton.leftAnchor constraintEqualToAnchor:self.stopTraceButton.rightAnchor
                                                constant:50.0f],
    [self.stopTraceButton.rightAnchor constraintEqualToAnchor:self.centerXAnchor constant:-25.0f],

    // Position metric button below stage button.
    [self.metricOneButton.topAnchor constraintEqualToAnchor:self.stageButton.bottomAnchor
                                                   constant:5.0f],
    [self.metricTwoButton.centerYAnchor constraintEqualToAnchor:self.metricOneButton.centerYAnchor],
    [self.metricOneButton.widthAnchor constraintEqualToAnchor:self.metricTwoButton.widthAnchor],
    [self.metricTwoButton.leftAnchor constraintEqualToAnchor:self.metricOneButton.rightAnchor
                                                    constant:50.0f],
    [self.metricOneButton.rightAnchor constraintEqualToAnchor:self.centerXAnchor constant:-25.0f],

    // Position Custom Attribute button below metric buttons.
    [self.customAttributeButton.topAnchor constraintEqualToAnchor:self.metricOneButton.bottomAnchor
                                                         constant:5.0f],
    [self.customAttributeButton.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],

    // Bottom constraint is required to determine height.
    [self.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.customAttributeButton.bottomAnchor
                                                   constant:10.0f],
  ]];
}

#pragma mark - Lazy creation of views.

- (UILabel *)nameLabel {
  if (!_nameLabel) {
    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
  }
  return _nameLabel;
}

- (UILabel *)newStageLabel {
  UILabel *label = [[UILabel alloc] init];
  label.translatesAutoresizingMaskIntoConstraints = NO;

  return label;
}

- (UIButton *)stopTraceButton {
  if (!_stopTraceButton) {
    _stopTraceButton = [self newButton];

    AccessibilityItem *item = [[self class] stopAccessibilityItemWithTraceName:self.trace.name];

    _stopTraceButton.accessibilityLabel = item.accessibilityLabel;
    _stopTraceButton.accessibilityIdentifier = item.accessibilityID;

    [_stopTraceButton setTitle:@"Stop trace" forState:UIControlStateNormal];
    [_stopTraceButton addTarget:self
                         action:@selector(stopTrace:)
               forControlEvents:UIControlEventTouchUpInside];
  }
  return _stopTraceButton;
}

- (UIButton *)stageButton {
  if (!_stageButton) {
    _stageButton = [self newButton];

    AccessibilityItem *item = [[self class] stageAccessibilityItemWithTraceName:self.trace.name];

    _stageButton.accessibilityLabel = item.accessibilityLabel;
    _stageButton.accessibilityIdentifier = item.accessibilityID;

    [_stageButton setTitle:@"Stage" forState:UIControlStateNormal];
    [_stageButton addTarget:self
                     action:@selector(createStage:)
           forControlEvents:UIControlEventTouchUpInside];
  }
  return _stageButton;
}

- (UIButton *)metricOneButton {
  if (!_metricOneButton) {
    _metricOneButton = [self newButton];

    AccessibilityItem *item =
        [[self class] metricOneAccessibilityItemWithTraceName:self.trace.name];

    _metricOneButton.accessibilityLabel = item.accessibilityLabel;
    _metricOneButton.accessibilityIdentifier = item.accessibilityID;

    [_metricOneButton setTitle:@"Metric 1" forState:UIControlStateNormal];
    [_metricOneButton addTarget:self
                         action:@selector(incrementMetricOne:)
               forControlEvents:UIControlEventTouchUpInside];
  }
  return _metricOneButton;
}

- (UIButton *)metricTwoButton {
  if (!_metricTwoButton) {
    _metricTwoButton = [self newButton];

    AccessibilityItem *item =
        [[self class] metricTwoAccessibilityItemWithTraceName:self.trace.name];
    _metricTwoButton.accessibilityLabel = item.accessibilityLabel;
    _metricTwoButton.accessibilityIdentifier = item.accessibilityID;
    [_metricTwoButton setTitle:@"Metric 2" forState:UIControlStateNormal];
    [_metricTwoButton addTarget:self
                         action:@selector(incrementMetricTwo:)
               forControlEvents:UIControlEventTouchUpInside];
  }
  return _metricTwoButton;
}

- (UIButton *)customAttributeButton {
  if (!_customAttributeButton) {
    _customAttributeButton = [self newButton];

    AccessibilityItem *item =
        [[self class] customAttributeAccessibilityItemWithTraceName:self.trace.name];
    _customAttributeButton.accessibilityLabel = item.accessibilityLabel;
    _customAttributeButton.accessibilityIdentifier = item.accessibilityID;
    [_customAttributeButton addTarget:self
                               action:@selector(addCustomAttribute:)
                     forControlEvents:UIControlEventTouchUpInside];
  }
  return _customAttributeButton;
}

#pragma mark - View utility functions

/**
 * Creates a new button with default UI properties.
 *
 * @return button The button that was created.
 */
- (UIButton *)newButton {
  UIButton *button = [[UIButton alloc] init];
  button.translatesAutoresizingMaskIntoConstraints = NO;

  [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
  [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
  button.titleLabel.font = [UIFont systemFontOfSize:12.0];

  button.contentEdgeInsets = UIEdgeInsetsMake(10.0f, 20.0f, 10.0f, 20.0f);
  button.layer.cornerRadius = 3.0f;
  button.layer.borderColor = [[UIColor blackColor] CGColor];
  button.layer.borderWidth = 1.0f;

  return button;
}

- (void)chooseCustomAttribute {
  NSArray<NSString *> *const values = @[
    @"apple", @"pear", @"plum", @"orange", @"purple", @"red", @"blue", @"1", @"2", @"3", @"4", @"5",
    @"6", @"7", @"8", @"9", @"0"
  ];
  _customAttributeValue = values[arc4random_uniform((uint32_t)values.count)];

  NSString *buttonTitle;
  buttonTitle = [NSString stringWithFormat:@"Add Attribute: attr%d with Value: %@",
                                           (int)_customAttributeCounter, _customAttributeValue];
  [_customAttributeButton setTitle:buttonTitle forState:UIControlStateNormal];
}

@end
