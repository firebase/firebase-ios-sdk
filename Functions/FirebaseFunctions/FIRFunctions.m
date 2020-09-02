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

#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRFunctions.h"
#import "Functions/FirebaseFunctions/FIRFunctions+Internal.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#import "Functions/FirebaseFunctions/FIRHTTPSCallable+Internal.h"
#import "Functions/FirebaseFunctions/FUNContext.h"
#import "Functions/FirebaseFunctions/FUNError.h"
#import "Functions/FirebaseFunctions/FUNSerializer.h"
#import "Functions/FirebaseFunctions/FUNUsageValidation.h"
#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRError.h"
#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRHTTPSCallable.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionFetcherService.h>
#endif

// The following two macros supply the incantation so that the C
// preprocessor does not try to parse the version as a floating
// point number. See
// https://www.guyrutenberg.com/2008/12/20/expanding-macros-into-string-constants-in-c/
#define STR(x) STR_EXPAND(x)
#define STR_EXPAND(x) #x

NS_ASSUME_NONNULL_BEGIN

NSString *const kFUNFCMTokenHeader = @"Firebase-Instance-ID-Token";
NSString *const kFUNDefaultRegion = @"us-central1";

/// Empty protocol to register Functions as a component with Core.
@protocol FIRFunctionsInstanceProvider
@end

@interface FIRFunctions () <FIRLibrary, FIRFunctionsInstanceProvider> {
  // The network client to use for http requests.
  GTMSessionFetcherService *_fetcherService;
  // The projectID to use for all function references.
  NSString *_projectID;
  // The region to use for all function references.
  NSString *_region;
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
                             auth:(nullable id<FIRAuthInterop>)auth
                        messaging:(nullable id<FIRMessagingInterop>)messaging
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRFunctions

+ (void)load {
  NSString *version = [NSString stringWithUTF8String:(const char *const)STR(FIRFunctions_VERSION)];
  [FIRApp registerInternalLibrary:(Class<FIRLibrary>)self withName:@"fire-fun" withVersion:version];
}

+ (NSArray<FIRComponent *> *)componentsToRegister {
  FIRComponentCreationBlock creationBlock =
      ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
    *isCacheable = YES;
    return [self functionsForApp:container.app];
  };
  FIRDependency *auth = [FIRDependency dependencyWithProtocol:@protocol(FIRAuthInterop)
                                                   isRequired:NO];
  FIRComponent *internalProvider =
      [FIRComponent componentWithProtocol:@protocol(FIRFunctionsInstanceProvider)
                      instantiationTiming:FIRInstantiationTimingLazy
                             dependencies:@[ auth ]
                            creationBlock:creationBlock];
  return @[ internalProvider ];
}

+ (instancetype)functions {
  return [[self alloc] initWithApp:[FIRApp defaultApp] region:kFUNDefaultRegion];
}

+ (instancetype)functionsForApp:(FIRApp *)app {
  return [[self alloc] initWithApp:app region:kFUNDefaultRegion];
}

+ (instancetype)functionsForRegion:(NSString *)region {
  return [[self alloc] initWithApp:[FIRApp defaultApp] region:region];
}

+ (instancetype)functionsForApp:(FIRApp *)app region:(NSString *)region {
  return [[self alloc] initWithApp:app region:region];
}

- (instancetype)initWithApp:(FIRApp *)app region:(NSString *)region {
  return [self initWithProjectID:app.options.projectID
                          region:region
                            auth:FIR_COMPONENT(FIRAuthInterop, app.container)
                       messaging:FIR_COMPONENT(FIRMessagingInterop, app.container)];
}

- (instancetype)initWithProjectID:(NSString *)projectID
                           region:(NSString *)region
                             auth:(nullable id<FIRAuthInterop>)auth
                        messaging:(nullable id<FIRMessagingInterop>)messaging {
  self = [super init];
  if (self) {
    if (!region) {
      FUNThrowInvalidArgument(@"FIRFunctions region cannot be nil.");
    }
    _fetcherService = [[GTMSessionFetcherService alloc] init];
    _projectID = [projectID copy];
    _region = [region copy];
    _serializer = [[FUNSerializer alloc] init];
    _contextProvider = [[FUNContextProvider alloc] initWithAuth:auth messaging:messaging];
    _emulatorOrigin = nil;
  }
  return self;
}

- (void)useLocalhost {
  [self useFunctionsEmulatorOrigin:@"http://localhost:5005"];
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
  return
      [NSString stringWithFormat:@"https://%@-%@.cloudfunctions.net/%@", _region, _projectID, name];
}

- (void)callFunction:(NSString *)name
          withObject:(nullable id)data
             timeout:(NSTimeInterval)timeout
          completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                               NSError *_Nullable error))completion {
  [_contextProvider getContext:^(FUNContext *_Nullable context, NSError *_Nullable error) {
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

@end

NS_ASSUME_NONNULL_END
