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

@class FIRMessagingPersistentSyncMessage;

/**
 * This manages the RMQ persistent store.
 *
 * The store is used to store all the S2D id's that were received by the client and were ACK'ed
 * by us but the server hasn't confirmed the ACK. We don't delete these id's until the server
 * ACK's us that they have received them.
 *
 * We also store the upstream messages(d2s) that were sent by the client.
 *
 * Also store the lastRMQId that was sent by us so that for a new connection being setup we don't
 * duplicate RMQ Id's for the new messages.
 */
@interface FIRMessagingRmqManager : NSObject
// designated initializer
- (instancetype)initWithDatabaseName:(NSString *)databaseName;

- (void)loadRmqId;

/**
 *  Save Server to device message with the given RMQ-ID.
 *
 *  @param rmqID The rmqID of the s2d message to save.
 *
 */
- (void)saveS2dMessageWithRmqId:(NSString *)rmqID;

#pragma mark - Sync Messages

/**
 *  Get persisted sync message with rmqID.
 *
 *  @param rmqID The rmqID of the persisted sync message.
 *
 *  @return A valid persistent sync message with the given rmqID if found in the RMQ else nil.
 */
- (FIRMessagingPersistentSyncMessage *)querySyncMessageWithRmqID:(NSString *)rmqID;

/**
 *  Delete the expired sync messages from persisten store. Also deletes messages that have been
 *  delivered both via APNS and MCS.
 */
- (void)deleteExpiredOrFinishedSyncMessages;

/**
 *  Save sync message received by the device.
 *
 *  @param rmqID          The rmqID of the message received.
 *  @param expirationTime The expiration time of the sync message received.
 *
 */
- (void)saveSyncMessageWithRmqID:(NSString *)rmqID expirationTime:(int64_t)expirationTime;

/**
 *  Update sync message received via APNS.
 *
 *  @param rmqID The rmqID of the received message.
 *
 */
- (void)updateSyncMessageViaAPNSWithRmqID:(NSString *)rmqID;

/**
 * Returns path for database with specified name.
 * @param databaseName The database name without extension: "<databaseName>.sqlite".
 * @returns Path to the database with the specified name.
 */
+ (NSString *)pathForDatabaseWithName:(NSString *)databaseName;

@end
