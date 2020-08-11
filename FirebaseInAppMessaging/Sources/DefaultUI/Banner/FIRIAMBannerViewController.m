/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseInAppMessaging/Sources/DefaultUI/Banner/FIRIAMBannerViewController.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRCore+InAppMessagingDisplay.h"

@interface FIRIAMBannerViewController ()

@property(nonatomic, readwrite) FIRInAppMessagingBannerDisplay *bannerDisplayMessage;

@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewWidthConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewHeightConstraint;

@property(weak, nonatomic)
    IBOutlet NSLayoutConstraint *imageBottomAlignWithBodyLabelBottomConstraint;
@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property(weak, nonatomic) IBOutlet UILabel *titleLabel;
@property(weak, nonatomic) IBOutlet UILabel *bodyLabel;

// Banner view will be rendered and dismissed with animation. Within viewDidLayoutSubviews function,
// we would position the view so that it's out of UIWindow range on the top so that later on it can
// slide in with animation. However, viewDidLayoutSubviews is also triggred in other scenarios
// like split view on iPad or device orientation changes where we don't want to hide the banner for
// animations. So to have different logic, we use this property to tell the two different
// cases apart and apply different positioning logic accordingly in viewDidLayoutSubviews.
@property(nonatomic) BOOL hidingForAnimation;

@property(nonatomic, nullable) NSTimer *autoDismissTimer;
@end

// The image display area dimension in points
static const CGFloat kBannerViewImageWidth = 60;
static const CGFloat kBannerViewImageHeight = 60;

static const NSTimeInterval kBannerViewAnimationDuration = 0.3;  // in seconds

// Banner view will auto dismiss after this amount of time of showing if user does not take
// any other actions. It's in seconds.
static const NSTimeInterval kBannerAutoDimissTime = 12;

// If the window width is larger than this threshold, we cap banner view width
// by it: showing a non full-width banner when it happens.
static const CGFloat kBannerViewMaxWidth = 736;

static const CGFloat kSwipeUpThreshold = -10.0f;

@implementation FIRIAMBannerViewController

+ (FIRIAMBannerViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:(FIRInAppMessagingBannerDisplay *)bannerMessage
                                displayDelegate:
                                    (id<FIRInAppMessagingDisplayDelegate>)displayDelegate
                                    timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"FIRInAppMessageDisplayStoryboard"
                                                       bundle:resourceBundle];

  if (storyboard == nil) {
    FIRLogError(kFIRLoggerInAppMessagingDisplay, @"I-FID300002",
                @"Storyboard '"
                 "FIRInAppMessageDisplayStoryboard' not found in bundle %@",
                resourceBundle);
    return nil;
  }
  FIRIAMBannerViewController *bannerVC = (FIRIAMBannerViewController *)[storyboard
      instantiateViewControllerWithIdentifier:@"banner-view-vc"];
  bannerVC.displayDelegate = displayDelegate;
  bannerVC.bannerDisplayMessage = bannerMessage;
  bannerVC.timeFetcher = timeFetcher;

  return bannerVC;
}

- (FIRInAppMessagingDisplayMessage *)inAppMessage {
  return self.bannerDisplayMessage;
}

- (void)setupRecognizers {
  UIPanGestureRecognizer *panSwipeRecognizer =
      [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanSwipe:)];
  [self.view addGestureRecognizer:panSwipeRecognizer];

  UITapGestureRecognizer *tapGestureRecognizer =
      [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapped:)];
  tapGestureRecognizer.delaysTouchesBegan = YES;
  tapGestureRecognizer.numberOfTapsRequired = 1;

  [self.view addGestureRecognizer:tapGestureRecognizer];
}

- (void)handlePanSwipe:(UIPanGestureRecognizer *)recognizer {
  // Detect the swipe gesture
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    CGPoint vel = [recognizer velocityInView:recognizer.view];
    if (vel.y < kSwipeUpThreshold) {
      [self closeViewFromManualDismiss];
    }
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view from its nib.

  [self setupRecognizers];

  self.titleLabel.text = self.bannerDisplayMessage.title;
  self.bodyLabel.text = self.bannerDisplayMessage.bodyText;

  if (self.bannerDisplayMessage.imageData) {
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;

    UIImage *image = [UIImage imageWithData:self.bannerDisplayMessage.imageData.imageRawData];

    if (fabs(image.size.width / image.size.height - 1) > 0.02) {
      // width and height differ by at least 2%, need to adjust image view
      // size to respect the ratio

      // reduce height or width of the image view to retain the ratio of the image
      if (image.size.width > image.size.height) {
        CGFloat newImageHeight = kBannerViewImageWidth * image.size.height / image.size.width;
        self.imageViewHeightConstraint.constant = newImageHeight;
      } else {
        CGFloat newImageWidth = kBannerViewImageHeight * image.size.width / image.size.height;
        self.imageViewWidthConstraint.constant = newImageWidth;
      }
    }
    self.imageView.image = image;
  } else {
    // Hide image and remove the bottom constraint between body label and image view.
    self.imageViewWidthConstraint.constant = 0;
    self.imageBottomAlignWithBodyLabelBottomConstraint.active = NO;
  }

  // Set some rendering effects based on settings.
  self.view.backgroundColor = self.bannerDisplayMessage.displayBackgroundColor;
  self.titleLabel.textColor = self.bannerDisplayMessage.textColor;
  self.bodyLabel.textColor = self.bannerDisplayMessage.textColor;

  self.view.layer.masksToBounds = NO;
  self.view.layer.shadowOffset = CGSizeMake(2, 1);
  self.view.layer.shadowRadius = 2;
  self.view.layer.shadowOpacity = 0.4;

  // Calculate status bar height.
  CGFloat statusBarHeight = 0;
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  if (@available(iOS 13.0, *)) {
    UIStatusBarManager *manager =
        [UIApplication sharedApplication].keyWindow.windowScene.statusBarManager;

    statusBarHeight = manager.statusBarFrame.size.height;
  } else {
#endif
    statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
#if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000
  }
#endif

  // Pin title label below status bar with cushion.
  [[self.titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor
                                             constant:statusBarHeight + 3] setActive:YES];

  // When created, we are hiding it for later animation
  self.hidingForAnimation = YES;
  [self setupAutoDismissTimer];
}

- (void)dismissViewWithAnimation:(void (^)(void))completion {
  CGRect rectInNormalState = self.view.frame;
  CGAffineTransform hidingTransform =
      CGAffineTransformMakeTranslation(0, -rectInNormalState.size.height);

  [UIView animateWithDuration:kBannerViewAnimationDuration
      delay:0
      options:UIViewAnimationOptionCurveEaseInOut
      animations:^{
        self.view.transform = hidingTransform;
      }
      completion:^(BOOL finished) {
        completion();
      }];
}

- (void)closeViewFromAutoDismiss {
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300001", @"Auto dismiss the banner view");
  [self dismissViewWithAnimation:^(void) {
    [self dismissView:FIRInAppMessagingDismissTypeAuto];
  }];
}

- (void)closeViewFromManualDismiss {
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300003", @"Manually dismiss the banner view");
  [self.autoDismissTimer invalidate];
  [self dismissViewWithAnimation:^(void) {
    [self dismissView:FIRInAppMessagingDismissTypeUserSwipe];
  }];
}

- (void)messageTapped:(UITapGestureRecognizer *)recognizer {
  [self.autoDismissTimer invalidate];
  [self dismissViewWithAnimation:^(void) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    FIRInAppMessagingAction *action =
        [[FIRInAppMessagingAction alloc] initWithActionText:nil
                                                  actionURL:self.bannerDisplayMessage.actionURL];
#pragma clang diagnostic pop
    [self followAction:action];
  }];
}

- (void)adjustBodyLabelViewHeight {
  // These lines make sure that we only change the height of the label view
  // to fit the content. Doing [self.bodyLabel sizeToFit] only could potentially
  // change the width as well.
  CGRect theFrame = self.bodyLabel.frame;
  [self.bodyLabel sizeToFit];
  theFrame.size.height = self.bodyLabel.frame.size.height;
  self.bodyLabel.frame = theFrame;
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  CGFloat bannerViewHeight = 0;

  [self adjustBodyLabelViewHeight];

  if (self.bannerDisplayMessage.imageData) {
    CGFloat imageBottom = CGRectGetMaxY(self.imageView.frame);
    CGFloat bodyBottom = CGRectGetMaxY(self.bodyLabel.frame);
    bannerViewHeight = MAX(imageBottom, bodyBottom);
  } else {
    bannerViewHeight = CGRectGetMaxY(self.bodyLabel.frame);
  }

  bannerViewHeight += 5;  // Add some padding margin on the bottom of the view

  CGFloat appWindowWidth = [self.view.window bounds].size.width;
  CGFloat bannerViewWidth = appWindowWidth;

  if (bannerViewWidth > kBannerViewMaxWidth) {
    bannerViewWidth = kBannerViewMaxWidth;
    self.view.layer.cornerRadius = 4;
  }

  CGRect viewRect =
      CGRectMake((appWindowWidth - bannerViewWidth) / 2, 0, bannerViewWidth, bannerViewHeight);
  self.view.frame = viewRect;

  if (self.hidingForAnimation) {
    // Move the banner to be just above the top of the window to hide it.
    self.view.center = CGPointMake(appWindowWidth / 2, -viewRect.size.height / 2);
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  CGRect rectInNormalState = self.view.frame;
  CGPoint normalCenterPoint =
      CGPointMake(rectInNormalState.origin.x + rectInNormalState.size.width / 2,
                  rectInNormalState.size.height / 2);

  self.hidingForAnimation = NO;
  [UIView animateWithDuration:kBannerViewAnimationDuration
                        delay:0
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     self.view.center = normalCenterPoint;
                   }
                   completion:nil];
}

- (void)setupAutoDismissTimer {
  NSTimeInterval remaining = kBannerAutoDimissTime - super.aggregateImpressionTimeInSeconds;

  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300004",
              @"Remaining banner auto dismiss time is %lf", remaining);

  // Set up the auto dismiss behavior.
  __weak id weakSelf = self;
  self.autoDismissTimer =
      [NSTimer scheduledTimerWithTimeInterval:remaining
                                       target:weakSelf
                                     selector:@selector(closeViewFromAutoDismiss)
                                     userInfo:nil
                                      repeats:NO];
}

// Handlers for app become active inactive so that we can better adjust our auto dismiss feature
- (void)appWillBecomeInactive:(NSNotification *)notification {
  [super appWillBecomeInactive:notification];
  [self.autoDismissTimer invalidate];
}

- (void)appDidBecomeActive:(NSNotification *)notification {
  [super appDidBecomeActive:notification];
  [self setupAutoDismissTimer];
}

- (void)dealloc {
  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300005",
              @"-[FIRIAMBannerViewController dealloc] triggered for %p", self);
  [self.autoDismissTimer invalidate];
}
@end

#endif  // TARGET_OS_IOS
