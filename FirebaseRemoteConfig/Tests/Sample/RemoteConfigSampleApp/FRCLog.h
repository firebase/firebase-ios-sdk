#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FRCLog : NSObject

+ (instancetype)sharedInstance;

- (void)setLogView:(UITextView*)view;
- (void)logToConsole:(NSString*)text;
@end
