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

@class GtalkDataMessageStanza;
@class GPBMessage;

@class FIRMessagingPersistentSyncMessage;

/**
 * Called on each raw message.
 */
typedef void(^FIRMessagingRmqMessageHandler)(int64_t rmqId, int8_t tag, NSData *data);

/**
 * Called on each DataMessageStanza.
 */
typedef void(^FIRMessagingDataMessageHandler)(int64_t rmqId, GtalkDataMessageStanza *stanza);

/**
 *  Used to scan through the rmq and perform actions on messages as required.
 */
@protocol FIRMessagingRmqScanner <NSObject>

/**
 *  Scan the RMQ for outgoing messages and process them as required.
 */
- (void)scanWithRmqMessageHandler:(FIRMessagingRmqMessageHandler)rmqMessageHandler
               dataMessageHandler:(FIRMessagingDataMessageHandler)dataMessageHandler;

@end

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
@interface FIRMessagingRmqManager : NSObject <FIRMessagingRmqScanner>

// designated initializer
- (instancetype)initWithDatabaseName:(NSString *)databaseName;

- (void)loadRmqId;

/**
 *  Save an upstream message to RMQ. If the message send fails for some reason we would not
 *  lose the message since it would be saved in the RMQ.
 *
 *  @param message The upstream message to be saved.
 *  @param error   The error if any while saving the message else nil.
 *
 *  @return YES if the message was successfully saved to RMQ else NO.
 */
- (BOOL)saveRmqMessage:(GPBMessage *)message error:(NSError **)error;

/**
 *  Save Server to device message with the given RMQ-ID.
 *
 *  @param rmqID The rmqID of the s2d message to save.
 *
 *  @return YES if the save was successfull else NO.
 */
- (BOOL)saveS2dMessageWithRmqId:(NSString *)rmqID;

/**
 *  A list of all unacked Server to device RMQ IDs.
 *
 *  @return A list of unacked Server to Device RMQ ID's. All values are Strings.
 */
- (NSArray *)unackedS2dRmqIds;

/**
 *  Removes the outgoing message from RMQ store.
 *
 *  @param rmqId The rmqID to remove from the store.
 *
 *  @return The number of messages deleted successfully.
 */
- (int)removeRmqMessagesWithRmqId:(NSString *)rmqId;

/**
 *  Removes the messages with the given rmqIDs from RMQ store.
 *
 *  @param rmqIds The lsit of rmqID's to remove from the store.
 *
 *  @return The number of messages deleted successfully.
 */
- (int)removeRmqMessagesWithRmqIds:(NSArray *)rmqIds;

/**
 *  Removes a list of downstream messages from the RMQ.
 *
 *  @param s2dIds The list of messages ACK'ed by the server that we should remove
 *                from the RMQ store.
 */
- (void)removeS2dIds:(NSArray *)s2dIds;

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
 *  Delete sync message with rmqID.
 *
 *  @param rmqID The rmqID of the persisted sync message.
 *
 *  @return YES if the message was successfully deleted else NO.
 */
- (BOOL)deleteSyncMessageWithRmqID:(NSString *)rmqID;

/**
 *  Delete the expired sync messages from persisten store. Also deletes messages that have been
 *  delivered both via APNS and MCS.
 *
 *  @param error The error if any while deleting the messages.
 *
 *  @return The total number of messages that were deleted from the persistent store.
 */
- (int)deleteExpiredOrFinishedSyncMessages:(NSError **)error;

/**
 *  Save sync message received by the device.
 *
 *  @param rmqID          The rmqID of the message received.
 *  @param expirationTime The expiration time of the sync message received.
 *  @param apnsReceived   YES if the message was received via APNS else NO.
 *  @param mcsReceived    YES if the message was received via MCS else NO.
 *  @param error          The error if any while saving the sync message to persistent store.
 *
 *  @return YES if the message save was successful else NO.
 */
- (BOOL)saveSyncMessageWithRmqID:(NSString *)rmqID
                  expirationTime:(int64_t)expirationTime
                    apnsReceived:(BOOL)apnsReceived
                     mcsReceived:(BOOL)mcsReceived
                           error:(NSError **)error;

/**
 *  Update sync message received via APNS.
 *
 *  @param rmqID The rmqID of the received message.
 *  @param error The error if any while updating the sync message.
 *
 *  @return YES if the persistent sync message was successfully updated else NO.
 */
- (BOOL)updateSyncMessageViaAPNSWithRmqID:(NSString *)rmqID error:(NSError **)error;

/**
 *  Update sync message received via MCS.
 *
 *  @param rmqID The rmqID of the received message.
 *  @param error The error if any while updating the sync message.
 *
 *  @return YES if the persistent sync message was successfully updated else NO.
 */
- (BOOL)updateSyncMessageViaMCSWithRmqID:(NSString *)rmqID error:(NSError **)error;

#pragma mark - Testing

+ (void)removeDatabaseWithName:(NSString *)dbName;

@end
