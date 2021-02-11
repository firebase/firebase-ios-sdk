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

#import "PerfE2EScreenTracesViewController.h"

/** Number of cells in the table view. */
static const NSInteger kNumberOfCellsInTable = 200;

/** Number of sections in the table view. */
static const NSInteger kNumberOfSectionsInTable = 1;

/** Defines X where every Xth cell on load causes a frozen frame. */
static const NSInteger kIntervalOfCellThatCausesFrozenFrame = 15;

/** Duration for which the main thread has to be stalled to deterministically cause a frozen frame.
 */
static const NSTimeInterval kThreadSleepDurationForFrozenFrame = 0.9;

/** Duration for which the main thread has to be stalled to deterministically cause a slow frame. */
static const NSTimeInterval kThreadSleepDurationForSlowFrame = 0.05;

@interface PerfE2EScreenTracesViewController ()

@end

@implementation PerfE2EScreenTracesViewController

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return kNumberOfSectionsInTable;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return kNumberOfCellsInTable;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  // Not recycling cells so that this table view is deliberately slow.
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                 reuseIdentifier:nil];
  cell.textLabel.text = [NSString stringWithFormat:@"%ld", indexPath.row];
  cell.accessibilityIdentifier = [NSString stringWithFormat:@"cell_%ld", indexPath.row];

  // Adds a manual delay that slows down this method.
  if (indexPath.row % kIntervalOfCellThatCausesFrozenFrame == 0) {
    [NSThread sleepForTimeInterval:kThreadSleepDurationForFrozenFrame];
  } else {
    [NSThread sleepForTimeInterval:kThreadSleepDurationForSlowFrame];
  }

  return cell;
}

@end
