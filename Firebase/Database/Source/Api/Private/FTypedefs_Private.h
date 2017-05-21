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

#ifndef __FTYPEDEFS_PRIVATE__
#define __FTYPEDEFS_PRIVATE__

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, FTransactionStatus) {
    FTransactionInitializing,       // 0
    FTransactionRun,                // 1
    FTransactionSent,               // 2
    FTransactionCompleted,          // 3
    FTransactionSentNeedsAbort,     // 4
    FTransactionNeedsAbort          // 5
};

@protocol FNode;
@class FPath;
@class FIRTransactionResult;
@class FIRMutableData;
@class FIRDataSnapshot;
@class FCompoundHash;

typedef void (^fbt_void_nserror_bool_datasnapshot) (NSError* error, BOOL committed, FIRDataSnapshot * snapshot);
typedef FIRTransactionResult * (^fbt_transactionresult_mutabledata) (FIRMutableData * currentData);
typedef void (^fbt_void_path_node) (FPath*, id<FNode>);
typedef void (^fbt_void_nsstring) (NSString *);
typedef BOOL (^fbt_bool_nsstring_node) (NSString *, id<FNode>);
typedef void (^fbt_void_path_node_marray) (FPath *, id<FNode>, NSMutableArray *);
typedef BOOL (^fbt_bool_void) (void);
typedef void (^fbt_void_nsstring_nsstring)(NSString *str1, NSString* str2);
typedef void (^fbt_void_nsstring_nserror)(NSString *str, NSError* error);
typedef BOOL (^fbt_bool_path)(FPath *str);
typedef void (^fbt_void_id)(id data);
typedef NSString* (^fbt_nsstring_void) (void);
typedef FCompoundHash* (^fbt_compoundhash_void) (void);
typedef NSArray* (^fbt_nsarray_nsstring_id)(NSString *status, id Data);
typedef NSArray* (^fbt_nsarray_nsstring)(NSString *status);

// WWDC 2012 session 712 starting in page 83 for saving blocks in properties (use @property (strong) type name).

#endif
