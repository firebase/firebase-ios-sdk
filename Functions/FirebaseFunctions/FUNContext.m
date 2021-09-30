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

#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Sources/Interop/FIRAppCheckTokenResultInterop.h"
#import "FirebaseMessaging/Sources/Interop/FIRMessagingInterop.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

NS_ASSUME_NONNULL_BEGIN

@interface FUNContext ()

- (instancetype)initWithAuthToken:(NSString *_Nullable)authToken
                         FCMToken:(NSString *_Nullable)FCMToken
                    appCheckToken:(NSString *_Nullable)appCheckToken NS_DESIGNATED_INITIALIZER;

@end

@implementation FUNContext

- (instancetype)initWithAuthToken:(NSString *_Nullable)authToken
                         FCMToken:(NSString *_Nullable)FCMToken
                    appCheckToken:(NSString *_Nullable)appCheckToken {
  self = [super init];
  if (self) {
    _authToken = [authToken copy];
    _FCMToken = [FCMToken copy];
    _appCheckToken = [appCheckToken copy];
  }
  return self;
}

@end

@interface FUNContextProvider () {
  id<FIRAuthInterop> _Nullable _auth;
  id<FIRMessagingInterop> _Nullable _messaging;
  id<FIRAppCheckInterop> _Nullable _appCheck;
}
@end

@implementation FUNContextProvider

- (instancetype)initWithAuth:(nullable id<FIRAuthInterop>)auth
                   messaging:(nullable id<FIRMessagingInterop>)messaging
                    appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
  self = [super init];
  if (self) {
    _auth = auth;
    _messaging = messaging;
    _appCheck = appCheck;
  }
  return self;
}

// This is broken out so it can be mocked for tests.
- (NSString *)FCMToken {
  return _messaging.FCMToken;
}

- (void)getContext:(void (^)(FUNContext *context, NSError *_Nullable error))completion {
  dispatch_group_t dispatchGroup = dispatch_group_create();

  // Try to get FCM token.
  NSString *FCMToken = [self FCMToken];

  __block NSString *authToken;
  __block NSString *appCheckToken;
  __block NSError *authError;

  // Fetch auth token if available.
  if (_auth != nil) {
    dispatch_group_enter(dispatchGroup);

    [_auth getTokenForcingRefresh:NO
                     withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                       authToken = token;
                       authError = error;

                       dispatch_group_leave(dispatchGroup);
                     }];
  }

  // Fetch FAC token if available.
  if (_appCheck) {
    dispatch_group_enter(dispatchGroup);

    [_appCheck getTokenForcingRefresh:NO
                           completion:^(id<FIRAppCheckTokenResultInterop> _Nonnull tokenResult) {
                             // Send only valid token to functions.
                             if (tokenResult.error == nil) {
                               appCheckToken = tokenResult.token;
                             }

                             dispatch_group_leave(dispatchGroup);
                           }];
  }

  dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
    FUNContext *context = [[FUNContext alloc] initWithAuthToken:authToken
                                                       FCMToken:FCMToken
                                                  appCheckToken:appCheckToken];

    if (completion) {
      completion(context, authError);
    }
  });
}

@end

NS_ASSUME_NONNULL_END
