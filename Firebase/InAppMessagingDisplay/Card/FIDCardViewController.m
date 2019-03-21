//
//  FIDCardViewController.m
//  FirebaseInAppMessagingDisplay
//
//  Created by Chris Tibbs on 2/19/19.
//

#import "FIDCardViewController.h"
#import "FIRCore+InAppMessagingDisplay.h"

@interface FIDCardViewController ()

@property(nonatomic, readwrite) FIRInAppMessagingCardDisplay *cardDisplayMessage;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIButton *primaryActionButton;
@property (weak, nonatomic) IBOutlet UIButton *secondaryActionButton;
@property (weak, nonatomic) IBOutlet UITextView *bodyTextView;

@end

@implementation FIDCardViewController

+ (FIDCardViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:(FIRInAppMessagingCardDisplay *)cardMessage
                                displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate
                                    timeFetcher:(id<FIDTimeFetcher>)timeFetcher {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"FIRInAppMessageDisplayStoryboard"
                                                       bundle:resourceBundle];
  
  if (!storyboard) {
    FIRLogError(kFIRLoggerInAppMessagingDisplay, @"I-FID300001",
                @"Storyboard '"
                "FIRInAppMessageDisplayStoryboard' not found in bundle %@",
                resourceBundle);
    return nil;
  }
  FIDCardViewController *cardVC = (FIDCardViewController *)[storyboard
      instantiateViewControllerWithIdentifier:@"card-view-vc"];
  cardVC.displayDelegate = displayDelegate;
  cardVC.cardDisplayMessage = cardMessage;
  cardVC.timeFetcher = timeFetcher;
  
  return cardVC;
}

- (FIRInAppMessagingDisplayMessage *)inAppMessage {
  return self.cardDisplayMessage;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.bodyTextView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
  
  // make the background half transparent
  [self.view setBackgroundColor:[UIColor.grayColor colorWithAlphaComponent:0.5]];
  
  self.titleLabel.text = self.cardDisplayMessage.title;
  self.bodyTextView.text = self.cardDisplayMessage.body;

  [self.primaryActionButton setTitle:self.cardDisplayMessage.primaryActionButton.buttonText
                            forState:UIControlStateNormal];
  
  if (self.cardDisplayMessage.secondaryActionButton) {
    self.secondaryActionButton.hidden = NO;
    [self.secondaryActionButton setTitle:self.cardDisplayMessage.secondaryActionButton.buttonText
                                forState:UIControlStateNormal];
  }
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  
  if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ||
      self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
    NSData *imageData = self.cardDisplayMessage.landscapeImageData ? self.cardDisplayMessage.landscapeImageData.imageRawData : self.cardDisplayMessage.portraitImageData.imageRawData;
    self.imageView.image = [UIImage imageWithData:imageData];
  } else {
    self.imageView.image = [UIImage imageWithData:self.cardDisplayMessage.portraitImageData.imageRawData];
  }
  
  BOOL enableScrolling =
      self.bodyTextView.frame.size.height < self.bodyTextView.contentSize.height;
  self.bodyTextView.scrollEnabled = enableScrolling;
}

@end
