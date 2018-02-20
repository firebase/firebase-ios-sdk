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

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRApp;
@class FSTDispatchQueue;

#pragma mark - Typedefs

/**
 * `FSTVoidTokenErrorBlock` is a block that gets a token or an error.
 *
 * @param token An auth token, either valid or invalid when error occurred.
 * @param error The error if one occurred, or else `nil`.
 */
typedef void (^FSTVoidGetTokenResultBlock)(firebase::firestore::auth::Token token,
                                           NSError *_Nullable error);

/** Listener block notified with a User. */
typedef void (^FSTVoidUserBlock)(firebase::firestore::auth::User user);

#pragma mark - FSTCredentialsProvider

/** Provides methods for getting the uid and token for the current user and listen for changes. */
@protocol FSTCredentialsProvider <NSObject>

/** Requests token for the current user, optionally forcing a refreshed token to be fetched. */
- (void)getTokenForcingRefresh:(BOOL)forceRefresh completion:(FSTVoidGetTokenResultBlock)completion;

/**
 * A listener to be notified of user changes (sign-in / sign-out). It is immediately called once
 * with the initial user.
 *
 * Note that this block will be called back on an arbitrary thread that is not the normal Firestore
 * worker thread.
 */
@property(nonatomic, copy, nullable, readwrite) FSTVoidUserBlock userChangeListener;

@end

#pragma mark - FSTFirebaseCredentialsProvider

/**
 * `FSTFirebaseCredentialsProvider` uses Firebase Auth via `FIRApp` to get an auth token.
 *
 * NOTE: To simplify the implementation, it requires that you set `userChangeListener` with a
 * non-`nil` value no more than once and don't call `getTokenForcingRefresh:` after setting
 * it to `nil`.
 *
 * This class must be implemented in a thread-safe manner since it is accessed from the thread
 * backing our internal worker queue and the callbacks from FIRAuth will be executed on an
 * arbitrary different thread.
 */
@interface FSTFirebaseCredentialsProvider : NSObject <FSTCredentialsProvider>

/**
 * Initializes a new FSTFirebaseCredentialsProvider.
 *
 * @param app The Firebase app from which to get credentials.
 *
 * @return A new instance of FSTFirebaseCredentialsProvider.
 */
- (instancetype)initWithApp:(FIRApp *)app NS_DESIGNATED_INITIALIZER;

- (id)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
