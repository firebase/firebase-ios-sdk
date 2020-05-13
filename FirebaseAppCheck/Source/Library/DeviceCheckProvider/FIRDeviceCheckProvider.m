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

#import <FirebaseAppCheck/FIRDeviceCheckProvider.h>

#import "DCDevice+FIRDeviceCheckTokenGenerator.h"
#import "FIRAppCheckToken.h"
#import "FIRDeviceCheckAPIService.h"

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

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(nonnull FIRAppCheckTokenHandler)handler {
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
