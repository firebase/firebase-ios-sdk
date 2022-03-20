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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckAvailability.h"

#if FIR_DEVICE_CHECK_SUPPORTED_TARGETS

#import <Foundation/Foundation.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProvider.h"

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/Backoff/FIRAppCheckBackoffWrapper.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/DCDevice+FIRDeviceCheckTokenGenerator.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRDeviceCheckProvider ()
@property(nonatomic, readonly) id<FIRDeviceCheckAPIServiceProtocol> APIService;
@property(nonatomic, readonly) id<FIRDeviceCheckTokenGenerator> deviceTokenGenerator;
@property(nonatomic, readonly) id<FIRAppCheckBackoffWrapperProtocol> backoffWrapper;

- (instancetype)initWithAPIService:(id<FIRDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<FIRDeviceCheckTokenGenerator>)deviceTokenGenerator
                    backoffWrapper:(id<FIRAppCheckBackoffWrapperProtocol>)backoffWrapper
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRDeviceCheckProvider

- (instancetype)initWithAPIService:(id<FIRDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<FIRDeviceCheckTokenGenerator>)deviceTokenGenerator
                    backoffWrapper:(id<FIRAppCheckBackoffWrapperProtocol>)backoffWrapper {
  self = [super init];
  if (self) {
    _APIService = APIService;
    _deviceTokenGenerator = deviceTokenGenerator;
    _backoffWrapper = backoffWrapper;
  }
  return self;
}

- (instancetype)initWithAPIService:(id<FIRDeviceCheckAPIServiceProtocol>)APIService {
  FIRAppCheckBackoffWrapper *backoffWrapper = [[FIRAppCheckBackoffWrapper alloc] init];
  return [self initWithAPIService:APIService
             deviceTokenGenerator:[DCDevice currentDevice]
                   backoffWrapper:backoffWrapper];
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  NSArray<NSString *> *missingOptionsFields =
      [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck,
                kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions,
                @"Cannot instantiate `FIRDeviceCheckProvider` for app: %@. The following "
                @"`FirebaseOptions` fields are missing: %@",
                app.name, [missingOptionsFields componentsJoinedByString:@", "]);
    return nil;
  }

  NSURLSession *URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];

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

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [self.backoffWrapper
      applyBackoffToOperation:^FBLPromise *_Nonnull {
        return [self getTokenPromise];
      }
                 errorHandler:[self.backoffWrapper defaultAppCheckProviderErrorHandler]]
      // Call the handler with either token or error.
      .then(^id(FIRAppCheckToken *appCheckToken) {
        handler(appCheckToken, nil);
        return nil;
      })
      .catch(^void(NSError *error) {
        handler(nil, error);
      });
}

- (FBLPromise<FIRAppCheckToken *> *)getTokenPromise {
  // Get DeviceCheck token
  return [self deviceToken]
      // Exchange DeviceCheck token for FAC token.
      .then(^FBLPromise<FIRAppCheckToken *> *(NSData *deviceToken) {
        return [self.APIService appCheckTokenWithDeviceToken:deviceToken];
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

#endif  // FIR_DEVICE_CHECK_SUPPORTED_TARGETS
