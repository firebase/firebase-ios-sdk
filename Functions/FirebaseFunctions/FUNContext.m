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

#import "Functions/FirebaseFunctions/FUNContext.h"

#import "FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUNContext ()

- (instancetype)initWithAuthToken:(NSString *_Nullable)authToken
                         FCMToken:(NSString *_Nullable)FCMToken NS_DESIGNATED_INITIALIZER;

@end

@implementation FUNContext

- (instancetype)initWithAuthToken:(NSString *_Nullable)authToken
                         FCMToken:(NSString *_Nullable)FCMToken {
  self = [super init];
  if (self) {
    _authToken = [authToken copy];
    _FCMToken = [FCMToken copy];
  }
  return self;
}

@end

@interface FUNContextProvider () {
  id<FIRAuthInterop> _auth;
  id<FIRMessagingInterop> _messaging;
}
@end

@implementation FUNContextProvider

- (instancetype)initWithAuth:(nullable id<FIRAuthInterop>)auth
                   messaging:(nullable id<FIRMessagingInterop>)messaging {
  self = [super init];
  if (self) {
    _auth = auth;
    _messaging = messaging;
  }
  return self;
}

// This is broken out so it can be mocked for tests.
- (NSString *)FCMToken {
  return _messaging.FCMToken;
}

- (void)getContext:(void (^)(FUNContext *_Nullable context, NSError *_Nullable error))completion {
  // If auth isn't included, call the completion handler and return.
  if (_auth == nil) {
    // With no auth, just populate FCMToken and call the completion handler.
    NSString *FCMToken = [self FCMToken];
    FUNContext *context = [[FUNContext alloc] initWithAuthToken:nil FCMToken:FCMToken];
    completion(context, nil);
    return;
  }

  // Auth exists, get the auth token.
  [_auth getTokenForcingRefresh:NO
                   withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                     if (error) {
                       completion(nil, error);
                       return;
                     }

                     // Get the instance id token.
                     NSString *_Nullable FCMToken = [self FCMToken];

                     FUNContext *context = [[FUNContext alloc] initWithAuthToken:token
                                                                        FCMToken:FCMToken];
                     completion(context, nil);
                   }];
}

@end

NS_ASSUME_NONNULL_END
