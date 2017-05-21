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

// table data handlers
/**
 *  Handle message stored in the outgoing RMQ messages table.
 *
 *  @param rmqId The rmqID of the message.
 *  @param tag   The message tag.
 *  @param data  The data stored in the message.
 */
typedef void(^FCMOutgoingRmqMessagesTableHandler)(int64_t rmqId, int8_t tag, NSData *data);

/// Outgoing messages RMQ table
extern NSString *const kTableOutgoingRmqMessages;
/// Server to device RMQ table
extern NSString *const kTableS2DRmqIds;

@interface FIRMessagingRmq2PersistentStore : NSObject

/**
 *  Initialize and open the RMQ database on the client.
 *
 *  @param databaseName The name for RMQ database.
 *
 *  @return A store used to persist messages on the client.
 */
- (instancetype)initWithDatabaseName:(NSString *)databaseName;

/**
 *  Save outgoing message in RMQ.
 *
 *  @param rmqId The rmqID for the message.
 *  @param tag   The tag of the message proto.
 *  @param data  The data being sent in the message.
 *  @param error The error if any while saving the message to the persistent store.
 *
 *  @return YES if the message was successfully saved to the persistent store else NO.
 */
- (BOOL)saveMessageWithRmqId:(int64_t)rmqId
                         tag:(int8_t)tag
                        data:(NSData *)data
                       error:(NSError **)error;

/**
 *  Add unacked server to device message with a given rmqID to the persistent store.
 *
 *  @param rmqId The rmqID of the message that was not acked by the cient.
 *
 *  @return YES if the save was successful else NO.
 */
- (BOOL)saveUnackedS2dMessageWithRmqId:(NSString *)rmqId;

/**
 *  Update the last RMQ ID that was sent by the client.
 *
 *  @param rmqID The latest rmqID sent by the device.
 *
 *  @return YES if the last rmqID was successfully saved else NO.
 */
- (BOOL)updateLastOutgoingRmqId:(int64_t)rmqID;

#pragma mark - Query

/**
 *  Query the highest rmqID saved in the Outgoing messages table.
 *
 *  @return The highest rmqID amongst all the messages in the Outgoing RMQ table. If no message
 *          was ever persisted return 0.
 */
- (int64_t)queryHighestRmqId;

/**
 *  The last rmqID that was saved on the client.
 *
 *  @return The last rmqID that was saved. If no rmqID was ever persisted return 0.
 */
- (int64_t)queryLastRmqId;

/**
 *  Get a list of all unacked server to device messages stored on the client.
 *
 *  @return List of all unacked s2d messages in the persistent store.
 */
- (NSArray *)unackedS2dRmqIds;

/**
 *  Iterate over all outgoing messages in the RMQ table.
 *
 *  @param handler The handler invoked with each message in the outgoing RMQ table.
 */
- (void)scanOutgoingRmqMessagesWithHandler:(FCMOutgoingRmqMessagesTableHandler)handler;

#pragma mark - Delete

/**
 *  Delete messages with given rmqID's from a table.
 *
 *  @param tableName The table name from which to delete the rmq messages.
 *  @param rmqIds    The rmqID's of the messages to be deleted.
 *
 *  @return The number of messages that were successfully deleted.
 */
- (int)deleteMessagesFromTable:(NSString *)tableName
                    withRmqIds:(NSArray *)rmqIds;

/**
 *  Remove database from the device.
 *
 *  @param dbName The database name to be deleted.
 */
+ (void)removeDatabase:(NSString *)dbName;

#pragma mark - Sync Messages

/**
 *  Save sync message to persistent store to check for duplicates.
 *
 *  @param rmqID          The rmqID of the message to save.
 *  @param expirationTime The expiration time of the message to save.
 *  @param apnsReceived   YES if the message was received via APNS else NO.
 *  @param mcsReceived    YES if the message was received via MCS else NO.
 *  @param error          The error if any while saving the message to store.
 *
 *  @return YES if the message was saved successfully else NO.
 */
- (BOOL)saveSyncMessageWithRmqID:(NSString *)rmqID
                  expirationTime:(int64_t)expirationTime
                    apnsReceived:(BOOL)apnsReceived
                     mcsReceived:(BOOL)mcsReceived
                           error:(NSError **)error;

/**
 *  Update sync message received via APNS.
 *
 *  @param rmqID The rmqID of the sync message.
 *  @param error The error if any while updating the sync message in persistence.
 *
 *  @return YES if the update was successful else NO.
 */
- (BOOL)updateSyncMessageViaAPNSWithRmqID:(NSString *)rmqID
                                    error:(NSError **)error;

/**
 *  Update sync message received via MCS.
 *
 *  @param rmqID The rmqID of the sync message.
 *  @param error The error if any while updating the sync message in persistence.
 *
 *  @return YES if the update was successful else NO.
 */
- (BOOL)updateSyncMessageViaMCSWithRmqID:(NSString *)rmqID
                                   error:(NSError **)error;

/**
 *  Query sync message table for a given rmqID.
 *
 *  @param rmqID The rmqID to search for in SYNC_RMQ.
 *
 *  @return The sync message that was persisted with `rmqID`. If no such message was persisted
 *          return nil.
 */
- (FIRMessagingPersistentSyncMessage *)querySyncMessageWithRmqID:(NSString *)rmqID;

/**
 *  Delete sync message with rmqID.
 *
 *  @param rmqID The rmqID of the message to delete.
 *
 *  @return YES if a sync message with rmqID was found and deleted successfully else NO.
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

@end
