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
