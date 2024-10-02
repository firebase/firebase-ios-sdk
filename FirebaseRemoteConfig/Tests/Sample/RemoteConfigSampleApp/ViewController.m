// Copyright 2019 Google
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

#import "ViewController.h"

#import <FirebaseAnalytics/FirebaseAnalytics.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseInstallations/FirebaseInstallations.h>
#import <FirebaseRemoteConfig/FirebaseRemoteConfig.h>
#import "../../../Sources/Private/FIRRemoteConfig_Private.h"
#import "FRCLog.h"
@import FirebaseRemoteConfigInterop;

static NSString *const FIRPerfNamespace = @"fireperf";
static NSString *const FIRDefaultFIRAppName = @"__FIRAPP_DEFAULT";
static NSString *const FIRSecondFIRAppName = @"secondFIRApp";

@interface FIRRemoteConfig (Sample)
+ (FIRRemoteConfig *)remoteConfigWithFIRNamespace:(NSString *)remoteConfigNamespace
                                              app:(FIRApp *)app;
@end

@interface ViewController ()
@property(nonatomic, strong) IBOutlet UIButton *fetchButton;
@property(nonatomic, strong) IBOutlet UIButton *applyButton;
@property(nonatomic, strong) IBOutlet UIButton *refreshButton;
@property(nonatomic, strong) IBOutlet UIButton *clearLogsButton;
@property(nonatomic, strong) IBOutlet UITextView *mainTextView;
/// Key of custom variable to be added by user.
@property(nonatomic, weak) IBOutlet UITextField *keyLabel;
/// Value of custom variable to be added by user.
@property(nonatomic, weak) IBOutlet UITextField *valueLabel;
/// Expiration in seconds to be set by user.
@property(nonatomic, weak) IBOutlet UITextField *expirationLabel;
/// Config Defaults.
@property(nonatomic, strong) NSMutableDictionary *configDefaults;
/// developer mode switch.
@property(strong, nonatomic) IBOutlet UISwitch *developerModeEnabled;
/// Current selected namespace.
@property(nonatomic, copy) NSString *currentNamespace;
/// Current selected FIRApp instance name.
@property(nonatomic, copy) NSString *FIRAppName;
/// Selected namespace picker control view.
@property(nonatomic, strong) IBOutlet UIPickerView *namespacePicker;
/// Selected app picker control view.
@property(nonatomic, strong) IBOutlet UIPickerView *appPicker;
/// Array of prepopulated namespaces supported by this app.
@property(nonatomic, strong) NSArray<NSString *> *namespacePickerData;
/// Array of prepopulated FIRApp names supported by this app.
@property(nonatomic, strong) NSArray<NSString *> *appPickerData;
/// Array of Remote Config instances.
@property(nonatomic, strong) NSMutableDictionary *RCInstances;
@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [[FRCLog sharedInstance] setLogView:self.mainTextView];
  [[FRCLog sharedInstance] logToConsole:@"Viewcontroller loaded"];
  [[FRCLog sharedInstance] logToConsole:[[NSBundle mainBundle] bundleIdentifier]];

  // Setup UI
  self.expirationLabel.text = [NSString stringWithFormat:@"0"];
  self.configDefaults = [[NSMutableDictionary alloc] init];
  self.keyLabel.delegate = self;
  self.valueLabel.delegate = self;
  self.expirationLabel.delegate = self;
  self.mainTextView.editable = NO;

  // TODO(mandard): Add support for deleting and adding namespaces in the app.
  self.namespacePickerData =
      [[NSArray alloc] initWithObjects:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform,
                                       FIRPerfNamespace, nil];
  self.appPickerData =
      [[NSArray alloc] initWithObjects:FIRDefaultFIRAppName, FIRSecondFIRAppName, nil];
  self.RCInstances = [[NSMutableDictionary alloc] init];
  for (NSString *namespaceString in self.namespacePickerData) {
    for (NSString *appString in self.appPickerData) {
      // Check for the default instance.
      if (!self.RCInstances[namespaceString]) {
        self.RCInstances[namespaceString] = [[NSMutableDictionary alloc] init];
      }
      if ([namespaceString
              isEqualToString:FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform] &&
          [appString isEqualToString:FIRDefaultFIRAppName]) {
        self.RCInstances[namespaceString][appString] = [FIRRemoteConfig remoteConfig];
      } else {
        FIRApp *firebaseApp = ([appString isEqualToString:FIRDefaultFIRAppName])
                                  ? [FIRApp defaultApp]
                                  : [FIRApp appNamed:appString];
        self.RCInstances[namespaceString][appString] =
            [FIRRemoteConfig remoteConfigWithFIRNamespace:namespaceString app:firebaseApp];
      }
      FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
      settings.fetchTimeout = 300;
      settings.minimumFetchInterval = 300;
      ((FIRRemoteConfig *)(self.RCInstances[namespaceString][appString])).configSettings = settings;
    }
  }

  /// UI popup for Realtime that shows if realtime_test_key was included in update.
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Alert"
                       message:@"The value for realtime_test_key has been updated!"
                preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action){
                                                        }];
  [alert addAction:defaultAction];

  // Add realtime listener for firebase namespace
  [self.RCInstances[FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform][FIRDefaultFIRAppName]
      addOnConfigUpdateListener:^(FIRRemoteConfigUpdate *_Nullable update,
                                  NSError *_Nullable error) {
        if (error != nil) {
          [[FRCLog sharedInstance]
              logToConsole:[NSString
                               stringWithFormat:@"Realtime Error: %@", error.localizedDescription]];
        } else {
          [[FRCLog sharedInstance] logToConsole:[NSString stringWithFormat:@"Config updated!"]];
          if (update != nil) {
            /// UI popup that lets user know that fetch included realtime_test_key in updatedKeys.
            if ([[update updatedKeys] containsObject:@"realtime_test_key"]) {
              [self presentViewController:alert animated:YES completion:nil];
            }
            NSString *updatedParams = [update updatedKeys];
            [[FRCLog sharedInstance]
                logToConsole:[NSString stringWithFormat:[updatedParams description]]];
            [self apply];
          }
        }
      }];
  [[FRCLog sharedInstance] logToConsole:@"RC instances inited"];

  self.namespacePicker.dataSource = self;
  self.namespacePicker.delegate = self;
  self.appPicker.dataSource = self;
  self.appPicker.delegate = self;
  [self.developerModeEnabled setOn:true animated:false];
}

- (IBAction)fetchButtonPressed:(id)sender {
  [[FRCLog sharedInstance] logToConsole:@"Fetch button pressed"];
  // fetchConfig api callback, this is triggered when client receives response from server
  ViewController *__weak weakSelf = self;
  FIRRemoteConfigFetchCompletion completion = ^(FIRRemoteConfigFetchStatus status, NSError *error) {
    ViewController *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    [[FRCLog sharedInstance]
        logToConsole:[NSString stringWithFormat:@"Fetch completed. Status=%@",
                                                [strongSelf statusString:status]]];
    if (error) {
      [[FRCLog sharedInstance] logToConsole:[NSString stringWithFormat:@"Fetch Error=%@", error]];
    }

    NSMutableString *output = [NSMutableString
        stringWithFormat:@"Fetch status : %@.\n\n", [strongSelf statusString:status]];
    if (error) {
      [output appendFormat:@"%@\n", error];
    }
    if (status == FIRRemoteConfigFetchStatusFailure) {
      [output appendString:[NSString stringWithFormat:@"Fetch Error :%@.\n",
                                                      [strongSelf errorString:error.code]]];
      if (error.code == FIRRemoteConfigErrorThrottled) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSNumber *throttledTime =
            (NSNumber *)error.userInfo[FIRRemoteConfigThrottledEndTimeInSecondsKey];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[throttledTime doubleValue]];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString *timeString = [dateFormatter stringFromDate:date];

        [output appendString:[NSString stringWithFormat:@"Throttled end at: %@ \n", timeString]];
      }
    }
    [[FRCLog sharedInstance] logToConsole:output];
  };

  // fetchConfig api call
  [[FRCLog sharedInstance] logToConsole:@"Calling fetchWithExpirationDuration.."];
  [self.RCInstances[self.currentNamespace][self.FIRAppName]
      fetchWithExpirationDuration:self.expirationLabel.text.integerValue
                completionHandler:completion];
}

- (IBAction)fetchAndActivateButtonPressed:(id)sender {
  // fetchConfig api callback, this is triggered when client receives response from server
  ViewController *__weak weakSelf = self;
  FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion = ^(
      FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
    ViewController *strongSelf = weakSelf;
    if (!strongSelf) {
      return;
    }
    NSMutableString *output = [@"Fetch and activate status :" mutableCopy];
    if (status == FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote) {
      [output appendString:@"Success from remote fetch."];
    } else if (status == FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData) {
      [output appendString:@"Success using pre-fetched data."];
    } else if (status == FIRRemoteConfigFetchAndActivateStatusError) {
      [output
          appendString:[NSString stringWithFormat:@"Failure: %@", [error localizedDescription]]];
    }

    if (error) {
      [output appendFormat:@"%@\n", error];
    }
    if (status == FIRRemoteConfigFetchAndActivateStatusError) {
      [output appendString:[NSString stringWithFormat:@"Fetch And Activate Error :%@.\n",
                                                      [strongSelf errorString:error.code]]];
      if (error.code == FIRRemoteConfigErrorThrottled) {
        [output appendString:[NSString stringWithFormat:@"Throttled.\n"]];
      }
    }
    // activate status
    [[FRCLog sharedInstance] logToConsole:output];
    if (status == FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote ||
        status == FIRRemoteConfigFetchAndActivateStatusSuccessUsingPreFetchedData) {
      [strongSelf printResult:[[NSMutableString alloc] init]];
    }
  };

  // fetchConfig api call
  [self.RCInstances[self.currentNamespace][self.FIRAppName]
      fetchAndActivateWithCompletionHandler:fetchAndActivateCompletion];
}

- (IBAction)activateButtonPressed:(id)sender {
  [self apply];
}

- (IBAction)refreshButtonPressed:(id)sender {
  NSMutableString *output = [[NSMutableString alloc] init];
  [self printResult:output];
}

- (IBAction)setDefaultFromPlistButtonPressed:(id)sender {
  [self.RCInstances[self.currentNamespace][self.FIRAppName]
      setDefaultsFromPlistFileName:@"Defaults"];
  [self printDefaultConfigs];
}

- (IBAction)setDefaultButtonPressed:(id)sender {
  if (self.configDefaults.count) {
    [self.RCInstances[self.currentNamespace][self.FIRAppName] setDefaults:self.configDefaults];
    [self.configDefaults removeAllObjects];
    [self printDefaultConfigs];
  } else {
    [[FRCLog sharedInstance] logToConsole:@"Nothing to set for defaults."];
  }
}

- (IBAction)onClearLogsButtonPressed:(id)sender {
  self.mainTextView.text = @"";
}

- (void)printDefaultConfigs {
  NSMutableString *output = [[NSMutableString alloc] init];
  [output appendString:@"\n-------Default config------\n"];
  NSArray<NSString *> *result = [self.RCInstances[self.currentNamespace][self.FIRAppName]
      allKeysFromSource:FIRRemoteConfigSourceDefault];
  if (result) {
    NSString *stringPerNs = @"";
    for (NSString *key in result) {
      FIRRemoteConfigValue *value =
          [self.RCInstances[self.currentNamespace][self.FIRAppName] defaultValueForKey:key];
      stringPerNs = [NSString stringWithFormat:@"%@%@ : %@ : %@\n", stringPerNs,
                                               self.currentNamespace, key, value.stringValue];
    }
    [output appendString:stringPerNs];
  }
  [[FRCLog sharedInstance] logToConsole:output];
}

- (IBAction)getValueButtonPressed:(id)sender {
  [[FRCLog sharedInstance] logToConsole:[self.RCInstances[self.currentNamespace][self.FIRAppName]
                                            configValueForKey:self.keyLabel.text]
                                            .debugDescription];
}

- (IBAction)logValueButtonPressed:(id)sender {
  [[FRCLog sharedInstance]
      logToConsole:[NSString stringWithFormat:@"key: %@ logged", self.keyLabel.text]];
}

// add default variable button pressed
- (IBAction)addButtonPressed:(id)sender {
  [self addNewEntryToVariables:self.configDefaults isDefaults:YES];
}

- (IBAction)developerModeSwitched:(id)sender {
  FIRRemoteConfigSettings *configSettings = [[FIRRemoteConfigSettings alloc] init];
  ((FIRRemoteConfig *)(self.RCInstances[self.currentNamespace][self.FIRAppName])).configSettings =
      configSettings;
}

- (void)addNewEntryToVariables:(NSMutableDictionary *)variables isDefaults:(BOOL)isDefaults {
  if ([self.keyLabel.text length]) {
    variables[self.keyLabel.text] = self.valueLabel.text;

    NSString *showText = @"custom variables ";
    if (isDefaults) {
      showText = @"config defaults";
    }
    [[FRCLog sharedInstance]
        logToConsole:[NSString stringWithFormat:@"New %@ added %@ : %@\n", showText,
                                                self.keyLabel.text, self.valueLabel.text]];

    self.keyLabel.text = @"";
    self.valueLabel.text = @"";
  }
}

- (void)apply {
  [self.RCInstances[self.currentNamespace][self.FIRAppName]
      activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        NSMutableString *output = [[NSMutableString alloc] init];
        [output appendString:[NSString stringWithFormat:@"ActivateFetched = %@\n",
                                                        changed ? @"YES" : @"NO"]];
        [[FRCLog sharedInstance] logToConsole:output];
        if (!error) {
          [self printResult:output];
        } else {
          [self printResult:[[NSString stringWithFormat:@"Activate failed. Error: %@",
                                                        error.localizedDescription] mutableCopy]];
        }
      }];
}

// print out fetch result
- (void)printResult:(NSMutableString *)output {
  FIRRemoteConfig *currentRCInstance = self.RCInstances[self.currentNamespace][self.FIRAppName];
  NSString *namespace_p = self.currentNamespace;
  [output appendString:@"-------Active config------\n"];

  NSArray<NSString *> *result = [self.RCInstances[self.currentNamespace][self.FIRAppName]
      allKeysFromSource:FIRRemoteConfigSourceRemote];
  if (result) {
    NSString *stringPerNs = @"";
    for (NSString *key in result) {
      FIRRemoteConfigValue *value = [currentRCInstance configValueForKey:key];
      stringPerNs = [NSString
          stringWithFormat:@"%@%@ : %@ : %@\n", stringPerNs, namespace_p, key, value.stringValue];
    }
    [output appendString:stringPerNs];
  }
  [output appendString:@"\n-------Default config------\n"];
  result = [currentRCInstance allKeysFromSource:FIRRemoteConfigSourceDefault];
  if (result) {
    NSString *stringPerNs = @"";
    for (NSString *key in result) {
      FIRRemoteConfigValue *value = [currentRCInstance defaultValueForKey:key];
      stringPerNs = [NSString
          stringWithFormat:@"%@%@ : %@ : %@\n", stringPerNs, namespace_p, key, value.stringValue];
    }
    [output appendString:stringPerNs];
  }

  [output appendString:@"\n--------Custom Variables--------\n"];

  [output appendString:@"\n----------Last fetch time----------------\n"];
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  [output
      appendString:[NSString stringWithFormat:@"%@\n",
                                              [dateFormatter
                                                  stringFromDate:currentRCInstance.lastFetchTime]]];
  [output appendString:@"\n-----------Last fetch status------------\n"];
  [output appendString:[NSString
                           stringWithFormat:@"%@\n",
                                            [self statusString:currentRCInstance.lastFetchStatus]]];

  FIRInstallations *installations = [FIRInstallations installations];
  [installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                NSError *_Nullable error) {
    [output appendString:@"\n-----------Installation ID------------------\n"];
    [output appendString:[NSString stringWithFormat:@"%@\n", identifier]];

    [output appendString:@"\n-----------Installation ID token------------\n"];

    [installations authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                             NSError *_Nullable error) {
      [output appendString:[NSString stringWithFormat:@"%@\n", tokenResult.authToken]];
      [[FRCLog sharedInstance] logToConsole:output];
    }];
  }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  return YES;
}

- (NSString *)statusString:(FIRRemoteConfigFetchStatus)status {
  switch (status) {
    case FIRRemoteConfigFetchStatusSuccess:
      return @"Success";
    case FIRRemoteConfigFetchStatusNoFetchYet:
      return @"NotFetchYet";
    case FIRRemoteConfigFetchStatusFailure:
      return @"Failure";
    case FIRRemoteConfigFetchStatusThrottled:
      return @"Throttled";
    default:
      return @"Unknown";
  }
  return @"";
}

- (NSString *)errorString:(FIRRemoteConfigError)error {
  switch (error) {
    case FIRRemoteConfigErrorInternalError:
      return @"Internal Error";
    case FIRRemoteConfigErrorUnknown:
      return @"Unknown Error";
    case FIRRemoteConfigErrorThrottled:
      return @"Throttled";
    default:
      return @"unknown";
  }
  return @"";
}

- (IBAction)fetchIIDButtonClicked:(id)sender {
  FIRInstallations *installations =
      [FIRInstallations installationsWithApp:[FIRApp appNamed:self.FIRAppName]];
  [installations installationIDWithCompletion:^(NSString *_Nullable identifier,
                                                NSError *_Nullable error) {
    if (error) {
      [[FRCLog sharedInstance] logToConsole:[NSString stringWithFormat:@"%@", error]];
    } else {
      [installations authTokenWithCompletion:^(
                         FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                         NSError *_Nullable error) {
        if (tokenResult.authToken) {
          ((FIRRemoteConfig *)self.RCInstances[self.currentNamespace][self.FIRAppName])
              .settings.configInstallationsToken = tokenResult.authToken;
          [[FRCLog sharedInstance]
              logToConsole:[NSString
                               stringWithFormat:
                                   @"Successfully got installation ID : \n\n%@\n\nToken : \n\n%@\n",
                                   identifier, tokenResult.authToken]];
        }
      }];
    }
  }];
}

- (IBAction)searchButtonClicked:(id)sender {
  NSString *output = @"-------Active Config------\n";

  for (NSString *key in [self.RCInstances[self.currentNamespace][self.FIRAppName]
           keysWithPrefix:self.keyLabel.text]) {
    FIRRemoteConfigValue *value =
        ((FIRRemoteConfig *)(self.RCInstances[self.currentNamespace][self.FIRAppName]))[key];
    output = [NSString stringWithFormat:@"%@%@ : %@ : %@\n", output, self.currentNamespace, key,
                                        value.stringValue];
  }

  [[FRCLog sharedInstance] logToConsole:output];
}

- (IBAction)userPropertyButtonClicked:(id)sender {
  [FIRAnalytics setUserPropertyString:self.valueLabel.text forName:self.keyLabel.text];

  NSString *output = [NSString
      stringWithFormat:@"Set User Property => %@ : %@\n", self.keyLabel.text, self.valueLabel.text];
  [[FRCLog sharedInstance] logToConsole:output];
}

#pragma mark - picker

// The number of columns of data
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
  // App and currentNamespace pickers.
  return 2;
}

// The number of rows of data
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
  NSInteger rowCount = (component == 0) ? self.namespacePickerData.count : self.appPickerData.count;
  return rowCount;
}

// The data to return for the row and component (column) that's being passed in
- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
  if (component == 0) {
    self.currentNamespace = self.namespacePickerData[row];
    return self.namespacePickerData[row];
  } else {
    self.FIRAppName = self.appPickerData[row];
    return self.appPickerData[row];
  }
}

- (UIView *)pickerView:(UIPickerView *)pickerView
            viewForRow:(NSInteger)row
          forComponent:(NSInteger)component
           reusingView:(UIView *)view {
  UILabel *tView = (UILabel *)view;
  if (!tView) {
    tView = [[UILabel alloc] init];
    [tView setFont:[UIFont fontWithName:@"Helvetica" size:15]];
    tView.numberOfLines = 3;
  }
  if (component == 0) {
    self.currentNamespace = self.namespacePickerData[row];
    tView.text = self.namespacePickerData[row];
  } else {
    self.FIRAppName = self.appPickerData[row];
    tView.text = self.appPickerData[row];
  }

  return tView;
}

@end
