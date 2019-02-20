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
@property (weak, nonatomic) IBOutlet UILabel *bodyLabel;
@property (weak, nonatomic) IBOutlet UIButton *primaryActionButton;
@property (weak, nonatomic) IBOutlet UIButton *secondaryActionButton;

@end

@implementation FIDCardViewController

+ (FIDCardViewController *)
    instantiateViewControllerWithResourceBundle:(NSBundle *)resourceBundle
                                 displayMessage:(FIRInAppMessagingCardDisplay *)cardMessage
                                displayDelegate:(id<FIRInAppMessagingDisplayDelegate>)displayDelegate
                                    timeFetcher:(id<FIDTimeFetcher>)timeFetcher {
  UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"FIRInAppMessageDisplaySDtoryboard"
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
  
  self.titleLabel.text = self.cardDisplayMessage.title;
  self.bodyLabel.text = self.cardDisplayMessage.body;
  
  self.imageView.image = [UIImage imageWithData:self.cardDisplayMessage.portraitImageData.imageRawData];
  
  [self.primaryActionButton setTitle:self.cardDisplayMessage.primaryActionButton.buttonText
                            forState:UIControlStateNormal];
  
  if (self.cardDisplayMessage.secondaryActionButton) {
    [self.secondaryActionButton setTitle:self.cardDisplayMessage.secondaryActionButton.buttonText
                                forState:UIControlStateNormal];
  }
}

@end
