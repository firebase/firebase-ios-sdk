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

#import <UIKit/UIKit.h>

#import "FirebaseInAppMessaging/Sources/DefaultUI/FIRCore+InAppMessagingDisplay.h"
#import "FirebaseInAppMessaging/Sources/DefaultUI/Modal/FIRIAMModalViewController.h"

@interface FIRIAMModalViewController ()

@property(nonatomic, readwrite) FIRInAppMessagingModalDisplay *modalDisplayMessage;

@property(weak, nonatomic) IBOutlet UIImageView *imageView;
@property(weak, nonatomic) IBOutlet UILabel *titleLabel;
@property(weak, nonatomic) IBOutlet UIButton *actionButton;

@property(weak, nonatomic) IBOutlet UIView *messageCardView;
@property(weak, nonatomic) IBOutlet UITextView *bodyTextView;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;

// this is only needed for removing the layout errors in interface builder. At runtime
// we determine the height via its content size. So disable this at runtime.
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *fixedMessageCardHeightConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *messageCardHeightMaxInTabletCase;

@property(weak, nonatomic) IBOutlet NSLayoutConstraint *maxActionButtonHeight;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *bodyTextViewHeightConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *buttonTopToBodyBottomConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageActualHeightConstraint;

// constraints manipulated further in portrait mode
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *titleLabelHeightConstraint;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *buttonBottomToContainerBottomInPortraitMode;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageTopToTitleBottomInPortraitMode;

// constraints manipulated further in landscape mode
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageWidthInLandscapeMode;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *titleTopToCardViewTop;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *cardLeadingMarginInLandscapeMode;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *maxCardHeightInLandscapeMode;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *imageTopToCardTopInLandscapeMode;
@property(weak, nonatomic) IBOutlet NSLayoutConstraint *bodyTopToTitleBottomInLandScapeMode;
@end

static CGFloat VerticalSpacingBetweenTitleAndBody = 24;
static CGFloat VerticalSpacingBetweenBodyAndActionButton = 24;

// the padding between the content and view card's top and bottom edges
static CGFloat TopBottomPaddingAroundContent = 24;
// the minimal padding size between msg card and app window's top and bottom
static CGFloat TopBottomPaddingAroundMsgCard = 30;

// the horizontal spacing between image column and text/button column in landscape mode
static CGFloat LandScapePaddingBetweenImageAndTextColumn = 24;

@implementation FIRIAMModalViewController

+ (FIRIAMModalViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:(FIRInAppMessagingModalDisplay *)modalMessage
                                displayDelegate:
                                    (id<FIRInAppMessagingDisplayDelegate>)displayDelegate
                                    timeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"FIRInAppMessageDisplayStoryboard"
                                                       bundle:resourceBundle];

  if (storyboard == nil) {
    FIRLogError(kFIRLoggerInAppMessagingDisplay, @"I-FID300001",
                @"Storyboard '"
                 "FIRInAppMessageDisplayStoryboard' not found in bundle %@",
                resourceBundle);
    return nil;
  }
  FIRIAMModalViewController *modalVC = (FIRIAMModalViewController *)[storyboard
      instantiateViewControllerWithIdentifier:@"modal-view-vc"];
  modalVC.displayDelegate = displayDelegate;
  modalVC.modalDisplayMessage = modalMessage;
  modalVC.timeFetcher = timeFetcher;

  return modalVC;
}

- (FIRInAppMessagingDisplayMessage *)inAppMessage {
  return self.modalDisplayMessage;
}

- (IBAction)closeButtonClicked:(id)sender {
  [self dismissView:FIRInAppMessagingDismissTypeUserTapClose];
}

- (IBAction)actionButtonTapped:(id)sender {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  FIRInAppMessagingAction *action = [[FIRInAppMessagingAction alloc]
      initWithActionText:self.modalDisplayMessage.actionButton.buttonText
               actionURL:self.modalDisplayMessage.actionURL];
#pragma clang diagnostic pop
  [self followAction:action];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // make the background half transparent
  [self.view setBackgroundColor:[UIColor.grayColor colorWithAlphaComponent:0.5]];
  self.messageCardView.layer.cornerRadius = 4;

  // populating values for display elements

  self.titleLabel.text = self.modalDisplayMessage.title;
  self.bodyTextView.text = self.modalDisplayMessage.bodyText;

  if (self.modalDisplayMessage.imageData) {
    [self.imageView
        setImage:[UIImage imageWithData:self.modalDisplayMessage.imageData.imageRawData]];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
  }

  self.messageCardView.backgroundColor = self.modalDisplayMessage.displayBackgroundColor;

  self.titleLabel.textColor = self.modalDisplayMessage.textColor;
  self.bodyTextView.textColor = self.modalDisplayMessage.textColor;
  self.bodyTextView.selectable = NO;

  if (self.modalDisplayMessage.actionButton.buttonText.length != 0) {
    [self.actionButton setTitle:self.modalDisplayMessage.actionButton.buttonText
                       forState:UIControlStateNormal];
    self.actionButton.backgroundColor = self.modalDisplayMessage.actionButton.buttonBackgroundColor;
    [self.actionButton setTitleColor:self.modalDisplayMessage.actionButton.buttonTextColor
                            forState:UIControlStateNormal];
    self.actionButton.layer.cornerRadius = 4;

    if (self.modalDisplayMessage.bodyText.length == 0) {
      self.buttonTopToBodyBottomConstraint.constant = 0;
    }
  } else {
    // either action button text is empty or nil

    // hide the action button and reclaim the space below the buttom
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300002",
                @"Modal view to be rendered without action button");
    self.maxActionButtonHeight.constant = 0;
    self.actionButton.clipsToBounds = YES;
    self.buttonTopToBodyBottomConstraint.constant = 0;
  }

  [self.view addConstraint:self.imageActualHeightConstraint];
  self.imageActualHeightConstraint.active = YES;
  self.fixedMessageCardHeightConstraint.active = NO;
}

// for text display UIview, which could be a UILabel or UITextView, decide the fit height under a
// given display width
- (CGFloat)determineTextAreaViewFitHeightForView:(UIView *)textView
                                       withWidth:(CGFloat)displayWidth {
  CGSize displaySize = CGSizeMake(displayWidth, FLT_MAX);
  return [textView sizeThatFits:displaySize].height;
}

// In both landscape or portrait mode, the title, body & button are aligned vertically and they form
// together have an impact on the height for that column. Many times, we need to calculate a
// suitable heights for them to help decide the layout. The height calculation is influced by quite
// a few factors: the text lenght of title and body, the presence/absense of body & button and
// available card/window sizes. So these are wrapped within
// estimateTextButtomColumnHeightWithDisplayWidth which produce a TitleBodyButtonHeightInfo struct
// to give the estimates of the heights of different elements.
struct TitleBodyButtonHeightInfo {
  CGFloat titleHeight;
  CGFloat bodyHeight;

  // this is the total height of title plus body plus the button. Notice that button or body are
  // optional and the result totaColumnlHeight factor in these cases correctly
  CGFloat totaColumnlHeight;
};

- (struct TitleBodyButtonHeightInfo)estimateTextBtnColumnHeightWithDisplayWidth:
                                        (CGFloat)displayWidth
                                                            withMaxColumnHeight:(CGFloat)maxHeight {
  struct TitleBodyButtonHeightInfo resultHeightInfo;

  CGFloat titleFitHeight = [self determineTextAreaViewFitHeightForView:self.titleLabel
                                                             withWidth:displayWidth];
  CGFloat bodyFitHeight = self.modalDisplayMessage.bodyText.length == 0
                              ? 0
                              : [self determineTextAreaViewFitHeightForView:self.bodyTextView
                                                                  withWidth:displayWidth];

  CGFloat bodyFitHeightWithPadding = self.modalDisplayMessage.bodyText.length == 0
                                         ? 0
                                         : bodyFitHeight + VerticalSpacingBetweenTitleAndBody;

  CGFloat buttonHeight =
      self.modalDisplayMessage.actionButton == nil
          ? 0
          : self.actionButton.frame.size.height + VerticalSpacingBetweenBodyAndActionButton;

  // we keep the spacing even if body or button is absent.
  CGFloat fitColumnHeight = titleFitHeight + bodyFitHeightWithPadding + buttonHeight;

  if (fitColumnHeight < maxHeight) {
    // every element get space that can fit the content
    resultHeightInfo.bodyHeight = bodyFitHeight;
    resultHeightInfo.titleHeight = titleFitHeight;
    resultHeightInfo.totaColumnlHeight = fitColumnHeight;
  } else {
    // need to restrict heights of certain elements
    resultHeightInfo.totaColumnlHeight = maxHeight;
    if (self.modalDisplayMessage.bodyText.length == 0) {
      // no message body, title will try to expand to take all the available height
      resultHeightInfo.bodyHeight = 0;
      if (self.modalDisplayMessage.actionButton == nil) {
        resultHeightInfo.titleHeight = maxHeight;
      } else {
        // button height, if not 0, already accommodates the space above it
        resultHeightInfo.titleHeight = maxHeight - buttonHeight;
      }
    } else {
      // first give title up to 40% of available height
      resultHeightInfo.titleHeight = fmin(titleFitHeight, maxHeight * 2 / 5);

      CGFloat availableBodyHeight = 0;
      if (self.modalDisplayMessage.actionButton == nil) {
        availableBodyHeight =
            maxHeight - resultHeightInfo.titleHeight - VerticalSpacingBetweenTitleAndBody;
      } else {
        // body takes the rest minus button space
        availableBodyHeight = maxHeight - resultHeightInfo.titleHeight - buttonHeight -
                              VerticalSpacingBetweenTitleAndBody;
      }

      if (availableBodyHeight > bodyFitHeight) {
        resultHeightInfo.bodyHeight = bodyFitHeight;
        // give some back to title height since body does not use up all the allocation
        resultHeightInfo.titleHeight += (availableBodyHeight - bodyFitHeight);
      } else {
        resultHeightInfo.bodyHeight = availableBodyHeight;
      }
    }
  }

  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300003",
              @"In heights calculation (max-height = %lf, width = %lf), title heights is %lf, "
               "body height is %lf, button height is %lf, total column heights are %lf",
              maxHeight, displayWidth, resultHeightInfo.titleHeight, resultHeightInfo.bodyHeight,
              buttonHeight, resultHeightInfo.totaColumnlHeight);

  return resultHeightInfo;
}

// the following two layoutFineTunexx methods make additional adjustments for the view layout
// in portrait and landscape mode respectively. They are supposed to be triggered from
// viewDidLayoutSubviews since certain dimension sizes are only available there
- (void)layoutFineTuneInPortraitMode {
  // for tablet case, since we use a fixed card height, the reference would be just the card height
  // for non-tablet case, we want to use a dynamic height , so the reference would be the window
  // height
  CGFloat heightCalcReference = 0;
  if (self.messageCardHeightMaxInTabletCase.active) {
    heightCalcReference =
        self.messageCardView.frame.size.height - TopBottomPaddingAroundContent * 2;
  } else {
    heightCalcReference = self.view.window.frame.size.height - TopBottomPaddingAroundContent * 2 -
                          TopBottomPaddingAroundMsgCard * 2;

    // Factor in space for the top notch on iPhone X*.
#if defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
      heightCalcReference -= self.view.safeAreaInsets.top;
    }
#endif  // defined(__IPHONE_11_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
  }

  FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300004",
              @"The height calc reference is %lf "
               "with frame height as %lf",
              heightCalcReference, self.view.window.frame.size.height);

  // this makes sure titleLable gets correct width to be ready for later's height estimate for the
  // text & button column
  [self.messageCardView layoutIfNeeded];

  // we reserve approximately 1/3 vertical space for image
  CGFloat textBtnTotalAvailableHeight =
      self.modalDisplayMessage.imageData ? heightCalcReference * 2 / 3 : heightCalcReference;

  struct TitleBodyButtonHeightInfo heights =
      [self estimateTextBtnColumnHeightWithDisplayWidth:self.titleLabel.frame.size.width
                                    withMaxColumnHeight:textBtnTotalAvailableHeight];

  self.titleLabelHeightConstraint.constant = heights.titleHeight;
  self.bodyTextViewHeightConstraint.constant = heights.bodyHeight;

  if (self.modalDisplayMessage.imageData) {
    UIImage *image = [UIImage imageWithData:self.modalDisplayMessage.imageData.imageRawData];
    CGSize imageAvailableSpace = CGSizeMake(self.titleLabel.frame.size.width,
                                            heightCalcReference - heights.totaColumnlHeight -
                                                self.imageTopToTitleBottomInPortraitMode.constant);

    CGSize imageDisplaySize = [self fitImageInRegionSize:imageAvailableSpace
                                           withImageSize:image.size];

    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300005",
                @"Given actual image size %@ and available image display size %@, the actual"
                 "image display size is %@",
                NSStringFromCGSize(image.size), NSStringFromCGSize(imageAvailableSpace),
                NSStringFromCGSize(imageDisplaySize));

    // for portrait mode, no need to change image width since no content is shown side to
    // the image
    self.imageActualHeightConstraint.constant = imageDisplaySize.height;
  } else {
    // no image case
    self.imageActualHeightConstraint.constant = 0;
    self.imageTopToTitleBottomInPortraitMode.constant = 0;
  }
}

- (CGSize)fitImageInRegionSize:(CGSize)regionSize withImageSize:(CGSize)imageSize {
  if (imageSize.height <= regionSize.height && imageSize.width <= regionSize.width) {
    return imageSize;  // image can be fully rendered at its original dimension
  } else {
    CGFloat regionRatio = regionSize.width / regionSize.height;
    CGFloat imageRaio = imageSize.width / imageSize.height;

    if (regionRatio < imageRaio) {
      // bound on the width dimension
      return CGSizeMake(regionSize.width, regionSize.width / imageRaio);
    } else {
      return CGSizeMake(regionSize.height * imageRaio, regionSize.height);
    }
  }
}

// for devices of 4 inches or below (iphone se, iphone 5/5s and iphone 4s), reduce
// the padding sizes between elements in the text/button column for landscape mode
- (void)applySmallerSpacingForInLandscapeMode {
  if (self.modalDisplayMessage.bodyText.length != 0) {
    VerticalSpacingBetweenTitleAndBody = self.bodyTopToTitleBottomInLandScapeMode.constant = 12;
  }

  if (self.modalDisplayMessage.actionButton != nil &&
      self.modalDisplayMessage.bodyText.length != 0) {
    VerticalSpacingBetweenBodyAndActionButton = self.buttonTopToBodyBottomConstraint.constant = 12;
  }
}

- (void)layoutFineTuneInLandscapeMode {
  // smaller spacing threshold is applied for screens equal or larger than 4.7 inches
  if (self.view.window.frame.size.height <= 321) {
    [self applySmallerSpacingForInLandscapeMode];
  }

  if (self.modalDisplayMessage.imageData) {
    UIImage *image = [UIImage imageWithData:self.modalDisplayMessage.imageData.imageRawData];

    CGFloat maxImageHeight = self.view.window.frame.size.height -
                             TopBottomPaddingAroundContent * 2 - TopBottomPaddingAroundMsgCard * 2;
    CGFloat maxImageWidth = self.messageCardView.frame.size.width * 2 / 5;
    CGSize imageDisplaySize = [self fitImageInRegionSize:CGSizeMake(maxImageWidth, maxImageHeight)
                                           withImageSize:image.size];

    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300008",
                @"In landscape mode, image fit size is %@", NSStringFromCGSize(imageDisplaySize));

    // resize image per imageSize
    self.imageWidthInLandscapeMode.constant = imageDisplaySize.width;
    self.imageActualHeightConstraint.constant = imageDisplaySize.height;

    // now we can estimate the new card width given the desired image size

    // this assumes we use half of the window width for diplaying the text/button column
    CGFloat cardFitWidth = imageDisplaySize.width + self.view.window.frame.size.width / 2 +
                           LandScapePaddingBetweenImageAndTextColumn;

    self.cardLeadingMarginInLandscapeMode.constant =
        fmax(15, (self.view.window.frame.size.width - cardFitWidth) / 2);
  } else {
    self.imageWidthInLandscapeMode.constant = 0;
    self.imageActualHeightConstraint.constant = 0;

    // card would be of 3/5 width of the screen in landscape
    self.cardLeadingMarginInLandscapeMode.constant = self.view.window.frame.size.width / 5;
  }

  // this makes sure titleLable gets correct width to be ready for later's height estimate for the
  // text & button column
  [self.messageCardView layoutIfNeeded];

  struct TitleBodyButtonHeightInfo heights =
      [self estimateTextBtnColumnHeightWithDisplayWidth:self.titleLabel.frame.size.width
                                    withMaxColumnHeight:self.view.frame.size.height -
                                                        TopBottomPaddingAroundContent * 2 -
                                                        TopBottomPaddingAroundMsgCard * 2];

  self.titleLabelHeightConstraint.constant = heights.titleHeight;
  self.bodyTextViewHeightConstraint.constant = heights.bodyHeight;

  // Adjust the height of the card
  // are we bound by the text/button column height or image height ?
  CGFloat cardHeight = fmax(self.imageActualHeightConstraint.constant, heights.totaColumnlHeight) +
                       TopBottomPaddingAroundContent * 2;
  self.maxCardHeightInLandscapeMode.constant = cardHeight;

  // with the new card height, align the image and the text/btn column to center vertically
  self.imageTopToCardTopInLandscapeMode.constant =
      (cardHeight - self.imageActualHeightConstraint.constant) / 2;
  self.titleTopToCardViewTop.constant = (cardHeight - heights.totaColumnlHeight) / 2;
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ||
      self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300010",
                @"Modal view rendered in landscape mode");
    [self layoutFineTuneInLandscapeMode];
  } else {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300009",
                @"Modal view rendered in portrait mode");
    [self layoutFineTuneInPortraitMode];
  }

  // always scroll to the top in case the body area is scrollable
  [self.bodyTextView setContentOffset:CGPointZero];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  // close any potential keyboard, which would conflict with the modal in-app messagine view
  [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder)
                                             to:nil
                                           from:nil
                                       forEvent:nil];

  if (self.modalDisplayMessage.campaignInfo.renderAsTestMessage) {
    FIRLogDebug(kFIRLoggerInAppMessagingDisplay, @"I-FID300011",
                @"Flushing the close button since this is a test message.");
    [self flashCloseButton:self.closeButton];
  }
}

- (void)flashCloseButton:(UIButton *)closeButton {
  closeButton.alpha = 1.0f;
  [UIView animateWithDuration:2.0
                        delay:0.0
                      options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionRepeat |
                              UIViewAnimationOptionAutoreverse |
                              UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     closeButton.alpha = 0.1f;
                   }
                   completion:^(BOOL finished){
                       // Do nothing
                   }];
}
@end

#endif  // TARGET_OS_IOS
