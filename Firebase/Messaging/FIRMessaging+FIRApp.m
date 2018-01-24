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

#import "FIRMessaging+FIRApp.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>

#import "FIRMessagingConstants.h"
#import "FIRMessagingLogger.h"
#import "FIRMessagingPubSub.h"
#import "FIRMessagingRemoteNotificationsProxy.h"
#import "FIRMessagingVersionUtilities.h"
#import "FIRMessaging_Private.h"

@interface FIRMessaging ()

@property(nonatomic, readwrite, strong) NSString *fcmSenderID;

@end

@implementation FIRMessaging (FIRApp)

+ (void)load {
  // FIRMessaging by default removes itself from observing any notifications.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveConfigureSDKNotification:)
                                               name:kFIRAppReadyToConfigureSDKNotification
                                             object:[FIRApp class]];
}

+ (void)didReceiveConfigureSDKNotification:(NSNotification *)notification {
  NSDictionary *appInfoDict = notification.userInfo;
  NSNumber *isDefaultApp = appInfoDict[kFIRAppIsDefaultAppKey];
  if (![isDefaultApp boolValue]) {
    // Only configure for the default FIRApp.
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeFIRApp001,
                            @"Firebase Messaging only works with the default app.");
    return;
  }

  NSString *appName = appInfoDict[kFIRAppNameKey];
  FIRApp *app = [FIRApp appNamed:appName];
  [[FIRMessaging messaging] configureMessaging:app];
}

- (void)configureMessaging:(FIRApp *)app {
  FIROptions *options = app.options;
  NSError *error;
  if (!options.GCMSenderID.length) {
    error =
        [FIRApp errorForSubspecConfigurationFailureWithDomain:kFirebaseCloudMessagingErrorDomain
                                                    errorCode:FIRErrorCodeCloudMessagingFailed
                                                      service:kFIRServiceMessaging
                                                       reason:@"Google Sender ID must not be nil"
                                                              @" or empty."];
    [self exitApp:app withError:error];
    return;
  }

  self.fcmSenderID = [options.GCMSenderID copy];

  // Swizzle remote-notification-related methods (app delegate and UNUserNotificationCenter)
  if ([FIRMessagingRemoteNotificationsProxy canSwizzleMethods]) {
    NSString *docsURLString = @"https://firebase.google.com/docs/cloud-messaging/ios/client"
                              @"#method_swizzling_in_firebase_messaging";
    FIRMessagingLoggerNotice(kFIRMessagingMessageCodeFIRApp000,
                             @"FIRMessaging Remote Notifications proxy enabled, will swizzle "
                             @"remote notification receiver handlers. If you'd prefer to manually "
                             @"integrate Firebase Messaging, add \"%@\" to your Info.plist, "
                             @"and set it to NO. Follow the instructions at:\n%@\nto ensure "
                             @"proper integration.",
                             kFIRMessagingRemoteNotificationsProxyEnabledInfoPlistKey,
                             docsURLString);
    [FIRMessagingRemoteNotificationsProxy swizzleMethods];
  }
}

- (void)exitApp:(FIRApp *)app withError:(NSError *)error {
  [app sendLogsWithServiceName:kFIRServiceMessaging
                       version:FIRMessagingCurrentLibraryVersion()
                         error:error];
  if (error) {
    NSString *message = nil;
    if (app.options.usingOptionsFromDefaultPlist) {
      // Configured using plist file
      message = [NSString stringWithFormat:@"Firebase Messaging has stopped your project because "
                    @"there are missing or incorrect values provided in %@.%@ that may prevent "
                    @"your app from behaving as expected:\n\n"
                    @"Error: %@\n\n"
                    @"Please fix these issues to ensure that Firebase is correctly configured in "
                    @"your project.",
                    kServiceInfoFileName,
                    kServiceInfoFileType,
                    error.localizedFailureReason];
    } else {
      // Configured manually
      message = [NSString stringWithFormat:@"Firebase Messaging has stopped your project because "
                    @"there are missing or incorrect values in Firebase's configuration options "
                    @"that may prevent your app from behaving as expected:\n\n"
                    @"Error:%@\n\n"
                    @"Please fix these issues to ensure that Firebase is correctly configured in "
                    @"your project.",
                    error.localizedFailureReason];
    }
    [NSException raise:kFirebaseCloudMessagingErrorDomain format:@"%@", message];
  }
}

@end
