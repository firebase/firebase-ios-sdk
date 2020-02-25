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

  //[MYInterestingClass doSomething];

  // Results of this are ORed and NO doesn't affect other delegate interceptors' result.
  return NO;
}

//- (BOOL)application:(UIApplication *)application
//            openURL:(NSURL *)URL
//  sourceApplication:(NSString *)sourceApplication
//         annotation:(id)annotation {
//
//    //[MYInterestingClass doSomething];
//
//  // Results of this are ORed and NO doesn't affect other delegate interceptors' result.
//  return NO;
//}
//
//#pragma mark - Network overridden handler methods
//
//- (void)application:(UIApplication *)application
//    handleEventsForBackgroundURLSession:(NSString *)identifier
//                      completionHandler:(void (^)(void))completionHandler {
//
//  // Note: Interceptors are not responsible for (and should not) call the completion handler.
//  //[MYInterestingClass doSomething];
//}
//
//#pragma mark - User Activities overridden handler methods
//
//- (BOOL)application:(UIApplication *)application
//    continueUserActivity:(NSUserActivity *)userActivity
//      restorationHandler:(void (^)(NSArray *restorableObjects))restorationHandler {
//
//  //[MYInterestingClass doSomething];
//
//  // Results of this are ORed and NO doesn't affect other delegate interceptors' result.
//  return NO;
//}

@end
