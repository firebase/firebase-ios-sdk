// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

#import "FirebaseFunctions/Sources/FIRFunctions+Internal.h"
#import "FirebaseFunctions/Sources/Public/FirebaseFunctions/FIRFunctions.h"

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseFunctions/Sources/FIRFunctionsComponent.h"
#import "FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#import "FirebaseFunctions/Sources/FIRHTTPSCallable+Internal.h"
#import "FirebaseFunctions/Sources/FUNContext.h"
#import "FirebaseFunctions/Sources/FUNError.h"
#import "FirebaseFunctions/Sources/FUNSerializer.h"
#import "FirebaseFunctions/Sources/FUNUsageValidation.h"
#import "FirebaseFunctions/Sources/Public/FirebaseFunctions/FIRError.h"
#import "FirebaseFunctions/Sources/Public/FirebaseFunctions/FIRHTTPSCallable.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcherService.h>
#endif

NS_ASSUME_NONNULL_BEGIN

NSString *const kFUNAppCheckTokenHeader = @"X-Firebase-AppCheck";
NSString *const kFUNFCMTokenHeader = @"Firebase-Instance-ID-Token";
NSString *const kFUNDefaultRegion = @"us-central1";

@interface FIRFunctions () {
  // The network client to use for http requests.
  GTMSessionFetcherService *_fetcherService;
  // The projectID to use for all function references.
  NSString *_projectID;
  // The region to use for all function references.
  NSString *_region;
  // The custom domain to use for all functions references (optional).
  NSString *_customDomain;
  // A serializer to encode/decode data and return values.
  FUNSerializer *_serializer;
  // A factory for getting the metadata to include with function calls.
  FUNContextProvider *_contextProvider;
  // For testing only. If this is set, functions will be called against it instead of Firebase.
  NSString *_emulatorOrigin;
}

// Re-declare this initializer here in order to attribute it as the designated initializer.
- (instancetype)initWithProjectID:(NSString *)projectID
                           region:(NSString *)region
                     customDomain:(nullable NSString *)customDomain
                             auth:(nullable id<FIRAuthInterop>)auth
                        messaging:(nullable id<FIRMessagingInterop>)messaging
                         appCheck:(nullable id<FIRAppCheckInterop>)appCheck
                   fetcherService:(GTMSessionFetcherService *)fetcherService
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRFunctions

+ (instancetype)functions {
  return [self functionsForApp:[FIRApp defaultApp] region:kFUNDefaultRegion customDomain:nil];
}

+ (instancetype)functionsForApp:(FIRApp *)app {
  return [self functionsForApp:app region:kFUNDefaultRegion customDomain:nil];
}

+ (instancetype)functionsForRegion:(NSString *)region {
  return [self functionsForApp:[FIRApp defaultApp] region:region customDomain:nil];
}

+ (instancetype)functionsForCustomDomain:(NSString *)customDomain {
  return [self functionsForApp:[FIRApp defaultApp]
                        region:kFUNDefaultRegion
                  customDomain:customDomain];
}

+ (instancetype)functionsForApp:(FIRApp *)app region:(NSString *)region {
  return [self functionsForApp:app region:region customDomain:nil];
}

+ (instancetype)functionsForApp:(FIRApp *)app customDomain:(NSString *)customDomain {
  return [self functionsForApp:app region:kFUNDefaultRegion customDomain:customDomain];
}

+ (instancetype)functionsForApp:(FIRApp *)app
                         region:(NSString *)region
                   customDomain:(nullable NSString *)customDomain {
  id<FIRFunctionsProvider> provider = FIR_COMPONENT(FIRFunctionsProvider, app.container);
  return [provider functionsForApp:app region:region customDomain:customDomain type:[self class]];
}

- (instancetype)initWithApp:(FIRApp *)app
                     region:(NSString *)region
               customDomain:(nullable NSString *)customDomain {
  return [self initWithProjectID:app.options.projectID
                          region:region
                    customDomain:customDomain
                            auth:FIR_COMPONENT(FIRAuthInterop, app.container)
                       messaging:FIR_COMPONENT(FIRMessagingInterop, app.container)
                        appCheck:FIR_COMPONENT(FIRAppCheckInterop, app.container)];
}

- (instancetype)initWithProjectID:(NSString *)projectID
                           region:(NSString *)region
                     customDomain:(nullable NSString *)customDomain
                             auth:(nullable id<FIRAuthInterop>)auth
                        messaging:(nullable id<FIRMessagingInterop>)messaging
                         appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
  return [self initWithProjectID:projectID
                          region:region
                    customDomain:customDomain
                            auth:auth
                       messaging:messaging
                        appCheck:appCheck
                  fetcherService:[[GTMSessionFetcherService alloc] init]];
}

- (instancetype)initWithProjectID:(NSString *)projectID
                           region:(NSString *)region
                     customDomain:(nullable NSString *)customDomain
                             auth:(nullable id<FIRAuthInterop>)auth
                        messaging:(nullable id<FIRMessagingInterop>)messaging
                         appCheck:(nullable id<FIRAppCheckInterop>)appCheck
                   fetcherService:(GTMSessionFetcherService *)fetcherService {
  self = [super init];
  if (self) {
    if (!region) {
      FUNThrowInvalidArgument(@"FIRFunctions region cannot be nil.");
    }
    _fetcherService = fetcherService;
    _projectID = [projectID copy];
    _region = [region copy];
    _customDomain = [customDomain copy];
    _serializer = [[FUNSerializer alloc] init];
    _contextProvider = [[FUNContextProvider alloc] initWithAuth:auth
                                                      messaging:messaging
                                                       appCheck:appCheck];
    _emulatorOrigin = nil;
  }
  return self;
}

- (void)useLocalhost {
  [self useEmulatorWithHost:@"localhost" port:5005];
}

- (void)useEmulatorWithHost:(NSString *)host port:(NSInteger)port {
  NSAssert(host.length > 0, @"Cannot connect to nil or empty host");
  NSString *prefix = [host hasPrefix:@"http"] ? @"" : @"http://";
  NSString *origin = [NSString stringWithFormat:@"%@%@:%li", prefix, host, (long)port];
  _emulatorOrigin = origin;
}

- (void)useFunctionsEmulatorOrigin:(NSString *)origin {
  _emulatorOrigin = origin;
}

- (NSString *)URLWithName:(NSString *)name {
  if (!name) {
    FUNThrowInvalidArgument(@"FIRFunctions function name cannot be nil.");
  }
  if (!_projectID) {
    FUNThrowInvalidArgument(@"FIRFunctions app projectID cannot be nil.");
  }
  if (_emulatorOrigin) {
    return [NSString stringWithFormat:@"%@/%@/%@/%@", _emulatorOrigin, _projectID, _region, name];
  }
  if (_customDomain) {
    return [NSString stringWithFormat:@"%@/%@", _customDomain, name];
  }
  return
      [NSString stringWithFormat:@"https://%@-%@.cloudfunctions.net/%@", _region, _projectID, name];
}

- (void)callFunction:(NSString *)name
          withObject:(nullable id)data
             timeout:(NSTimeInterval)timeout
          completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                               NSError *_Nullable error))completion {
  [_contextProvider getContext:^(FUNContext *context, NSError *_Nullable error) {
    if (error) {
      if (completion) {
        completion(nil, error);
      }
      return;
    }
    return [self callFunction:name
                   withObject:data
                      timeout:timeout
                      context:context
                   completion:completion];
  }];
}

- (void)callFunction:(NSString *)name
          withObject:(nullable id)data
             timeout:(NSTimeInterval)timeout
             context:(FUNContext *)context
          completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                               NSError *_Nullable error))completion {
  NSURL *url = [NSURL URLWithString:[self URLWithName:name]];
  NSURLRequest *request = [NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                       timeoutInterval:timeout];
  GTMSessionFetcher *fetcher = [_fetcherService fetcherWithRequest:request];

  NSMutableDictionary *body = [NSMutableDictionary dictionary];
  // Encode the data in the body.
  if (!data) {
    data = [NSNull null];
  }
  id encoded = [_serializer encode:data];
  if (!encoded) {
    FUNThrowInvalidArgument(@"FIRFunctions data encoded as nil. This should not happen.");
  }
  body[@"data"] = encoded;

  NSError *error = nil;
  NSData *payload = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
  if (error) {
    if (completion) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, error);
      });
    }
    return;
  }
  fetcher.bodyData = payload;

  // Set the headers.
  [fetcher setRequestValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  if (context.authToken) {
    NSString *value = [NSString stringWithFormat:@"Bearer %@", context.authToken];
    [fetcher setRequestValue:value forHTTPHeaderField:@"Authorization"];
  }
  if (context.FCMToken) {
    [fetcher setRequestValue:context.FCMToken forHTTPHeaderField:kFUNFCMTokenHeader];
  }
  if (context.appCheckToken) {
    [fetcher setRequestValue:context.appCheckToken forHTTPHeaderField:kFUNAppCheckTokenHeader];
  }

  // Override normal security rules if this is a local test.
  if (_emulatorOrigin) {
    fetcher.allowLocalhostRequest = YES;
    fetcher.allowedInsecureSchemes = @[ @"http" ];
  }

  FUNSerializer *serializer = _serializer;
  [fetcher beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
    // If there was an HTTP error, convert it to our own error domain.
    if (error) {
      if ([error.domain isEqualToString:kGTMSessionFetcherStatusDomain]) {
        error = FUNErrorForResponse(error.code, data, serializer);
      }
      if ([error.domain isEqualToString:NSURLErrorDomain]) {
        if (error.code == NSURLErrorTimedOut) {
          error = FUNErrorForCode(FIRFunctionsErrorCodeDeadlineExceeded);
        }
      }
    } else {
      // If there wasn't an HTTP error, see if there was an error in the body.
      error = FUNErrorForResponse(200, data, serializer);
    }
    // If there was an error, report it to the user and stop.
    if (error) {
      if (completion) {
        completion(nil, error);
      }
      return;
    }

    id responseJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
      if (completion) {
        completion(nil, error);
      }
      return;
    }
    if (![responseJSON isKindOfClass:[NSDictionary class]]) {
      NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Response was not a dictionary."};
      error = [NSError errorWithDomain:FIRFunctionsErrorDomain
                                  code:FIRFunctionsErrorCodeInternal
                              userInfo:userInfo];
      if (completion) {
        completion(nil, error);
      }
      return;
    }
    id dataJSON = responseJSON[@"data"];
    // TODO(klimt): Allow "result" instead of "data" for now, for backwards compatibility.
    if (!dataJSON) {
      dataJSON = responseJSON[@"result"];
    }
    if (!dataJSON) {
      NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Response is missing data field."};
      error = [NSError errorWithDomain:FIRFunctionsErrorDomain
                                  code:FIRFunctionsErrorCodeInternal
                              userInfo:userInfo];
      if (completion) {
        completion(nil, error);
      }
      return;
    }
    id resultData = [serializer decode:dataJSON error:&error];
    if (error) {
      if (completion) {
        completion(nil, error);
      }
      return;
    }
    id result = [[FIRHTTPSCallableResult alloc] initWithData:resultData];
    if (completion) {
      // If there's no result field, this will return nil, which is fine.
      completion(result, nil);
    }
  }];
}

- (FIRHTTPSCallable *)HTTPSCallableWithName:(NSString *)name {
  return [[FIRHTTPSCallable alloc] initWithFunctions:self name:name];
}

- (nullable NSString *)emulatorOrigin {
  return _emulatorOrigin;
}

- (nullable NSString *)customDomain {
  return _customDomain;
}

- (NSString *)region {
  return _region;
}

@end

NS_ASSUME_NONNULL_END
