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
#import "FPath.h"
#import "FTypedefs_Private.h"
#import "FTypedefs.h"

@interface FTupleTransaction : NSObject

@property (nonatomic, strong) FPath* path;
@property (nonatomic, copy) fbt_transactionresult_mutabledata update;
@property (nonatomic, copy) fbt_void_nserror_bool_datasnapshot onComplete;
@property (nonatomic) FTransactionStatus status;

/**
* Used when combining transaction at different locations to figure out which one goes first.
*/
@property (nonatomic, strong) NSNumber* order;
/**
* Whether to raise local events for this transaction
*/
@property (nonatomic) BOOL applyLocally;

/**
* Count how many times we've retried the transaction
*/
@property (nonatomic) int retryCount;

/**
* Function to call to clean up our listener
*/
@property (nonatomic, copy) fbt_void_void unwatcher;

/**
* Stores why a transaction was aborted
*/
@property (nonatomic, strong, readonly) NSString* abortStatus;
@property (nonatomic, strong, readonly) NSString* abortReason;

- (void)setAbortStatus:(NSString *)abortStatus reason:(NSString *)reason;
- (NSError *)abortError;

@property (nonatomic, strong) NSNumber *currentWriteId;

/**
* Stores the input snapshot, before the update
*/
@property (nonatomic, strong) id<FNode> currentInputSnapshot;

/**
* Stores the unresolved (for server values) output snapshot, after the update
*/
@property (nonatomic, strong) id<FNode> currentOutputSnapshotRaw;

/**
 * Stores the resolved (for server values) output snapshot, after the update
 */
@property (nonatomic, strong) id<FNode> currentOutputSnapshotResolved;

@end
