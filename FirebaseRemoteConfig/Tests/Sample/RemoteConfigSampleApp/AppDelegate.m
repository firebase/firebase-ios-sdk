#import "AppDelegate.h"

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIRConfiguration.h>
#import <FirebaseCore/FIROptions.h>

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  FIROptions *options = [FIROptions defaultOptions];
  [FIRApp configureWithOptions:options];

  FIROptions *secondAppOptions = [[FIROptions alloc]
      initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SecondApp-GoogleService-Info"
                                                             ofType:@"plist"]];
  [FIRApp configureWithName:@"secondFIRApp" options:secondAppOptions];
  [[FIRConfiguration sharedInstance] setLoggerLevel:FIRLoggerLevelMax];
  return YES;
}

@end
