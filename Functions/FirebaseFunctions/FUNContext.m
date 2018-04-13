//
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

#import "FUNContext.h"

#import "FIRApp.h"
#import "FIRAppInternal.h"
#import "FUNInstanceIDProxy.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUNContext ()

- (instancetype)initWithAuthToken:(NSString *_Nullable)authToken
                  instanceIDToken:(NSString *_Nullable)instanceIDToken NS_DESIGNATED_INITIALIZER;

@end

@implementation FUNContext

- (instancetype)initWithAuthToken:(NSString *_Nullable)authToken
                  instanceIDToken:(NSString *_Nullable)instanceIDToken {
  self = [super init];
  if (self) {
    _authToken = [authToken copy];
    _instanceIDToken = [instanceIDToken copy];
  }
  return self;
}

@end

@interface FUNContextProvider () {
  FIRApp *_app;
  FUNInstanceIDProxy *_instanceIDProxy;
}
@end

@implementation FUNContextProvider

- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
    _instanceIDProxy = [[FUNInstanceIDProxy alloc] init];
  }
  return self;
}

// This is broken out so it can be mocked for tests.
- (NSString *)instanceIDToken {
  return [_instanceIDProxy token];
}

- (void)getContext:(void (^)(FUNContext *_Nullable context, NSError *_Nullable error))completion {
  // Get the auth token.
  [_app getTokenForcingRefresh:NO
                  withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                    if (error) {
                      completion(nil, error);
                      return;
                    }

                    // Get the instance id token.
                    NSString *_Nullable instanceIDToken = [self instanceIDToken];

                    FUNContext *context = [[FUNContext alloc] initWithAuthToken:token
                                                                instanceIDToken:instanceIDToken];
                    completion(context, nil);
                  }];
}

@end

NS_ASSUME_NONNULL_END
