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

#import "FIRInAppMessaging+Bootstrap.h"

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <GoogleUtilities/GULAppEnvironmentUtil.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClearcutUploader.h"
#import "FIRIAMRuntimeManager.h"
#import "FIRIAMSDKSettings.h"
#import "NSString+FIRInterlaceStrings.h"

@implementation FIRInAppMessaging (Bootstrap)

static FIRIAMSDKSettings *_sdkSetting = nil;

static NSString *_fiamServerHostName = @"firebaseinappmessaging.googleapis.com";

+ (NSString *)getFiamServerHost {
  return _fiamServerHostName;
}

+ (void)setFiamServerHostWithName:(NSString *)serverHost {
  _fiamServerHostName = serverHost;
}

+ (NSString *)getServer {
  // Override to change to test server.
  NSString *serverHostNameFirstComponent = @"pa.ogepscm";
  NSString *serverHostNameSecondComponent = @"lygolai.o";
  return [NSString fir_interlaceString:serverHostNameFirstComponent
                            withString:serverHostNameSecondComponent];
}

+ (void)bootstrapIAMFromFIRApp:(FIRApp *)app {
  FIROptions *options = app.options;
  NSError *error;

  if (!options.GCMSenderID.length) {
    error =
        [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                            code:0
                        userInfo:@{
                          NSLocalizedDescriptionKey : @"Google Sender ID must not be nil or empty."
                        }];

    [self exitAppWithFatalError:error];
  }

  if (!options.APIKey.length) {
    error = [NSError
        errorWithDomain:kFirebaseInAppMessagingErrorDomain
                   code:0
               userInfo:@{NSLocalizedDescriptionKey : @"API key must not be nil or empty."}];

    [self exitAppWithFatalError:error];
  }

  if (!options.googleAppID.length) {
    error =
        [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                            code:0
                        userInfo:@{NSLocalizedDescriptionKey : @"Google App ID must not be nil."}];
    [self exitAppWithFatalError:error];
  }

  // following are the default sdk settings to be used by hosting app
  _sdkSetting = [[FIRIAMSDKSettings alloc] init];
  _sdkSetting.apiServerHost = [FIRInAppMessaging getFiamServerHost];
  _sdkSetting.clearcutServerHost = [FIRInAppMessaging getServer];
  _sdkSetting.apiHttpProtocol = @"https";
  _sdkSetting.firebaseAppId = options.googleAppID;
  _sdkSetting.firebaseProjectNumber = options.GCMSenderID;
  _sdkSetting.apiKey = options.APIKey;
  _sdkSetting.fetchMinIntervalInMinutes = 24 * 60;  // fetch at most once every 24 hours
  _sdkSetting.loggerMaxCountBeforeReduce = 100;
  _sdkSetting.loggerSizeAfterReduce = 50;
  _sdkSetting.appFGRenderMinIntervalInMinutes = 24 * 60;  // render at most one message from
                                                          // app-foreground trigger every 24 hours
  _sdkSetting.loggerInVerboseMode = NO;

  // TODO: once Firebase Core supports sending notifications at global Firebase level setting
  // change, FIAM SDK would listen to it and respond to it. Until then, FIAM SDK only checks
  // the setting once upon App/SDK startup.
  _sdkSetting.firebaseAutoDataCollectionEnabled = app.isDataCollectionDefaultEnabled;

  if ([GULAppEnvironmentUtil isSimulator]) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170004",
                @"Running in simulator. Do realtime clearcut uploading.");
    _sdkSetting.clearcutStrategy =
        [[FIRIAMClearcutStrategy alloc] initWithMinWaitTimeInMills:0
                                                maxWaitTimeInMills:0
                                         failureBackoffTimeInMills:60 * 60 * 1000  // 60 mins
                                                     batchSendSize:50];
  } else {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM170005",
                @"Not running in simulator. Use regular clearcut uploading strategy.");
    _sdkSetting.clearcutStrategy =
        [[FIRIAMClearcutStrategy alloc] initWithMinWaitTimeInMills:5 * 60 * 1000        // 5 mins
                                                maxWaitTimeInMills:12 * 60 * 60 * 1000  // 12 hours
                                         failureBackoffTimeInMills:60 * 60 * 1000       // 60 mins
                                                     batchSendSize:50];
  }

  [[FIRIAMRuntimeManager getSDKRuntimeInstance] startRuntimeWithSDKSettings:_sdkSetting];
}

+ (void)bootstrapIAMWithSettings:(FIRIAMSDKSettings *)settings {
  _sdkSetting = settings;
  [[FIRIAMRuntimeManager getSDKRuntimeInstance] startRuntimeWithSDKSettings:_sdkSetting];
}

+ (void)exitAppWithFatalError:(NSError *)error {
  [NSException raise:kFirebaseInAppMessagingErrorDomain
              format:@"Error happened %@", error.localizedDescription];
}

@end
