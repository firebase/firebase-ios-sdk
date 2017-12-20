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
#import "FIRDataEventType.h"
#import "FIRDataSnapshot.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A FIRDatabaseHandle is used to identify listeners of Firebase Database events. These handles
 * are returned by observeEventType: and and can later be passed to removeObserverWithHandle: to
 * stop receiving updates.
 */
typedef NSUInteger FIRDatabaseHandle NS_SWIFT_NAME(DatabaseHandle);

/**
 * A FIRDatabaseQuery instance represents a query over the data at a particular location.
 *
 * You create one by calling one of the query methods (queryOrderedByChild:, queryStartingAtValue:, etc.)
 * on a FIRDatabaseReference. The query methods can be chained to further specify the data you are interested in
 * observing
 */
NS_SWIFT_NAME(DatabaseQuery)
@interface FIRDatabaseQuery : NSObject


#pragma mark - Attach observers to read data

/**
 * observeEventType:withBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from the Firebase Database. Your block will be triggered
 * for the initial data and again whenever the data changes.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates.  It is passed the data as a FIRDataSnapshot.
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType withBlock:(void (^)(FIRDataSnapshot *snapshot))block;


/**
 * observeEventType:andPreviousSiblingKeyWithBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from the Firebase Database. Your block will be triggered
 * for the initial data and again whenever the data changes. In addition, for FIRDataEventTypeChildAdded, FIRDataEventTypeChildMoved, and
 * FIRDataEventTypeChildChanged events, your block will be passed the key of the previous node by priority order.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates.  It is passed the data as a FIRDataSnapshot
 * and the previous child's key.
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(void (^)(FIRDataSnapshot *snapshot, NSString *__nullable prevKey))block;


/**
 * observeEventType:withBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from the Firebase Database. Your block will be triggered
 * for the initial data and again whenever the data changes.
 *
 * The cancelBlock will be called if you will no longer receive new events due to no longer having permission.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates.  It is passed the data as a FIRDataSnapshot.
 * @param cancelBlock The block that should be called if this client no longer has permission to receive these events
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType withBlock:(void (^)(FIRDataSnapshot *snapshot))block withCancelBlock:(nullable void (^)(NSError* error))cancelBlock;


/**
 * observeEventType:andPreviousSiblingKeyWithBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from the Firebase Database. Your block will be triggered
 * for the initial data and again whenever the data changes. In addition, for FIRDataEventTypeChildAdded, FIRDataEventTypeChildMoved, and
 * FIRDataEventTypeChildChanged events, your block will be passed the key of the previous node by priority order.
 *
 * The cancelBlock will be called if you will no longer receive new events due to no longer having permission.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates.  It is passed the data as a FIRDataSnapshot
 * and the previous child's key.
 * @param cancelBlock The block that should be called if this client no longer has permission to receive these events
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FIRDatabaseHandle)observeEventType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(void (^)(FIRDataSnapshot *snapshot, NSString *__nullable prevKey))block withCancelBlock:(nullable void (^)(NSError* error))cancelBlock;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called.  It is passed the data as a FIRDataSnapshot.
 */
- (void)observeSingleEventOfType:(FIRDataEventType)eventType withBlock:(void (^)(FIRDataSnapshot *snapshot))block;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned. In addition, for FIRDataEventTypeChildAdded, FIRDataEventTypeChildMoved, and
 * FIRDataEventTypeChildChanged events, your block will be passed the key of the previous node by priority order.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called.  It is passed the data as a FIRDataSnapshot and the previous child's key.
 */
- (void)observeSingleEventOfType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(void (^)(FIRDataSnapshot *snapshot, NSString *__nullable prevKey))block;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned.
 *
 * The cancelBlock will be called if you do not have permission to read data at this location.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called.  It is passed the data as a FIRDataSnapshot.
 * @param cancelBlock The block that will be called if you don't have permission to access this data
 */
- (void)observeSingleEventOfType:(FIRDataEventType)eventType withBlock:(void (^)(FIRDataSnapshot *snapshot))block withCancelBlock:(nullable void (^)(NSError* error))cancelBlock;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned. In addition, for FIRDataEventTypeChildAdded, FIRDataEventTypeChildMoved, and
 * FIRDataEventTypeChildChanged events, your block will be passed the key of the previous node by priority order.
 *
 * The cancelBlock will be called if you do not have permission to read data at this location.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called.  It is passed the data as a FIRDataSnapshot and the previous child's key.
 * @param cancelBlock The block that will be called if you don't have permission to access this data
 */
- (void)observeSingleEventOfType:(FIRDataEventType)eventType andPreviousSiblingKeyWithBlock:(void (^)(FIRDataSnapshot *snapshot, NSString *__nullable prevKey))block withCancelBlock:(nullable void (^)(NSError* error))cancelBlock;


#pragma mark - Detaching observers

/**
 * Detach a block previously attached with observeEventType:withBlock:.
 *
 * @param handle The handle returned by the call to observeEventType:withBlock: which we are trying to remove.
 */
- (void) removeObserverWithHandle:(FIRDatabaseHandle)handle;


/**
 * Detach all blocks previously attached to this Firebase Database location with observeEventType:withBlock:
 */
- (void) removeAllObservers;

/**
 * By calling `keepSynced:YES` on a location, the data for that location will automatically be downloaded and
 * kept in sync, even when no listeners are attached for that location. Additionally, while a location is kept
 * synced, it will not be evicted from the persistent disk cache.
 *
 * @param keepSynced Pass YES to keep this location synchronized, pass NO to stop synchronization.
*/
 - (void) keepSynced:(BOOL)keepSynced;


#pragma mark - Querying and limiting

/**
* queryLimitedToFirst: is used to generate a reference to a limited view of the data at this location.
* The FIRDatabaseQuery instance returned by queryLimitedToFirst: will respond to at most the first limit child nodes.
*
* @param limit The upper bound, inclusive, for the number of child nodes to receive events for
* @return A FIRDatabaseQuery instance, limited to at most limit child nodes.
*/
- (FIRDatabaseQuery *)queryLimitedToFirst:(NSUInteger)limit;


/**
* queryLimitedToLast: is used to generate a reference to a limited view of the data at this location.
* The FIRDatabaseQuery instance returned by queryLimitedToLast: will respond to at most the last limit child nodes.
*
* @param limit The upper bound, inclusive, for the number of child nodes to receive events for
* @return A FIRDatabaseQuery instance, limited to at most limit child nodes.
*/
- (FIRDatabaseQuery *)queryLimitedToLast:(NSUInteger)limit;

/**
 * queryOrderBy: is used to generate a reference to a view of the data that's been sorted by the values of
 * a particular child key. This method is intended to be used in combination with queryStartingAtValue:,
 * queryEndingAtValue:, or queryEqualToValue:.
 *
 * @param key The child key to use in ordering data visible to the returned FIRDatabaseQuery
 * @return A FIRDatabaseQuery instance, ordered by the values of the specified child key.
*/
- (FIRDatabaseQuery *)queryOrderedByChild:(NSString *)key;

/**
 * queryOrderedByKey: is used to generate a reference to a view of the data that's been sorted by child key.
 * This method is intended to be used in combination with queryStartingAtValue:, queryEndingAtValue:,
 * or queryEqualToValue:.
 *
 * @return A FIRDatabaseQuery instance, ordered by child keys.
 */
- (FIRDatabaseQuery *) queryOrderedByKey;

/**
 * queryOrderedByValue: is used to generate a reference to a view of the data that's been sorted by child value.
 * This method is intended to be used in combination with queryStartingAtValue:, queryEndingAtValue:,
 * or queryEqualToValue:.
 *
 * @return A FIRDatabaseQuery instance, ordered by child value.
 */
- (FIRDatabaseQuery *) queryOrderedByValue;

/**
 * queryOrderedByPriority: is used to generate a reference to a view of the data that's been sorted by child
 * priority. This method is intended to be used in combination with queryStartingAtValue:, queryEndingAtValue:,
 * or queryEqualToValue:.
 *
 * @return A FIRDatabaseQuery instance, ordered by child priorities.
 */
- (FIRDatabaseQuery *) queryOrderedByPriority;

/**
 * queryStartingAtValue: is used to generate a reference to a limited view of the data at this location.
 * The FIRDatabaseQuery instance returned by queryStartingAtValue: will respond to events at nodes with a value
 * greater than or equal to startValue.
 *
 * @param startValue The lower bound, inclusive, for the value of data visible to the returned FIRDatabaseQuery
 * @return A FIRDatabaseQuery instance, limited to data with value greater than or equal to startValue
 */
- (FIRDatabaseQuery *)queryStartingAtValue:(nullable id)startValue;

/**
 * queryStartingAtValue:childKey: is used to generate a reference to a limited view of the data at this location.
 * The FIRDatabaseQuery instance returned by queryStartingAtValue:childKey will respond to events at nodes with a value
 * greater than startValue, or equal to startValue and with a key greater than or equal to childKey. This is most
 * useful when implementing pagination in a case where multiple nodes can match the startValue.
 *
 * @param startValue The lower bound, inclusive, for the value of data visible to the returned FIRDatabaseQuery
 * @param childKey The lower bound, inclusive, for the key of nodes with value equal to startValue
 * @return A FIRDatabaseQuery instance, limited to data with value greater than or equal to startValue
 */
- (FIRDatabaseQuery *)queryStartingAtValue:(nullable id)startValue childKey:(nullable NSString *)childKey;

/**
 * queryEndingAtValue: is used to generate a reference to a limited view of the data at this location.
 * The FIRDatabaseQuery instance returned by queryEndingAtValue: will respond to events at nodes with a value
 * less than or equal to endValue.
 *
 * @param endValue The upper bound, inclusive, for the value of data visible to the returned FIRDatabaseQuery
 * @return A FIRDatabaseQuery instance, limited to data with value less than or equal to endValue
 */
- (FIRDatabaseQuery *)queryEndingAtValue:(nullable id)endValue;

/**
 * queryEndingAtValue:childKey: is used to generate a reference to a limited view of the data at this location.
 * The FIRDatabaseQuery instance returned by queryEndingAtValue:childKey will respond to events at nodes with a value
 * less than endValue, or equal to endValue and with a key less than or equal to childKey. This is most useful when
 * implementing pagination in a case where multiple nodes can match the endValue.
 *
 * @param endValue The upper bound, inclusive, for the value of data visible to the returned FIRDatabaseQuery
 * @param childKey The upper bound, inclusive, for the key of nodes with value equal to endValue
 * @return A FIRDatabaseQuery instance, limited to data with value less than or equal to endValue
 */
- (FIRDatabaseQuery *)queryEndingAtValue:(nullable id)endValue childKey:(nullable NSString *)childKey;

/**
 * queryEqualToValue: is used to generate a reference to a limited view of the data at this location.
 * The FIRDatabaseQuery instance returned by queryEqualToValue: will respond to events at nodes with a value equal
 * to the supplied argument.
 *
 * @param value The value that the data returned by this FIRDatabaseQuery will have
 * @return A FIRDatabaseQuery instance, limited to data with the supplied value.
 */
- (FIRDatabaseQuery *)queryEqualToValue:(nullable id)value;

/**
 * queryEqualToValue:childKey: is used to generate a reference to a limited view of the data at this location.
 * The FIRDatabaseQuery instance returned by queryEqualToValue:childKey will respond to events at nodes with a value
 * equal to the supplied argument and with their key equal to childKey. There will be at most one node that matches
 * because child keys are unique.
 *
 * @param value The value that the data returned by this FIRDatabaseQuery will have
 * @param childKey The name of nodes with the right value
 * @return A FIRDatabaseQuery instance, limited to data with the supplied value and the key.
 */
- (FIRDatabaseQuery *)queryEqualToValue:(nullable id)value childKey:(nullable NSString *)childKey;


#pragma mark - Properties

/**
* Gets a FIRDatabaseReference for the location of this query.
*
* @return A FIRDatabaseReference for the location of this query.
*/
@property (nonatomic, readonly, strong) FIRDatabaseReference * ref;

@end

NS_ASSUME_NONNULL_END
