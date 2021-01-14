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

// Non-google3 relative import to support building with Xcode.
#import "ScreenTracesTestScreensListViewController.h"
#import "ScreenTraceTestViewControllers/FastLargeTableViewController.h"
#import "ScreenTraceTestViewControllers/FrozenFramesViewController.h"
#import "ScreenTraceTestViewControllers/SlowLargeTableViewController.h"

/** Reuse identifier of cell that displays name of test screen. */
static NSString *const kTestScreenCellReuseIdentifier = @"TestScreenCell";

/** Name of cell that opens a slow rendering table view with many cells. */
static NSString *const largeSlowTableViewCellName = @"Slow Table View";

/** Name of cell that opens a fairly fast rendering table view with many cells. */
static NSString *const largeFastTableViewCellName = @"Fast Table View";

/** Name of cell that opens a view to reliably reproduce frozen frames. */
static NSString *const frozenFramesViewController = @"Frozen Frames";

@interface ScreenTracesTestScreensListViewController ()

/** Array of names of test screens in the catalog. */
@property(nonatomic) NSArray *screenList;

@end

@implementation ScreenTracesTestScreensListViewController

- (NSArray *)screenList {
  if (!_screenList) {
    _screenList =
        @[ largeSlowTableViewCellName, largeFastTableViewCellName, frozenFramesViewController ];
  }
  return _screenList;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self.tableView registerClass:[UITableViewCell class]
         forCellReuseIdentifier:kTestScreenCellReuseIdentifier];
  self.navigationItem.title = @"Select Test Screen";
  self.navigationItem.accessibilityLabel = @"Select Test Screen";
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.screenList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:kTestScreenCellReuseIdentifier];
  cell.textLabel.text = [self.screenList objectAtIndex:indexPath.row];
  cell.accessibilityLabel = [self.screenList objectAtIndex:indexPath.row];
  return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  NSString *selectedCellName = [self.screenList objectAtIndex:indexPath.row];
  UIViewController *viewControllerToShow;
  if ([selectedCellName isEqualToString:largeSlowTableViewCellName]) {
    viewControllerToShow = [[SlowLargeTableViewController alloc] initWithNibName:nil bundle:nil];
  } else if ([selectedCellName isEqualToString:largeFastTableViewCellName]) {
    viewControllerToShow = [[FastLargeTableViewController alloc] initWithNibName:nil bundle:nil];
  } else if ([selectedCellName isEqualToString:frozenFramesViewController]) {
    viewControllerToShow = [[FrozenFramesViewController alloc] initWithNibName:nil bundle:nil];
  }
  if (viewControllerToShow) {
    [self.splitViewController showDetailViewController:viewControllerToShow sender:self];
  }
}

@end
