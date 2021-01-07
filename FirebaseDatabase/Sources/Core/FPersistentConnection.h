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

#import "FirebaseDatabase/Sources/Api/Private/FTypedefs_Private.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Realtime/FConnection.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"
#import <Foundation/Foundation.h>

@protocol FPersistentConnectionDelegate;
@protocol FSyncTreeHash;
@class FQuerySpec;
@class FIRDatabaseConfig;

@interface FPersistentConnection : NSObject <FConnectionDelegate>

@property(nonatomic, weak) id<FPersistentConnectionDelegate> delegate;
@property(nonatomic) BOOL pauseWrites;

- (id)initWithRepoInfo:(FRepoInfo *)repoInfo
         dispatchQueue:(dispatch_queue_t)queue
                config:(FIRDatabaseConfig *)config;

- (void)open;

- (void)putData:(id)data
         forPath:(NSString *)pathString
        withHash:(NSString *)hash
    withCallback:(fbt_void_nsstring_nsstring)onComplete;
- (void)mergeData:(id)data
          forPath:(NSString *)pathString
     withCallback:(fbt_void_nsstring_nsstring)onComplete;

- (void)listen:(FQuerySpec *)query
         tagId:(NSNumber *)tagId
          hash:(id<FSyncTreeHash>)hash
    onComplete:(fbt_void_nsstring)onComplete;

- (void)unlisten:(FQuerySpec *)query tagId:(NSNumber *)tagId;
- (void)refreshAuthToken:(NSString *)token;
- (void)onDisconnectPutData:(id)data
                    forPath:(FPath *)path
               withCallback:(fbt_void_nsstring_nsstring)callback;
- (void)onDisconnectMergeData:(id)data
                      forPath:(FPath *)path
                 withCallback:(fbt_void_nsstring_nsstring)callback;
- (void)onDisconnectCancelPath:(FPath *)path
                  withCallback:(fbt_void_nsstring_nsstring)callback;
- (void)ackPuts;
- (void)purgeOutstandingWrites;

- (void)interruptForReason:(NSString *)reason;
- (void)resumeForReason:(NSString *)reason;
- (BOOL)isInterruptedForReason:(NSString *)reason;

// FConnection delegate methods
- (void)onReady:(FConnection *)fconnection
         atTime:(NSNumber *)timestamp
      sessionID:(NSString *)sessionID;
- (void)onDataMessage:(FConnection *)fconnection
          withMessage:(NSDictionary *)message;
- (void)onDisconnect:(FConnection *)fconnection
          withReason:(FDisconnectReason)reason;
- (void)onKill:(FConnection *)fconnection withReason:(NSString *)reason;

// Testing methods
- (NSDictionary *)dumpListens;

@end

@protocol FPersistentConnectionDelegate <NSObject>

- (void)onDataUpdate:(FPersistentConnection *)fpconnection
             forPath:(NSString *)pathString
             message:(id)message
             isMerge:(BOOL)isMerge
               tagId:(NSNumber *)tagId;
- (void)onRangeMerge:(NSArray *)ranges
             forPath:(NSString *)path
               tagId:(NSNumber *)tag;
- (void)onConnect:(FPersistentConnection *)fpconnection;
- (void)onDisconnect:(FPersistentConnection *)fpconnection;
- (void)onServerInfoUpdate:(FPersistentConnection *)fpconnection
                   updates:(NSDictionary *)updates;

@end
