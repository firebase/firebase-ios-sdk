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

#import "FIRMutableData.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used for `runTransactionBlock(_:)`. A `TransactionResult` instance is a
 * container for the results of the transaction.
 */
NS_SWIFT_NAME(TransactionResult)
@interface FIRTransactionResult : NSObject

/**
 * Used for `runTransactionBlock(_:)`. Indicates that the new value should be
 * saved at this location.
 *
 * @param value A `MutableData` instance containing the new value to be set
 * @return A `TransactionResult` instance that can be used as a return value
 *     from the block given to `runTransactionBlock(_:)`.
 */
+ (FIRTransactionResult *)successWithValue:(FIRMutableData *)value;

/**
 * Used for `runTransactionBlock(_:)`. Indicates that the current transaction
 * should no longer proceed.
 *
 * @return A `TransactionResult` instance that can be used as a return value
 * from the block given to `runTransactionBlock(_:)`
 */
+ (FIRTransactionResult *)abort;

@end

NS_ASSUME_NONNULL_END
