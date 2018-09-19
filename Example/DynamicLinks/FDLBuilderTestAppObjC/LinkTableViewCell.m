/*
 * Copyright 2018 Google
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

#import "LinkTableViewCell.h"

static const NSUInteger kHInset = 10;
static const NSUInteger kVInset = 4;

@implementation LinkTableViewCell {
  UILabel *_titleLabel;
  UITextView *_linkTextView;
}

- (instancetype)init {
  self = [super initWithStyle:UITableViewCellStyleDefault
              reuseIdentifier:NSStringFromClass(self.class)];
  if (self) {
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:15];
    _linkTextView = [[UITextView alloc] init];
    _linkTextView.font = [UIFont boldSystemFontOfSize:15];
    _linkTextView.editable = NO;
    _linkTextView.scrollEnabled = NO;
    _linkTextView.dataDetectorTypes = UIDataDetectorTypeLink;
    [self.contentView addSubview:_titleLabel];
    [self.contentView addSubview:_linkTextView];
  }
  return self;
}

- (void)layoutSubviews {
  _titleLabel.frame = CGRectMake(kHInset, kVInset, self.contentView.frame.size.width - 2 * kHInset,
                                 (self.contentView.frame.size.height / 2) - 2 * kVInset);
  _linkTextView.frame = CGRectMake(kHInset, (self.contentView.frame.size.height / 2) + kVInset,
                                   self.contentView.frame.size.width - 2 * kHInset,
                                   (self.contentView.frame.size.height / 2) - 2 * kVInset);
}

- (void)setTitle:(NSString *)title link:(NSString *)link {
  self.accessibilityIdentifier =
      [NSString stringWithFormat:@"%@-%@", NSStringFromClass(self.class), title];
  _linkTextView.accessibilityIdentifier =
      [NSString stringWithFormat:@"%@-LinkTextView-%@", NSStringFromClass(self.class), title];

  _titleLabel.text = title;

  if (link) {
    NSURL *URL = [NSURL URLWithString:link];
    NSAttributedString *attributedLink =
        [[NSAttributedString alloc] initWithString:link attributes:@{NSLinkAttributeName : URL}];
    _linkTextView.attributedText = attributedLink;
  }
  _linkTextView.accessibilityValue = link;
}

@end
