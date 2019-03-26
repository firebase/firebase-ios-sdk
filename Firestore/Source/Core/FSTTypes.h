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

#include <memory>

namespace firebase {
namespace firestore {
namespace core {

class Transaction;

}
}
}

NS_ASSUME_NONNULL_BEGIN

@class FSTMaybeDocument;

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
typedef void (^FSTTransactionBlock)(
    std::shared_ptr<firebase::firestore::core::Transaction> transaction,
    void (^completion)(id _Nullable, NSError *_Nullable));

NS_ASSUME_NONNULL_END
