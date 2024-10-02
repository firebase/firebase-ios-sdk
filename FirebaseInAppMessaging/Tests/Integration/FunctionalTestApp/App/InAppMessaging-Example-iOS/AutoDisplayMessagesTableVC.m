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

#import "AutoDisplayMessagesTableVC.h"
#import <FirebaseInAppMessaging/FIRIAMDisplayTriggerDefinition.h>
#import <FirebaseInAppMessaging/FIRIAMMessageContentData.h>

@interface AutoDisplayMessagesTableVC ()
@end

@implementation AutoDisplayMessagesTableVC

- (void)messageDataChanged {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.tableView reloadData];
  });
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;

  // Uncomment the following line to display an Edit button in the navigation bar for this view
  // controller. self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSArray<FIRIAMMessageDefinition *> *messages = self.messageCache.allRegularMessages;
  if (messages) {
    return messages.count;
  } else {
    return 0;
  }
}

static NSString *CellIdentifier = @"CellIdentifier";

- (NSString *)viewModeDisplayString:(FIRIAMRenderingMode)viewMode {
  switch (viewMode) {
    case FIRIAMRenderAsBannerView:
      return @"Banner";
    case FIRIAMRenderAsModalView:
      return @"Modal";
    case FIRIAMRenderAsImageOnlyView:
      return @"Image";
    default:
      return @"Unknown";
  }
}

- (NSString *)triggerDisplayString:(NSArray<FIRIAMDisplayTriggerDefinition *> *)triggers {
  NSMutableString *s = [[NSMutableString alloc] init];
  for (FIRIAMDisplayTriggerDefinition *trigger in triggers) {
    [s appendString:[self triggerDisplayStringForOneTrigger:trigger]];
    [s appendString:@","];
  }
  return [s copy];
}

- (NSString *)triggerDisplayStringForOneTrigger:
    (FIRIAMDisplayTriggerDefinition *)triggerDefinition {
  switch (triggerDefinition.triggerType) {
    case FIRIAMRenderTriggerOnAppForeground:
      return @"app_foreground";
    case FIRIAMRenderTriggerOnFirebaseAnalyticsEvent:
      return triggerDefinition.firebaseEventName;
    default:
      return @"Unknown";
  }
}
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSArray<FIRIAMMessageDefinition *> *messageDefs = self.messageCache.allRegularMessages;

  NSInteger rowIndex = [indexPath row];
  if (messageDefs.count > rowIndex) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                    reuseIdentifier:CellIdentifier];
    }

    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:10];
    UILabel *modeLabel = (UILabel *)[cell.contentView viewWithTag:20];
    UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:30];
    UILabel *triggerLabel = (UILabel *)[cell.contentView viewWithTag:40];

    titleLabel.text = messageDefs[rowIndex].renderData.contentData.titleText;
    modeLabel.text = [self
        viewModeDisplayString:messageDefs[rowIndex].renderData.renderingEffectSettings.viewMode];

    triggerLabel.text = [self triggerDisplayString:messageDefs[rowIndex].renderTriggers];

    [messageDefs[rowIndex].renderData.contentData
        loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                                 NSError *error) {
          if (error) {
            NSLog(@"error in loading image: %@", error.localizedDescription);
          } else {
            UIImage *image = [UIImage imageWithData:imageData];
            dispatch_async(dispatch_get_main_queue(), ^{
              [imageView setImage:image];
            });
          }
        }];
    return cell;
  } else {
    return nil;
  }
}

@end
