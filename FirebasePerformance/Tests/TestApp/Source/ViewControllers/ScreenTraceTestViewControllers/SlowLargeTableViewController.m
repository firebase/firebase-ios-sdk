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
#import "SlowLargeTableViewController.h"

@interface SlowLargeTableViewController ()

@end

@implementation SlowLargeTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.title = @"Slow Table View";
  self.navigationItem.accessibilityLabel = @"Slow Table View";
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
  // Not recycling cells so that this table view is deliberately slow.
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                 reuseIdentifier:nil];
  cell.textLabel.text = [[NSDate date] description];

  // Adds a manual delay that slows down this method.
  int counter = 0;
  for (int i = 0; i < 10000000; ++i) {
    counter += 1;
  }

  return cell;
}

@end
