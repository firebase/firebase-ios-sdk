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

#import "FirebaseStorageInternal/Sources/FIRStorageTokenAuthorizer.h"

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorage.h"
#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageConstants.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageErrors.h"
#import "FirebaseStorageInternal/Sources/FIRStorageLogger.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import "FirebaseAppCheck/Interop/FIRAppCheckInterop.h"
#import "FirebaseAppCheck/Interop/FIRAppCheckTokenResultInterop.h"
#import "FirebaseAuth/Interop/FIRAuthInterop.h"

static NSString *const kAppCheckTokenHeader = @"X-Firebase-AppCheck";
static NSString *const kAuthHeader = @"Authorization";

@implementation FIRStorageTokenAuthorizer {
 @private
  /// Google App ID to pass along with each request.
  NSString *_googleAppID;

  /// Auth provider.
  id<FIRAuthInterop> _auth;
  id<FIRAppCheckInterop> _appCheck;
}

@synthesize fetcherService = _fetcherService;

- (instancetype)initWithGoogleAppID:(NSString *)googleAppID
                     fetcherService:(GTMSessionFetcherService *)service
                       authProvider:(nullable id<FIRAuthInterop>)auth
                           appCheck:(nullable id<FIRAppCheckInterop>)appCheck {
  self = [super init];
  if (self) {
    _googleAppID = googleAppID;
    _fetcherService = service;
    _auth = auth;
    _appCheck = appCheck;
  }
  return self;
}

#pragma mark - GTMFetcherAuthorizationProtocol methods

- (void)authorizeRequest:(NSMutableURLRequest *)request
                delegate:(id)delegate
       didFinishSelector:(SEL)sel {
  // Set version header on each request
  NSString *versionString = [NSString stringWithFormat:@"ios/%@", FIRFirebaseVersion()];
  [request setValue:versionString forHTTPHeaderField:@"x-firebase-storage-version"];

  // Set GMP ID on each request
  [request setValue:_googleAppID forHTTPHeaderField:@"x-firebase-gmpid"];

  if (delegate && sel) {
    id selfParam = self;
    NSMethodSignature *sig = [delegate methodSignatureForSelector:sel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setSelector:sel];
    [invocation setTarget:delegate];
    [invocation setArgument:&selfParam atIndex:2];
    [invocation setArgument:&request atIndex:3];

    dispatch_queue_t callbackQueue = self.fetcherService.callbackQueue;
    if (!callbackQueue) {
      callbackQueue = dispatch_get_main_queue();
    }

    [invocation retainArguments];

    dispatch_group_t fetchTokenGroup = dispatch_group_create();

    if (_auth) {
      dispatch_group_enter(fetchTokenGroup);

      [_auth getTokenForcingRefresh:NO
                       withCallback:^(NSString *_Nullable token, NSError *_Nullable error) {
                         if (error) {
                           NSMutableDictionary *errorDictionary =
                               [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                           errorDictionary[kFIRStorageResponseErrorDomain] = error.domain;
                           errorDictionary[kFIRStorageResponseErrorCode] = @(error.code);

                           NSError *tokenError = [FIRStorageErrors
                                errorWithCode:FIRIMPLStorageErrorCodeUnauthenticated
                               infoDictionary:errorDictionary];
                           [invocation setArgument:&tokenError atIndex:4];
                         } else if (token) {
                           NSString *firebaseToken =
                               [NSString stringWithFormat:kFIRStorageAuthTokenFormat, token];
                           [request setValue:firebaseToken forHTTPHeaderField:kAuthHeader];
                         }

                         dispatch_group_leave(fetchTokenGroup);
                       }];
    }

    if (_appCheck) {
      dispatch_group_enter(fetchTokenGroup);

      [_appCheck getTokenForcingRefresh:NO
                             completion:^(id<FIRAppCheckTokenResultInterop> tokenResult) {
                               [request setValue:tokenResult.token
                                   forHTTPHeaderField:kAppCheckTokenHeader];

                               if (tokenResult.error) {
                                 FIRLogDebug(kFIRLoggerStorage, kFIRStorageMessageCodeAppCheckError,
                                             @"Failed to fetch AppCheck token. Error: %@",
                                             tokenResult.error);
                               }

                               dispatch_group_leave(fetchTokenGroup);
                             }];
    }

    dispatch_group_notify(fetchTokenGroup, callbackQueue, ^{
      [invocation invoke];
    });
  }
}

// Note that stopAuthorization, isAuthorizingRequest, and userEmail
// aren't relevant with the Firebase App/Auth implementation of tokens,
// and thus aren't implemented. Token refresh is handled transparently
// for us, and we don't allow the auth request to be stopped.
// Auth is also not required so the world doesn't stop.
- (void)stopAuthorization {
  // Noop
}

- (void)stopAuthorizationForRequest:(NSURLRequest *)request {
  // Noop
}

- (BOOL)isAuthorizingRequest:(NSURLRequest *)request {
  return NO;
}

- (BOOL)isAuthorizedRequest:(NSURLRequest *)request {
  NSString *authHeader = request.allHTTPHeaderFields[@"Authorization"];
  BOOL isFirebaseToken = [authHeader hasPrefix:@"Firebase"];
  return isFirebaseToken;
}

- (NSString *)userEmail {
  // Noop
  return nil;
}

@end
