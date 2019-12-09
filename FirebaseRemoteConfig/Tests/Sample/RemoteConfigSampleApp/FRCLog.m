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

#import "FRCLog.h"
#import <UIKit/UIKit.h>

@implementation FRCLog

__weak UITextView* _logView;
NSString* _textUntilTextViewSet;

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static FRCLog* sharedInstance;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FRCLog alloc] init];
  });
  return sharedInstance;
}

- (void)setLogView:(UITextView*)view {
  _logView = view;
  _logView.text = @"";
}

- (void)logToConsoleInternal:(NSString*)text {
  NSDate* now = [NSDate date];
  NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"HH:mm:ss"];

  NSString* append =
      [[NSString stringWithFormat:@"FRCLog(%@): ", [dateFormatter stringFromDate:now]]
          stringByAppendingString:text];
  append = [append stringByAppendingString:@"\n"];
  NSLog(@"%@", append);
  if (!_logView) {
    NSLog(@"FRCLog: Logview not set");
    if (!_textUntilTextViewSet) _textUntilTextViewSet = [[NSString alloc] initWithString:append];
    [_textUntilTextViewSet stringByAppendingString:append];
  } else {
    if (_textUntilTextViewSet) {
      _logView.text = _textUntilTextViewSet;
      _textUntilTextViewSet = nil;
    }
    _logView.text = [_logView.text stringByAppendingString:append];
  }
  [self scrollToBottom];
}

- (void)logToConsole:(NSString*)text {
  if ([NSThread isMainThread]) {
    [self logToConsoleInternal:text];
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self logToConsoleInternal:text];
    });
  }
}

- (void)scrollToBottom {
  if (_logView && _logView.text.length > 0) {
    [_logView scrollRangeToVisible:NSMakeRange(_logView.text.length - 1, 1)];
  }
}
@end
