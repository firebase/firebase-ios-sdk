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

#import "ParamTableViewCell.h"

static const NSUInteger kHInset = 10;
static const NSUInteger kVInset = 4;

@implementation ParamTableViewCell {
  UILabel *_label;
  UITextField *_textField;
}

@synthesize paramConfig = _paramConfig;

- (instancetype)init {
  self = [super initWithStyle:UITableViewCellStyleDefault
              reuseIdentifier:NSStringFromClass(self.class)];
  if (self) {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _label = [[UILabel alloc] init];
    _label.font = [UIFont italicSystemFontOfSize:[UIFont systemFontSize]];
    _textField = [[UITextField alloc] init];
    _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    [self.contentView addSubview:_label];
    [self.contentView addSubview:_textField];
    [_textField addTarget:self
                   action:@selector(onTextFieldValueChanged)
         forControlEvents:UIControlEventEditingChanged];
    [_textField addTarget:self
                   action:@selector(onTextFieldDidEndOnExit)
         forControlEvents:UIControlEventEditingDidEndOnExit];
  }
  return self;
}

- (void)layoutSubviews {
  _label.frame = CGRectMake(kHInset, kVInset, self.contentView.frame.size.width - 2 * kHInset,
                            (self.contentView.frame.size.height / 2) - 2 * kVInset);
  _textField.frame = CGRectMake(kHInset, (self.contentView.frame.size.height / 2) + kVInset,
                                self.contentView.frame.size.width - 2 * kHInset,
                                (self.contentView.frame.size.height / 2) - 2 * kVInset);
}

- (void)onTextFieldValueChanged {
  if (![self.textFieldValue isEqualToString:_textField.text]) {
    self.textFieldValue = _textField.text;
    [_delegate paramTableViewCellUpdatedValue:self];
  }
}

- (void)onTextFieldDidEndOnExit {
  [_textField resignFirstResponder];
}

- (void)setTextFieldValue:(NSString *)textFieldValue {
  _textFieldValue = textFieldValue;
  if (![_textFieldValue isEqualToString:_textField.text]) {
    _textField.text = self.textFieldValue;
  }
}

- (void)setParamConfig:(NSDictionary *)paramConfig {
  _paramConfig = [paramConfig copy];
  self.accessibilityIdentifier = _paramConfig[@"id"];
  _label.text = _paramConfig[@"label"];
}

@end
