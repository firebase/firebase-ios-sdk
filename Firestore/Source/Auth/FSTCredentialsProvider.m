/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Auth/FSTCredentialsProvider.h"

#import <FirebaseAuth/FIRAuth.h>
#import <FirebaseAuth/FIRUser.h>
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIRAppInternal.h>
#import <GRPCClient/GRPCCall.h>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/Auth/FSTUser.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTGetTokenResult

@implementation FSTGetTokenResult
- (instancetype)initWithUser:(FSTUser *)user token:(NSString *_Nullable)token {
  if (self = [super init]) {
    _user = user;
    _token = token;
  }
  return self;
}
@end

#pragma mark - FSTFirebaseCredentialsProvider
// TODO(mikelehen): Currently, we have a strong dependency on FIRAuth but we should ideally use
// only internal APIs on FIRApp instead. However, currently the FIRApp internal APIs don't expose
// the uid of the current user and don't expose an auth state change listener. So we use FIRAuth.
@interface FSTFirebaseCredentialsProvider ()

@property(nonatomic, strong, readonly) FIRApp *app;
@property(nonatomic, strong, readonly) FIRAuth *auth;

/** Handle used to stop receiving auth changes once userChangeListener is removed. */
@property(nonatomic, strong, nullable, readwrite)
    FIRAuthStateDidChangeListenerHandle authListenerHandle;

/** The current user as reported to us via our AuthStateDidChangeListener. */
@property(nonatomic, strong, nonnull, readwrite) FSTUser *currentUser;

/**
 * Counter used to detect if the user changed while a -getTokenForcingRefresh: request was
 * outstanding.
 */
@property(nonatomic, assign, readwrite) int userCounter;

@end

@implementation FSTFirebaseCredentialsProvider {
  FSTVoidUserBlock _userChangeListener;
}

- (instancetype)initWithApp:(FIRApp *)app {
  self = [super init];
  if (self) {
    _app = app;
    _auth = [FIRAuth authWithApp:app];
    _currentUser = [[FSTUser alloc] initWithUID:self.auth.currentUser.uid];
    _userCounter = 0;

    // Register for user changes so that we can internally track the current user.
    FSTWeakify(self);
    _authListenerHandle = [self.auth addAuthStateDidChangeListener:^(FIRAuth *auth, FIRUser *user) {
      FSTStrongify(self);
      if (self) {
        @synchronized(self) {
          FSTUser *newUser = [[FSTUser alloc] initWithUID:user.uid];
          if (![newUser isEqual:self.currentUser]) {
            self.currentUser = newUser;
            self.userCounter++;
            FSTVoidUserBlock listenerBlock = self.userChangeListener;
            if (listenerBlock) {
              listenerBlock(self.currentUser);
            }
          }
        }
      }
    }];
  }
  return self;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh
                    completion:(FSTVoidGetTokenResultBlock)completion {
  FSTAssert(self.authListenerHandle, @"getToken cannot be called after listener removed.");

  // Take note of the current value of the userCounter so that this method can fail (with a
  // FIRFirestoreErrorCodeAborted error) if there is a user change while the request is outstanding.
  int initialUserCounter = self.userCounter;

  void (^getTokenCallback)(NSString *, NSError *) =
      ^(NSString *_Nullable token, NSError *_Nullable error) {
        @synchronized(self) {
          if (initialUserCounter != self.userCounter) {
            // Cancel the request since the user changed while the request was outstanding so the
            // response is likely for a previous user (which user, we can't be sure).
            NSDictionary *errorInfo = @{@"details" : @"getToken aborted due to user change."};
            NSError *cancelError = [NSError errorWithDomain:FIRFirestoreErrorDomain
                                                       code:FIRFirestoreErrorCodeAborted
                                                   userInfo:errorInfo];
            completion(nil, cancelError);
          } else {
            FSTGetTokenResult *result =
                [[FSTGetTokenResult alloc] initWithUser:self.currentUser token:token];
            completion(result, error);
          }
        };
      };

  [self.app getTokenForcingRefresh:forceRefresh withCallback:getTokenCallback];
}

- (void)setUserChangeListener:(nullable FSTVoidUserBlock)block {
  @synchronized(self) {
    if (block) {
      FSTAssert(!_userChangeListener, @"UserChangeListener set twice!");

      // Fire initial event.
      block(self.currentUser);
    } else {
      FSTAssert(self.authListenerHandle, @"UserChangeListener removed twice!");
      FSTAssert(_userChangeListener, @"UserChangeListener removed without being set!");
      [self.auth removeAuthStateDidChangeListener:self.authListenerHandle];

      self.authListenerHandle = nil;
    }
    _userChangeListener = block;
  }
}

- (nullable FSTVoidUserBlock)userChangeListener {
  @synchronized(self) {
    return _userChangeListener;
  }
}

@end

NS_ASSUME_NONNULL_END
