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

#import "FirebaseDatabase/Sources/Core/FPersistentConnection.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDataEventType.h"
#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRDatabaseQuery.h"
#import "FirebaseDatabase/Sources/Utilities/Tuples/FTupleUserCallback.h"
#import <Foundation/Foundation.h>

@class FQuerySpec;
@class FPersistence;
@class FAuthenticationManager;
@class FIRDatabaseConfig;
@protocol FEventRegistration;
@class FCompoundWrite;
@protocol FClock;
@class FIRDatabase;

@interface FRepo : NSObject <FPersistentConnectionDelegate>

@property(nonatomic, strong) FIRDatabaseConfig *_Nullable config;

- (id _Nonnull)initWithRepoInfo:(FRepoInfo *_Nullable)info
                         config:(FIRDatabaseConfig *_Nullable)config
                       database:(FIRDatabase *_Nullable)database;

- (void)set:(FPath *_Nullable)path
        withNode:(id _Nullable)node
    withCallback:(fbt_void_nserror_ref _Nullable)onComplete;
- (void)update:(FPath *_Nullable)path
       withNodes:(FCompoundWrite *_Nullable)compoundWrite
    withCallback:(fbt_void_nserror_ref _Nullable)callback;
- (void)purgeOutstandingWrites;

- (void)getData:(FIRDatabaseQuery *_Nullable)query
    withCompletionBlock:
        (void (^_Nonnull)(NSError *_Nullable error,
                          FIRDataSnapshot *_Nullable snapshot))block;

- (void)addEventRegistration:(id<FEventRegistration> _Nullable)eventRegistration
                    forQuery:(FQuerySpec *_Nullable)query;
- (void)removeEventRegistration:
            (id<FEventRegistration> _Nullable)eventRegistration
                       forQuery:(FQuerySpec *_Nullable)query;
- (void)keepQuery:(FQuerySpec *_Nullable)query synced:(BOOL)synced;

- (NSString *_Nullable)name;
- (NSTimeInterval)serverTime;

- (void)onDataUpdate:(FPersistentConnection *_Nullable)fpconnection
             forPath:(NSString *_Nullable)pathString
             message:(id _Nullable)message
             isMerge:(BOOL)isMerge
               tagId:(NSNumber *_Nullable)tagId;
- (void)onConnect:(FPersistentConnection *_Nullable)fpconnection;
- (void)onDisconnect:(FPersistentConnection *_Nullable)fpconnection;

// Disconnect methods
- (void)onDisconnectCancel:(FPath *_Nullable)path
              withCallback:(fbt_void_nserror_ref _Nullable)callback;
- (void)onDisconnectSet:(FPath *_Nullable)path
               withNode:(id<FNode> _Nullable)node
           withCallback:(fbt_void_nserror_ref _Nullable)callback;
- (void)onDisconnectUpdate:(FPath *_Nullable)path
                 withNodes:(FCompoundWrite *_Nullable)compoundWrite
              withCallback:(fbt_void_nserror_ref _Nullable)callback;

// Connection Management.
- (void)interrupt;
- (void)resume;

// Transactions
- (void)startTransactionOnPath:(FPath *_Nullable)path
                        update:
                            (fbt_transactionresult_mutabledata _Nullable)update
                    onComplete:
                        (fbt_void_nserror_bool_datasnapshot _Nullable)onComplete
               withLocalEvents:(BOOL)applyLocally;

// Testing methods
- (NSDictionary *_Nullable)dumpListens;
- (void)dispose;
- (void)setHijackHash:(BOOL)hijack;

@property(nonatomic, strong, readonly) FAuthenticationManager *_Nullable auth;
@property(nonatomic, strong, readonly) FIRDatabase *_Nullable database;

@end
