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

#include "Firestore/core/src/firebase/firestore/model/types.h"

NS_ASSUME_NONNULL_BEGIN

@class FSTMaybeDocument;
@class FSTTransaction;

/** FSTBatchID is a locally assigned ID for a batch of mutations that have been applied. */
typedef firebase::firestore::model::BatchId FSTBatchID;

typedef firebase::firestore::model::TargetId FSTTargetID;

typedef int64_t FSTListenSequenceNumber;

typedef NSNumber FSTBoxedTargetID;

/**
 * FSTVoidBlock is a block that's called when a specific event happens but that otherwise has
 * no information associated with it.
 */
typedef void (^FSTVoidBlock)(void);

/**
 * FSTVoidErrorBlock is a block that gets an error, if one occurred.
 *
 * @param error The error if it occurred, or nil.
 */
typedef void (^FSTVoidErrorBlock)(NSError *_Nullable error);

/** FSTVoidIDErrorBlock is a block that takes an optional value and error. */
typedef void (^FSTVoidIDErrorBlock)(id _Nullable, NSError *_Nullable);

/**
 * FSTVoidMaybeDocumentErrorBlock is a block that gets either a list of documents or an error.
 *
 * @param documents The documents, if no error occurred, or nil.
 * @param error The error, if one occurred, or nil.
 */
typedef void (^FSTVoidMaybeDocumentArrayErrorBlock)(
    NSArray<FSTMaybeDocument *> *_Nullable documents, NSError *_Nullable error);

/**
 * FSTTransactionBlock is a block that wraps a user's transaction update block internally.
 *
 * @param transaction An object with methods for performing reads and writes within the
 *                    transaction.
 * @param completion To be called by the block once the user's code is finished.
 */
typedef void (^FSTTransactionBlock)(FSTTransaction *transaction,
                                    void (^completion)(id _Nullable, NSError *_Nullable));

/**
 * Describes the online state of the Firestore client. Note that this does not indicate whether
 * or not the remote store is trying to connect or not. This is primarily used by the View /
 * EventManager code to change their behavior while offline (e.g. get() calls shouldn't wait for
 * data from the server and snapshot events should set metadata.isFromCache=true).
 */
typedef NS_ENUM(NSUInteger, FSTOnlineState) {
  /**
   * The Firestore client is in an unknown online state. This means the client is either not
   * actively trying to establish a connection or it is currently trying to establish a connection,
   * but it has not succeeded or failed yet. Higher-level components should not operate in
   * offline mode.
   */
  FSTOnlineStateUnknown,

  /**
   * The client is connected and the connections are healthy. This state is reached after a
   * successful connection and there has been at least one successful message received from the
   * backends.
   */
  FSTOnlineStateOnline,

  /**
   * The client is either trying to establish a connection but failing, or it has been explicitly
   * marked offline via a call to `disableNetwork`. Higher-level components should operate in
   * offline mode.
   */
  FSTOnlineStateOffline
};

NS_ASSUME_NONNULL_END
