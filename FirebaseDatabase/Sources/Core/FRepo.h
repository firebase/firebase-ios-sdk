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

@property(nonatomic, strong) FIRDatabaseConfig *config;

- (id)initWithRepoInfo:(FRepoInfo *)info
                config:(FIRDatabaseConfig *)config
              database:(FIRDatabase *)database;

- (void)set:(FPath *)path
        withNode:(id)node
    withCallback:(fbt_void_nserror_ref)onComplete;
- (void)update:(FPath *)path
       withNodes:(FCompoundWrite *)compoundWrite
    withCallback:(fbt_void_nserror_ref)callback;
- (void)purgeOutstandingWrites;

- (void)addEventRegistration:(id<FEventRegistration>)eventRegistration
                    forQuery:(FQuerySpec *)query;
- (void)removeEventRegistration:(id<FEventRegistration>)eventRegistration
                       forQuery:(FQuerySpec *)query;
- (void)keepQuery:(FQuerySpec *)query synced:(BOOL)synced;

- (NSString *)name;
- (NSTimeInterval)serverTime;

- (void)onDataUpdate:(FPersistentConnection *)fpconnection
             forPath:(NSString *)pathString
             message:(id)message
             isMerge:(BOOL)isMerge
               tagId:(NSNumber *)tagId;
- (void)onConnect:(FPersistentConnection *)fpconnection;
- (void)onDisconnect:(FPersistentConnection *)fpconnection;

// Disconnect methods
- (void)onDisconnectCancel:(FPath *)path
              withCallback:(fbt_void_nserror_ref)callback;
- (void)onDisconnectSet:(FPath *)path
               withNode:(id<FNode>)node
           withCallback:(fbt_void_nserror_ref)callback;
- (void)onDisconnectUpdate:(FPath *)path
                 withNodes:(FCompoundWrite *)compoundWrite
              withCallback:(fbt_void_nserror_ref)callback;

// Connection Management.
- (void)interrupt;
- (void)resume;

// Transactions
- (void)startTransactionOnPath:(FPath *)path
                        update:(fbt_transactionresult_mutabledata)update
                    onComplete:(fbt_void_nserror_bool_datasnapshot)onComplete
               withLocalEvents:(BOOL)applyLocally;

// Testing methods
- (NSDictionary *)dumpListens;
- (void)dispose;
- (void)setHijackHash:(BOOL)hijack;

@property(nonatomic, strong, readonly) FAuthenticationManager *auth;
@property(nonatomic, strong, readonly) FIRDatabase *database;

@end
