/*
 * Copyright 2019 Google
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

#import "StaticContentTableViewManager.h"

/** @var kCellReuseIdentitfier
    @brief The reuse identifier for default style table view cell.
 */
static NSString *const kCellReuseIdentitfier = @"reuseIdentifier";

/** @var kCellReuseIdentitfier
    @brief The reuse identifier for value style table view cell.
 */
static NSString *const kValueCellReuseIdentitfier = @"reuseValueIdentifier";

#pragma mark -

@implementation StaticContentTableViewManager

- (void)setContents:(StaticContentTableViewContent *)contents {
  _contents = contents;
  [self.tableView reloadData];
}

- (void)setTableView:(UITableView *)tableView {
  _tableView = tableView;
  [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kCellReuseIdentitfier];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return _contents.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _contents.sections[section].cells.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  return _contents.sections[section].title;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
  return index;
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView {
  NSMutableArray<NSString *> *sectionTitles = [NSMutableArray array];
  for (StaticContentTableViewSection *section in _contents.sections) {
    [sectionTitles addObject:[section.title substringToIndex:3]];
  }
  return sectionTitles;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  StaticContentTableViewCell *cellData = _contents.sections[indexPath.section].cells[indexPath.row];
  if (cellData.customCell) {
    return cellData.customCell.frame.size.height;
  }
  return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  StaticContentTableViewCell *cellData = _contents.sections[indexPath.section].cells[indexPath.row];
  UITableViewCell *cell = cellData.customCell;
  if (cell) {
    return cell;
  }
  if (cellData.value.length) {
    cell = [tableView dequeueReusableCellWithIdentifier:kValueCellReuseIdentitfier];
    if (!cell) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                    reuseIdentifier:kValueCellReuseIdentitfier];
      cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
      cell.detailTextLabel.minimumScaleFactor = 0.5;
    }
    cell.detailTextLabel.text = cellData.value;
  } else {
    // kCellReuseIdentitfier has already been registered.
    cell = [tableView dequeueReusableCellWithIdentifier:kCellReuseIdentitfier
                                           forIndexPath:indexPath];
  }
  cell.textLabel.text = cellData.title;
  cell.accessibilityIdentifier = cellData.accessibilityIdentifier;
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  StaticContentTableViewCell *cellData = _contents.sections[indexPath.section].cells[indexPath.row];
  BOOL hasAssociatedAction = cellData.action != nil;
  if (hasAssociatedAction) {
    cellData.action();
  }
  [tableView deselectRowAtIndexPath:indexPath animated:hasAssociatedAction];
}

@end

#pragma mark -

@implementation StaticContentTableViewContent

+ (nullable instancetype)contentWithSections:
    (nullable NSArray<StaticContentTableViewSection *> *)sections {
  return [[self alloc] initWithSections:sections];
}

- (nullable instancetype)initWithSections:
    (nullable NSArray<StaticContentTableViewSection *> *)sections {
  self = [super init];
  if (self) {
    _sections = [sections copy];
  }
  return self;
}

@end

#pragma mark -

@implementation StaticContentTableViewSection

+ (nullable instancetype)sectionWithTitle:(nullable NSString *)title
                                    cells:(nullable NSArray<StaticContentTableViewCell *> *)cells {
  return [[self alloc] initWithTitle:title cells:cells];
}

- (nullable instancetype)initWithTitle:(nullable NSString *)title
                                 cells:(nullable NSArray<StaticContentTableViewCell *> *)cells {
  self = [super init];
  if (self) {
    _title = [title copy];
    _cells = [cells copy];
  }
  return self;
}

@end

#pragma mark -

@implementation StaticContentTableViewCell

+ (nullable instancetype)cellWithTitle:(nullable NSString *)title {
  return [[self alloc] initWithCustomCell:nil
                                    title:title
                                    value:nil
                                   action:nil
                          accessibilityID:nil];
}

+ (nullable instancetype)cellWithTitle:(nullable NSString *)title
                                 value:(nullable NSString *)value {
  return [[self alloc] initWithCustomCell:nil
                                    title:title
                                    value:value
                                   action:nil
                          accessibilityID:nil];
}

+ (nullable instancetype)cellWithTitle:(nullable NSString *)title
                                action:(nullable StaticContentTableViewCellAction)action {
  return [[self alloc] initWithCustomCell:nil
                                    title:title
                                    value:nil
                                   action:action
                          accessibilityID:nil];
}

+ (nullable instancetype)cellWithTitle:(nullable NSString *)title
                                 value:(nullable NSString *)value
                                action:(nullable StaticContentTableViewCellAction)action {
  return [[self alloc] initWithCustomCell:nil
                                    title:title
                                    value:value
                                   action:action
                          accessibilityID:nil];
}

+ (nullable instancetype)cellWithTitle:(nullable NSString *)title
                                 value:(nullable NSString *)value
                                action:(nullable StaticContentTableViewCellAction)action
                       accessibilityID:(nullable NSString *)accessibilityID {
      return [[self alloc] initWithCustomCell:nil
                                        title:title
                                        value:value
                                       action:action
                              accessibilityID:accessibilityID];
}

+ (nullable instancetype)cellWithCustomCell:(nullable UITableViewCell *)customCell {
  return [[self alloc] initWithCustomCell:customCell
                                    title:nil
                                    value:nil
                                   action:nil
                          accessibilityID:nil];
}

+ (nullable instancetype)cellWithCustomCell:(nullable UITableViewCell *)customCell
                                     action:(nullable StaticContentTableViewCellAction)action {
  return [[self alloc] initWithCustomCell:customCell
                                    title:nil
                                    value:nil action:action
                          accessibilityID:nil];
}

- (nullable instancetype)initWithCustomCell:(nullable UITableViewCell *)customCell
                                      title:(nullable NSString *)title
                                      value:(nullable NSString *)value
                                     action:(nullable StaticContentTableViewCellAction)action
                            accessibilityID:(nullable NSString *)accessibilityID {
  self = [super init];
  if (self) {
    _customCell = customCell;
    _title = [title copy];
    _value = [value copy];
    _action = action;
    if (accessibilityID) {
      _accessibilityIdentifier = [accessibilityID copy];
      self.isAccessibilityElement = YES;
    }
  }
  return self;
}

@end
