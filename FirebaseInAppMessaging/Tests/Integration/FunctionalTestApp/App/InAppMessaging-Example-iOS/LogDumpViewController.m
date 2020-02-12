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

#import "LogDumpViewController.h"

#import "AppDelegate.h"

#import <FirebaseInAppMessaging/FIRIAMRuntimeManager.h>

@interface LogDumpViewController ()
@property(weak, nonatomic) IBOutlet UITextView *logTextView;
@end

@implementation LogDumpViewController
- (IBAction)dumpImpressList:(id)sender {
  NSArray *impressions = [[FIRIAMRuntimeManager getSDKRuntimeInstance].bookKeeper getImpressions];
  NSString *text = [NSString stringWithFormat:@"Message Impression History are :\n%@",
                                              [impressions componentsJoinedByString:@"\n"]];
  self.logTextView.text = text;
}

- (IBAction)dumActivityLogs:(id)sender {
  NSArray<FIRIAMActivityRecord *> *records =
      [[FIRIAMRuntimeManager getSDKRuntimeInstance].activityLogger readRecords];

  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  dateFormatter.dateStyle = NSDateFormatterShortStyle;
  dateFormatter.timeStyle = NSDateFormatterMediumStyle;

  static NSString *appBuildVersion = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    appBuildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
  });

  NSMutableString *dumpContent = [[NSString
      stringWithFormat:@"App Build Version -- %@\n\n"
                        "SDK Settings -- %@\n\n"
                        "Activity Logs: %lu records\n\n",
                       appBuildVersion, [FIRIAMRuntimeManager getSDKRuntimeInstance].currentSetting,
                       (unsigned long)records.count] mutableCopy];

  for (FIRIAMActivityRecord *next in records) {
    NSString *nextRecordLog = [NSString
        stringWithFormat:@"%@, %@, %@, %@\n", [dateFormatter stringFromDate:next.timestamp],
                         [next displayStringForActivityType], next.success ? @"Success" : @"Failed",
                         next.detail];
    [dumpContent appendString:nextRecordLog];
  }
  self.logTextView.text = dumpContent;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}
@end
