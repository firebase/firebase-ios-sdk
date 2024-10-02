/*
 * Copyright 2017 Google
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

#import "AppDelegate.h"
#import <FirebaseInAppMessaging/FIRIAMClearcutUploader.h>
#import <FirebaseInAppMessaging/FIRIAMRuntimeManager.h>
#import <FirebaseInAppMessaging/FIRInAppMessaging+Bootstrap.h>
#import <FirebaseInAppMessaging/NSString+FIRInterlaceStrings.h>

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseDynamicLinks/FirebaseDynamicLinks.h>

@interface FIRInAppMessaging (Testing)
+ (void)disableAutoBootstrapWithFIRApp;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  NSLog(@"application started");

  [FIRInAppMessaging disableAutoBootstrapWithFIRApp];
  [FIROptions defaultOptions].deepLinkURLScheme = @"fiam-testing";
  [FIRApp configure];

  FIRIAMSDKSettings *sdkSetting = [[FIRIAMSDKSettings alloc] init];

  sdkSetting.apiServerHost = @"firebaseinappmessaging.googleapis.com";

  NSString *serverHostNameFirstComponent = @"pa.ogepscm";
  NSString *serverHostNameSecondComponent = @"lygolai.o";

  sdkSetting.clearcutServerHost = [NSString fir_interlaceString:serverHostNameFirstComponent
                                                     withString:serverHostNameSecondComponent];
  sdkSetting.apiHttpProtocol = @"https";
  sdkSetting.fetchMinIntervalInMinutes = 0.1;  // ok to refetch every 6 seconds
  sdkSetting.loggerMaxCountBeforeReduce = 800;
  sdkSetting.loggerSizeAfterReduce = 600;
  sdkSetting.appFGRenderMinIntervalInMinutes = 0.1;
  sdkSetting.loggerInVerboseMode = YES;
  sdkSetting.firebaseAutoDataCollectionEnabled = NO;

  sdkSetting.clearcutStrategy =
      [[FIRIAMClearcutStrategy alloc] initWithMinWaitTimeInMills:5 * 1000   // 5 seconds
                                              maxWaitTimeInMills:30 * 1000  // 30 seconds
                                       failureBackoffTimeInMills:60 * 1000  // 60 seconds
                                                   batchSendSize:50];

  [FIRInAppMessaging bootstrapIAMWithSettings:sdkSetting];
  return YES;
}

- (BOOL)application:(UIApplication *)application
    continueUserActivity:(NSUserActivity *)userActivity
      restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
  NSLog(@"handle page url %@", userActivity.webpageURL);
  BOOL handled = [[FIRDynamicLinks dynamicLinks]
      handleUniversalLink:userActivity.webpageURL
               completion:^(FIRDynamicLink *_Nullable dynamicLink, NSError *_Nullable error) {
                 if (dynamicLink) {
                   NSLog(@"dynamic link recognized with url as %@", dynamicLink.url.absoluteString);
                   [self showDeepLink:dynamicLink.url.absoluteString forUrlType:@"universal link"];
                 } else {
                   NSLog(@"error happened %@", error);
                 }
               }];
  return handled;
}

- (void)showDeepLink:(NSString *)url forUrlType:(NSString *)urlType {
  NSString *message = [NSString stringWithFormat:@"App wants to open a %@ : %@", urlType, url];
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"Deep link recognized"
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action){
                                                        }];

  [alert addAction:defaultAction];
  [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alert
                                                                             animated:YES
                                                                           completion:nil];
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<NSString *, id> *)options {
  return [self application:app openURL:url sourceApplication:@"source app" annotation:@{}];
}

- (BOOL)application:(UIApplication *)application
              openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication
           annotation:(id)annotation {
  NSLog(@"handle link with custom scheme: %@", url.absoluteString);
  [self showDeepLink:url.absoluteString forUrlType:@"custom scheme url"];
  return YES;
}
@end
