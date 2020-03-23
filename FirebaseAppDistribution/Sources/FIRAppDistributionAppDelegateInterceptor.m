#import "FIRAppDistributionAppDelegateInterceptor.h"
#import "AppAuth.h"
#import <UIKit/UIKit.h>

@implementation FIRAppDistributionAppDelegatorInterceptor

- (instancetype)init {
    self = [super init];
    
    return self;
}

+ (instancetype)sharedInstance {
  static dispatch_once_t once;
  static FIRAppDistributionAppDelegatorInterceptor *sharedInstance;
  dispatch_once(&once, ^{
      sharedInstance = [[FIRAppDistributionAppDelegatorInterceptor alloc] init];
  });
    
  return sharedInstance;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
            options:(NSDictionary<NSString *, id> *)options {

  return NO;
}
@end
