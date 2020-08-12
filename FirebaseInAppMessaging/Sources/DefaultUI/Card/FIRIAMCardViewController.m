/*
 * Copyright 2019 Google
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

#import "FirebaseInAppMessaging/Sources/DefaultUI/Card/FIRIAMCardViewController.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRCore+InAppMessagingDisplay.h"

@interface FIRIAMCardViewController ()

@property(nonatomic, readwrite) FIRInAppMessagingCardDisplay *cardDisplayMessage;

@property(weak, nonatomic) IBOutlet UIView *cardView;
@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property(weak, nonatomic) IBOutlet UILabel *titleLabel;
@property(weak, nonatomic) IBOutlet UIButton *primaryActionButton;
@property(weak, nonatomic) IBOutlet UIButton *secondaryActionButton;
@property(weak, nonatomic) IBOutlet UITextView *bodyTextView;
@property(weak, nonatomic) IBOutlet UIScrollView *textAreaScrollView;

@end

@implementation FIRIAMCardViewController

+ (FIRIAMCardViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:(FIRInAppMessagingCardDisplay *)cardMessage
                                displayDelegate:
                                    (id<FIRInAppMessagingDisplayDelegate>)displayDelegate
                                    timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"FIRInAppMessageDisplayStoryboard"
                                                       bundle:resourceBundle];

  if (!storyboard) {
    FIRLogError(kFIRLoggerInAppMessagingDisplay, @"I-FID300001",
                @"Storyboard '"
                 "FIRInAppMessageDisplayStoryboard' not found in bundle %@",
                resourceBundle);
    return nil;
  }
  FIRIAMCardViewController *cardVC = (FIRIAMCardViewController *)[storyboard
      instantiateViewControllerWithIdentifier:@"card-view-vc"];
  cardVC.displayDelegate = displayDelegate;
  cardVC.cardDisplayMessage = cardMessage;
  cardVC.timeFetcher = timeFetcher;

  return cardVC;
}

- (IBAction)primaryActionButtonTapped:(id)sender {
  if (self.cardDisplayMessage.primaryActionURL) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    FIRInAppMessagingAction *primaryAction = [[FIRInAppMessagingAction alloc]
        initWithActionText:self.cardDisplayMessage.primaryActionButton.buttonText
                 actionURL:self.cardDisplayMessage.primaryActionURL];
#pragma clang diagnostic pop
    [self followAction:primaryAction];
  } else {
    [self dismissView:FIRInAppMessagingDismissTypeUserTapClose];
  }
}

- (IBAction)secondaryActionButtonTapped:(id)sender {
  if (self.cardDisplayMessage.secondaryActionURL) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    FIRInAppMessagingAction *secondaryAction = [[FIRInAppMessagingAction alloc]
        initWithActionText:self.cardDisplayMessage.secondaryActionButton.buttonText
                 actionURL:self.cardDisplayMessage.secondaryActionURL];
#pragma clang diagnostic pop
    [self followAction:secondaryAction];
  } else {
    [self dismissView:FIRInAppMessagingDismissTypeUserTapClose];
  }
}

- (FIRInAppMessagingDisplayMessage *)inAppMessage {
  return self.cardDisplayMessage;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.cardView.backgroundColor = self.cardDisplayMessage.displayBackgroundColor;
  self.cardView.layer.cornerRadius = 4;

  self.bodyTextView.contentInset = UIEdgeInsetsZero;
  self.bodyTextView.textContainer.lineFragmentPadding = 0;

  // Make the background half transparent.
  [self.view setBackgroundColor:[UIColor.grayColor colorWithAlphaComponent:0.5]];

  self.titleLabel.text = self.cardDisplayMessage.title;
  self.titleLabel.textColor = self.cardDisplayMessage.textColor;

  self.bodyTextView.text = self.cardDisplayMessage.body;
  self.bodyTextView.textColor = self.cardDisplayMessage.textColor;

  [self.primaryActionButton setTitle:self.cardDisplayMessage.primaryActionButton.buttonText
                            forState:UIControlStateNormal];
  [self.primaryActionButton
      setTitleColor:self.cardDisplayMessage.primaryActionButton.buttonTextColor
           forState:UIControlStateNormal];

  if (self.cardDisplayMessage.secondaryActionButton) {
    self.secondaryActionButton.hidden = NO;
    [self.secondaryActionButton setTitle:self.cardDisplayMessage.secondaryActionButton.buttonText
                                forState:UIControlStateNormal];
    [self.secondaryActionButton
        setTitleColor:self.cardDisplayMessage.secondaryActionButton.buttonTextColor
             forState:UIControlStateNormal];
  }
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  // The landscape image is optional and only displayed if:
  // 1. Landscape image exists.
  // 2. The iOS device is in "landscape" mode (regular width or compact height).
  if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ||
      self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
    NSData *imageData = self.cardDisplayMessage.landscapeImageData
                            ? self.cardDisplayMessage.landscapeImageData.imageRawData
                            : self.cardDisplayMessage.portraitImageData.imageRawData;
    self.imageView.image = [UIImage imageWithData:imageData];
  } else {
    self.imageView.image =
        [UIImage imageWithData:self.cardDisplayMessage.portraitImageData.imageRawData];
  }

  self.textAreaScrollView.contentSize = self.bodyTextView.frame.size;
  [self.textAreaScrollView setContentOffset:CGPointZero];
}

@end

#endif  // TARGET_OS_IOS
