/*
 * Copyright 2017 Google
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

#import "AppDelegate.h"

#import "AutoDisplayFlowViewController.h"
#import "AutoDisplayMessagesTableVC.h"

#import <FirebaseInAppMessaging/FIRIAMDisplayCheckOnAppForegroundFlow.h>
#import <FirebaseInAppMessaging/FIRIAMMessageClientCache.h>
#import <FirebaseInAppMessaging/FIRIAMMessageContentDataWithImageURL.h>
#import <FirebaseInAppMessaging/FIRIAMMessageDefinition.h>

#import <FirebaseInAppMessaging/FIRIAMActivityLogger.h>
#import <FirebaseInAppMessaging/FIRIAMDisplayCheckOnAnalyticEventsFlow.h>
#import <FirebaseInAppMessaging/FIRIAMFetchOnAppForegroundFlow.h>
#import <FirebaseInAppMessaging/FIRIAMMessageClientCache.h>
#import <FirebaseInAppMessaging/FIRIAMMsgFetcherUsingRestful.h>

#import <FirebaseInAppMessaging/FIRIAMRuntimeManager.h>
#import "FIRInAppMessaging.h"

#import <FirebaseAnalytics/FIRAnalytics.h>

@interface AutoDisplayFlowViewController ()
@property(weak, nonatomic) IBOutlet UISwitch *autoDisplayFlowSwitch;

@property(nonatomic, weak) AutoDisplayMessagesTableVC *messageTableVC;
@property(weak, nonatomic) IBOutlet UITextField *autoDisplayIntervalText;
@property(weak, nonatomic) IBOutlet UITextField *autoFetchIntervalText;
@property(weak, nonatomic) IBOutlet UITextField *eventNameText;
@property(weak, nonatomic) IBOutlet UITextField *programmaticTriggerNameText;
@property(nonatomic) FIRIAMRuntimeManager *sdkRuntime;
@property(weak, nonatomic) IBOutlet UIButton *disableEnableSDKBtn;
@property(weak, nonatomic) IBOutlet UIButton *changeDataCollectionBtn;
@end

@implementation AutoDisplayFlowViewController
- (IBAction)clearClientStorage:(id)sender {
  [self.sdkRuntime.fetchResultStorage
      saveResponseDictionary:@{}
              withCompletion:^(BOOL success) {
                [self.sdkRuntime.messageCache
                    loadMessageDataFromServerFetchStorage:self.sdkRuntime.fetchResultStorage
                                           withCompletion:^(BOOL success) {
                                             NSLog(@"load from storage result is %d", success);
                                           }];
              }];
}
- (IBAction)disableEnableClicked:(id)sender {
  FIRInAppMessaging *sdk = [FIRInAppMessaging inAppMessaging];
  sdk.messageDisplaySuppressed = !sdk.messageDisplaySuppressed;
  [self setupDisableEnableButtonLabel];
}

- (void)setupDisableEnableButtonLabel {
  FIRInAppMessaging *sdk = [FIRInAppMessaging inAppMessaging];
  NSString *title = sdk.messageDisplaySuppressed ? @"allow rendering" : @"disallow rendering";
  [self.disableEnableSDKBtn setTitle:title forState:UIControlStateNormal];
}

- (IBAction)triggerAnalyticEventTapped:(id)sender {
  NSLog(@"triggering an analytics event: %@", self.eventNameText.text);

  [FIRAnalytics logEventWithName:self.eventNameText.text parameters:@{}];
}

- (IBAction)triggerProgrammaticallyTapped:(id)sender {
  NSLog(@"Trigger event %@ programmatically", self.eventNameText.text);

  [[FIRInAppMessaging inAppMessaging] triggerEvent:self.programmaticTriggerNameText.text];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
  UITouch *touch = [touches anyObject];
  if (![touch.view isMemberOfClass:[UITextField class]]) {
    [touch.view endEditing:YES];
  }
}
- (IBAction)changeAutoDataCollection:(id)sender {
  FIRInAppMessaging *sdk = [FIRInAppMessaging inAppMessaging];
  sdk.automaticDataCollectionEnabled = !sdk.automaticDataCollectionEnabled;
  [self setupChangeAutoDataCollectionButtonLabel];
}

- (void)setupChangeAutoDataCollectionButtonLabel {
  FIRInAppMessaging *sdk = [FIRInAppMessaging inAppMessaging];
  NSString *title = sdk.automaticDataCollectionEnabled ? @"disable data-col" : @"enable data-col";
  [self.changeDataCollectionBtn setTitle:title forState:UIControlStateNormal];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  double delayInSeconds = 2.0;
  dispatch_time_t setupTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
  dispatch_after(setupTime, dispatch_get_main_queue(), ^(void) {
    // code to be executed on the main queue after delay
    self.sdkRuntime = [FIRIAMRuntimeManager getSDKRuntimeInstance];
    self.messageTableVC.messageCache = self.sdkRuntime.messageCache;
    [self.sdkRuntime.messageCache setDataObserver:self.messageTableVC];
    [self.messageTableVC.tableView reloadData];
    [self setupDisableEnableButtonLabel];
    [self setupChangeAutoDataCollectionButtonLabel];
  });

  NSLog(@"done with set data observer");

  self.autoFetchIntervalText.text = [[NSNumber
      numberWithDouble:self.sdkRuntime.currentSetting.fetchMinIntervalInMinutes * 60] stringValue];
  self.autoDisplayIntervalText.text =
      [[NSNumber numberWithDouble:self.sdkRuntime.currentSetting.appFGRenderMinIntervalInMinutes *
                                  60] stringValue];
}

- (IBAction)dumpImpressionsToConsole:(id)sender {
  NSArray *impressions = [self.sdkRuntime.bookKeeper getImpressions];
  NSLog(@"impressions are %@", [impressions componentsJoinedByString:@","]);
}
- (IBAction)clearImpressionRecord:(id)sender {
  [self.sdkRuntime.bookKeeper cleanupImpressions];
}

- (IBAction)changeAutoFetchDisplaySettings:(id)sender {
  FIRIAMSDKSettings *setting = self.sdkRuntime.currentSetting;

  // set fetch interval
  double intervalValue = self.autoFetchIntervalText.text.doubleValue / 60;
  if (intervalValue < 0.0001) {
    intervalValue = 1;
    self.autoFetchIntervalText.text = [[NSNumber numberWithDouble:intervalValue * 60] stringValue];
  }
  setting.fetchMinIntervalInMinutes = intervalValue;

  // set app foreground display interval
  double displayIntervalValue = self.autoDisplayIntervalText.text.doubleValue / 60;

  if (displayIntervalValue < 0.0001) {
    displayIntervalValue = 1;
    self.autoDisplayIntervalText.text =
        [[NSNumber numberWithDouble:displayIntervalValue * 60] stringValue];
  }
  setting.appFGRenderMinIntervalInMinutes = displayIntervalValue;

  [self.sdkRuntime startRuntimeWithSDKSettings:setting];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Navigation
// In a storyboard-based application, you will often want to do a little preparation before
// navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  // Get the new view controller using [segue destinationViewController].
  // Pass the selected object to the new view controller.

  if ([segue.identifier isEqualToString:@"message-table-segue"]) {
    self.messageTableVC = (AutoDisplayMessagesTableVC *)[segue destinationViewController];
  }
}
@end
