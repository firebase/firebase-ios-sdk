/*
 * Copyright 2020 Google LLC
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

#import <Foundation/Foundation.h>

#import <DeviceCheck/DeviceCheck.h>

#import <FBLPromises/FBLPromises.h>

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckVersion.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/DCDevice+FIRDeviceCheckTokenGenerator.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDeviceCheckProvider ()
@property(nonatomic, readonly) id<FIRDeviceCheckAPIServiceProtocol> APIService;
@property(nonatomic, readonly) id<FIRDeviceCheckTokenGenerator> deviceTokenGenerator;
@end

@implementation FIRDeviceCheckProvider

- (instancetype)initWithAPIService:(id<FIRDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<FIRDeviceCheckTokenGenerator>)deviceTokenGenerator {
  self = [super init];
  if (self) {
    _APIService = APIService;
    _deviceTokenGenerator = deviceTokenGenerator;
  }
  return self;
}

- (instancetype)initWithAPIService:(id<FIRDeviceCheckAPIServiceProtocol>)APIService {
  return [self initWithAPIService:APIService deviceTokenGenerator:[DCDevice currentDevice]];
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  NSArray<NSString *> *missingOptionsFields = [[self class] missingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeUnknown,
                @"Cannot instantiate `FIRDeviceCheckProvider` for app: %@. The following "
                @"`FirebaseOptions` fields are missing: %@",
                app.name, [missingOptionsFields componentsJoinedByString:@", "]);
    return nil;
  }

  NSURLSession *URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

  FIRAppCheckAPIService *APIService =
      [[FIRAppCheckAPIService alloc] initWithURLSession:URLSession
                                                 APIKey:app.options.APIKey
                                              projectID:app.options.projectID
                                                  appID:app.options.googleAppID];

  FIRDeviceCheckAPIService *deviceCheckAPIService =
      [[FIRDeviceCheckAPIService alloc] initWithAPIService:APIService
                                                 projectID:app.options.projectID
                                                     appID:app.options.googleAppID];

  return [self initWithAPIService:deviceCheckAPIService];
}

+ (NSArray<NSString *> *)missingFieldsInOptions:(FIROptions *)options {
  NSMutableArray<NSString *> *missingFields = [NSMutableArray array];

  if (options.APIKey.length < 1) {
    [missingFields addObject:@"APIKey"];
  }

  if (options.projectID.length < 1) {
    [missingFields addObject:@"projectID"];
  }

  if (options.googleAppID.length < 1) {
    [missingFields addObject:@"googleAppID"];
  }

  return [missingFields copy];
}

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(FIRAppCheckTokenHandler)handler {
  [self deviceToken]
      .then(^FBLPromise<FIRAppCheckToken *> *(NSData *deviceToken) {
        return [self.APIService appCheckTokenWithDeviceToken:deviceToken];
      })
      .then(^id(FIRAppCheckToken *appCheckToken) {
        handler(appCheckToken, nil);
        return nil;
      })
      .recover(^id(NSError *error) {
        // TODO: Handle errors.
        NSLog(@"Error: %@", error);
        return error;
      })
      .catch(^void(NSError *error) {
        handler(nil, error);
      });
}

#pragma mark - DeviceCheck

- (FBLPromise<NSData *> *)deviceToken {
  return [FBLPromise
      wrapObjectOrErrorCompletion:^(FBLPromiseObjectOrErrorCompletion _Nonnull handler) {
        [self.deviceTokenGenerator generateTokenWithCompletionHandler:handler];
      }];
}

@end

NS_ASSUME_NONNULL_END
