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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckAvailability.h"

#if GAC_DEVICE_CHECK_SUPPORTED_TARGETS

#import <Foundation/Foundation.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "AppCheck/Sources/Public/AppCheck/GACDeviceCheckProvider.h"

#import "AppCheck/Sources/Core/APIService/GACAppCheckAPIService.h"
#import "AppCheck/Sources/Core/Backoff/GACAppCheckBackoffWrapper.h"
#import "AppCheck/Sources/Core/GACAppCheckLogger.h"
#import "AppCheck/Sources/DeviceCheckProvider/API/GACDeviceCheckAPIService.h"
#import "AppCheck/Sources/DeviceCheckProvider/DCDevice+GACDeviceCheckTokenGenerator.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckToken.h"

NS_ASSUME_NONNULL_BEGIN

@interface GACDeviceCheckProvider ()
@property(nonatomic, readonly) id<GACDeviceCheckAPIServiceProtocol> APIService;
@property(nonatomic, readonly) id<GACDeviceCheckTokenGenerator> deviceTokenGenerator;
@property(nonatomic, readonly) id<GACAppCheckBackoffWrapperProtocol> backoffWrapper;

- (instancetype)initWithAPIService:(id<GACDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<GACDeviceCheckTokenGenerator>)deviceTokenGenerator
                    backoffWrapper:(id<GACAppCheckBackoffWrapperProtocol>)backoffWrapper
    NS_DESIGNATED_INITIALIZER;

@end

@implementation GACDeviceCheckProvider

- (instancetype)initWithAPIService:(id<GACDeviceCheckAPIServiceProtocol>)APIService
              deviceTokenGenerator:(id<GACDeviceCheckTokenGenerator>)deviceTokenGenerator
                    backoffWrapper:(id<GACAppCheckBackoffWrapperProtocol>)backoffWrapper {
  self = [super init];
  if (self) {
    _APIService = APIService;
    _deviceTokenGenerator = deviceTokenGenerator;
    _backoffWrapper = backoffWrapper;
  }
  return self;
}

- (instancetype)initWithAPIService:(id<GACDeviceCheckAPIServiceProtocol>)APIService {
  GACAppCheckBackoffWrapper *backoffWrapper = [[GACAppCheckBackoffWrapper alloc] init];
  return [self initWithAPIService:APIService
             deviceTokenGenerator:[DCDevice currentDevice]
                   backoffWrapper:backoffWrapper];
}

- (instancetype)initWithStorageID:(NSString *)storageID
                     resourceName:(NSString *)resourceName
                           APIKey:(nullable NSString *)APIKey
                     requestHooks:(nullable NSArray<GACAppCheckAPIRequestHook> *)requestHooks {
  NSURLSession *URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];

  GACAppCheckAPIService *APIService =
      [[GACAppCheckAPIService alloc] initWithURLSession:URLSession
                                                 APIKey:APIKey
                                           requestHooks:requestHooks];

  GACDeviceCheckAPIService *deviceCheckAPIService =
      [[GACDeviceCheckAPIService alloc] initWithAPIService:APIService resourceName:resourceName];

  return [self initWithAPIService:deviceCheckAPIService];
}

#pragma mark - GACAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [self.backoffWrapper
      applyBackoffToOperation:^FBLPromise *_Nonnull {
        return [self getTokenPromise];
      }
                 errorHandler:[self.backoffWrapper defaultAppCheckProviderErrorHandler]]
      // Call the handler with either token or error.
      .then(^id(GACAppCheckToken *appCheckToken) {
        handler(appCheckToken, nil);
        return nil;
      })
      .catch(^void(NSError *error) {
        handler(nil, error);
      });
}

- (FBLPromise<GACAppCheckToken *> *)getTokenPromise {
  // Get DeviceCheck token
  return [self deviceToken]
      // Exchange DeviceCheck token for FAC token.
      .then(^FBLPromise<GACAppCheckToken *> *(NSData *deviceToken) {
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

#endif  // GAC_DEVICE_CHECK_SUPPORTED_TARGETS
