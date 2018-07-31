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

#import "FIRFunctions.h"
#import "FIRFunctions+Internal.h"

#import "FIRError.h"
#import "FIRHTTPSCallable+Internal.h"
#import "FIRHTTPSCallable.h"
#import "FUNContext.h"
#import "FUNError.h"
#import "FUNSerializer.h"
#import "FUNUsageValidation.h"

#import "FIRApp.h"
#import "FIRAppInternal.h"
#import "FIROptions.h"
#import "GTMSessionFetcherService.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const kFUNInstanceIDTokenHeader = @"Firebase-Instance-ID-Token";

@interface FIRFunctions () {
  // The network client to use for http requests.
  GTMSessionFetcherService *_fetcherService;
  // The projectID to use for all function references.
  FIRApp *_app;
  // The region to use for all function references.
  NSString *_region;
  // A serializer to encode/decode data and return values.
  FUNSerializer *_serializer;
  // A factory for getting the metadata to include with function calls.
  FUNContextProvider *_contextProvider;
  // For testing only. If this is set, functions will be called against it instead of Firebase.
  NSString *_emulatorOrigin;
}

/**
 * Initialize the Cloud Functions client with the given app and region.
 * @param app The app for the Firebase project.
 * @param region The region for the http trigger, such as "us-central1".
 */
- (id)initWithApp:(FIRApp *)app region:(NSString *)region NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRFunctions

+ (instancetype)functions {
  return [[self alloc] initWithApp:[FIRApp defaultApp] region:@"us-central1"];
}

+ (instancetype)functionsForApp:(FIRApp *)app {
  return [[self alloc] initWithApp:app region:@"us-central1"];
}

+ (instancetype)functionsForRegion:(NSString *)region {
  return [[self alloc] initWithApp:[FIRApp defaultApp] region:region];
}

+ (instancetype)functionsForApp:(FIRApp *)app region:(NSString *)region {
  return [[self alloc] initWithApp:app region:region];
}

- (instancetype)initWithApp:(FIRApp *)app region:(NSString *)region {
  self = [super init];
  if (self) {
    if (!region) {
      FUNThrowInvalidArgument(@"FIRFunctions region cannot be nil.");
    }
    _fetcherService = [[GTMSessionFetcherService alloc] init];
    _app = app;
    _region = [region copy];
    _serializer = [[FUNSerializer alloc] init];
    _contextProvider = [[FUNContextProvider alloc] initWithApp:app];
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
  NSString *projectID = _app.options.projectID;
  if (!projectID) {
    FUNThrowInvalidArgument(@"FIRFunctions app projectID cannot be nil.");
  }
  if (_emulatorOrigin) {
    return [NSString stringWithFormat:@"%@/%@/%@/%@", _emulatorOrigin, projectID, _region, name];
  }
  return
      [NSString stringWithFormat:@"https://%@-%@.cloudfunctions.net/%@", _region, projectID, name];
}

- (void)callFunction:(NSString *)name
          withObject:(nullable id)data
          completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                               NSError *_Nullable error))completion {
  [_contextProvider getContext:^(FUNContext *_Nullable context, NSError *_Nullable error) {
    if (error) {
      if (completion) {
        completion(nil, error);
      }
      return;
    }
    return [self callFunction:name withObject:data context:context completion:completion];
  }];
}

- (void)callFunction:(NSString *)name
          withObject:(nullable id)data
             context:(FUNContext *)context
          completion:(void (^)(FIRHTTPSCallableResult *_Nullable result,
                               NSError *_Nullable error))completion {
  GTMSessionFetcher *fetcher = [_fetcherService fetcherWithURLString:[self URLWithName:name]];

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
  if (context.instanceIDToken) {
    [fetcher setRequestValue:context.instanceIDToken forHTTPHeaderField:kFUNInstanceIDTokenHeader];
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
      NSDictionary *userInfo =
          @{NSLocalizedDescriptionKey : @"Response did not include data field."};
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
