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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckDebugProvider.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "AppCheck/Sources/Core/APIService/GACAppCheckAPIService.h"
#import "AppCheck/Sources/Core/GACAppCheckLogger.h"
#import "AppCheck/Sources/DebugProvider/API/GACAppCheckDebugProviderAPIService.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckErrors.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckToken.h"

NS_ASSUME_NONNULL_BEGIN

// TODO(andrewheard): Parameterize the following Firebase-specific keys.
// FIREBASE_APP_CHECK_ONLY_BEGIN
static NSString *const kDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"FIRAAppCheckDebugToken";
// FIREBASE_APP_CHECK_ONLY_END

@interface GACAppCheckDebugProvider ()
@property(nonatomic, readonly) id<GACAppCheckDebugProviderAPIServiceProtocol> APIService;
@end

@implementation GACAppCheckDebugProvider

- (instancetype)initWithAPIService:(id<GACAppCheckDebugProviderAPIServiceProtocol>)APIService {
  self = [super init];
  if (self) {
    _APIService = APIService;
  }
  return self;
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

  GACAppCheckDebugProviderAPIService *debugAPIService =
      [[GACAppCheckDebugProviderAPIService alloc] initWithAPIService:APIService
                                                        resourceName:resourceName];

  return [self initWithAPIService:debugAPIService];
}

- (NSString *)currentDebugToken {
  NSString *envVariableValue = [[NSProcessInfo processInfo] environment][kDebugTokenEnvKey];
  if (envVariableValue.length > 0) {
    return envVariableValue;
  } else {
    return [self localDebugToken];
  }
}

- (NSString *)localDebugToken {
  return [self storedDebugToken] ?: [self generateAndStoreDebugToken];
}

- (nullable NSString *)storedDebugToken {
  return [[NSUserDefaults standardUserDefaults] stringForKey:kDebugTokenUserDefaultsKey];
}

- (void)storeDebugToken:(nullable NSString *)token {
  [[NSUserDefaults standardUserDefaults] setObject:token forKey:kDebugTokenUserDefaultsKey];
}

- (NSString *)generateAndStoreDebugToken {
  NSString *token = [NSUUID UUID].UUIDString;
  [self storeDebugToken:token];
  return token;
}

#pragma mark - GACAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(GACAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [FBLPromise do:^NSString * {
    return [self currentDebugToken];
  }]
      .then(^FBLPromise<GACAppCheckToken *> *(NSString *debugToken) {
        return [self.APIService appCheckTokenWithDebugToken:debugToken];
      })
      .then(^id(GACAppCheckToken *appCheckToken) {
        handler(appCheckToken, nil);
        return nil;
      })
      .catch(^void(NSError *error) {
        GACLogDebug(kGACLoggerAppCheckMessageDebugProviderFailedExchange,
                    @"Failed to exchange debug token to app check token: %@", error);
        handler(nil, error);
      });
}

@end

NS_ASSUME_NONNULL_END
