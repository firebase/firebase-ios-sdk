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
#import "FastLargeTableViewController.h"

/** Reuse identifier of cell that displays name of test screen. */
static NSString *const kCellReuseIdentifier = @"CellWithDate";

@interface FastLargeTableViewController ()

@end

@implementation FastLargeTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.title = @"Fast Table View";
  self.navigationItem.accessibilityLabel = @"Fast Table View";
  [self.tableView registerClass:[UITableViewCell class]
         forCellReuseIdentifier:kCellReuseIdentifier];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 10000;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentifier];
  cell.textLabel.text = [[NSDate date] description];
  return cell;
}

@end
