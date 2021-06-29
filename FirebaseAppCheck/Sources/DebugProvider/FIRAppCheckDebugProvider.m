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

#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProvider.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"
#import "FirebaseAppCheck/Sources/DebugProvider/API/FIRAppCheckDebugProviderAPIService.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kDebugTokenEnvKey = @"FIRAAppCheckDebugToken";
static NSString *const kDebugTokenUserDefaultsKey = @"FIRAAppCheckDebugToken";

@interface FIRAppCheckDebugProvider ()
@property(nonatomic, readonly) id<FIRAppCheckDebugProviderAPIServiceProtocol> APIService;
@end

@implementation FIRAppCheckDebugProvider

- (instancetype)initWithAPIService:(id<FIRAppCheckDebugProviderAPIServiceProtocol>)APIService {
  self = [super init];
  if (self) {
    _APIService = APIService;
  }
  return self;
}

- (nullable instancetype)initWithApp:(FIRApp *)app {
  NSArray<NSString *> *missingOptionsFields =
      [FIRAppCheckValidator tokenExchangeMissingFieldsInOptions:app.options];
  if (missingOptionsFields.count > 0) {
    FIRLogError(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions,
                @"Cannot instantiate `FIRAppCheckDebugProvider` for app: %@. The following "
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

  FIRAppCheckDebugProviderAPIService *debugAPIService =
      [[FIRAppCheckDebugProviderAPIService alloc] initWithAPIService:APIService
                                                           projectID:app.options.projectID
                                                               appID:app.options.googleAppID];

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

#pragma mark - FIRAppCheckProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable token,
                                         NSError *_Nullable error))handler {
  [FBLPromise do:^NSString * {
    return [self currentDebugToken];
  }]
      .then(^FBLPromise<FIRAppCheckToken *> *(NSString *debugToken) {
        return [self.APIService appCheckTokenWithDebugToken:debugToken];
      })
      .then(^id(FIRAppCheckToken *appCheckToken) {
        handler(appCheckToken, nil);
        return nil;
      })
      .catch(^void(NSError *error) {
        FIRAppCheckDebugLog(kFIRLoggerAppCheckMessageDebugProviderFailedExchange,
                            @"Failed to exchange debug token to app check token: %@", error);
        handler(nil, error);
      });
}

@end

NS_ASSUME_NONNULL_END
