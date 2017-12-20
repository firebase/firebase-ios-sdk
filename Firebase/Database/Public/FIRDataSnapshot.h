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

NS_ASSUME_NONNULL_BEGIN

@class FIRDatabaseReference;

/**
 * A FIRDataSnapshot contains data from a Firebase Database location. Any time you read
 * Firebase data, you receive the data as a FIRDataSnapshot.
 *
 * FIRDataSnapshots are passed to the blocks you attach with observeEventType:withBlock: or observeSingleEvent:withBlock:.
 * They are efficiently-generated immutable copies of the data at a Firebase Database location.
 * They can't be modified and will never change. To modify data at a location,
 * use a FIRDatabaseReference (e.g. with setValue:).
 */
NS_SWIFT_NAME(DataSnapshot)
@interface FIRDataSnapshot : NSObject


#pragma mark - Navigating and inspecting a snapshot

/**
 * Gets a FIRDataSnapshot for the location at the specified relative path.
 * The relative path can either be a simple child key (e.g. 'fred')
 * or a deeper slash-separated path (e.g. 'fred/name/first'). If the child
 * location has no data, an empty FIRDataSnapshot is returned.
 *
 * @param childPathString A relative path to the location of child data.
 * @return The FIRDataSnapshot for the child location.
 */
- (FIRDataSnapshot *)childSnapshotForPath:(NSString *)childPathString;


/**
 * Return YES if the specified child exists.
 *
 * @param childPathString A relative path to the location of a potential child.
 * @return YES if data exists at the specified childPathString, else NO.
 */
- (BOOL) hasChild:(NSString *)childPathString;


/**
 * Return YES if the DataSnapshot has any children.
 *
 * @return YES if this snapshot has any children, else NO.
 */
- (BOOL) hasChildren;


/**
 * Return YES if the DataSnapshot contains a non-null value.
 *
 * @return YES if this snapshot contains a non-null value, else NO.
 */
- (BOOL) exists;


#pragma mark - Data export

/**
 * Returns the raw value at this location, coupled with any metadata, such as priority.
 *
 * Priorities, where they exist, are accessible under the ".priority" key in instances of NSDictionary.
 * For leaf locations with priorities, the value will be under the ".value" key.
 */
- (id __nullable) valueInExportFormat;


#pragma mark - Properties

/**
 * Returns the contents of this data snapshot as native types.
 *
 * Data types returned:
 * + NSDictionary
 * + NSArray
 * + NSNumber (also includes booleans)
 * + NSString
 *
 * @return The data as a native object.
 */
@property (strong, readonly, nonatomic, nullable) id value;


/**
 * Gets the number of children for this DataSnapshot.
 *
 * @return An integer indicating the number of children.
 */
@property (readonly, nonatomic) NSUInteger childrenCount;


/**
 * Gets a FIRDatabaseReference for the location that this data came from.
 *
 * @return A FIRDatabaseReference instance for the location of this data.
 */
@property (nonatomic, readonly, strong) FIRDatabaseReference * ref;


/**
 * The key of the location that generated this FIRDataSnapshot.
 *
 * @return An NSString containing the key for the location of this FIRDataSnapshot.
 */
@property (strong, readonly, nonatomic) NSString* key;


/**
 * An iterator for snapshots of the child nodes in this snapshot.
 * You can use the native for..in syntax:
 *
 * for (FIRDataSnapshot* child in snapshot.children) {
 *     ...
 * }
 *
 * @return An NSEnumerator of the children.
 */
@property (strong, readonly, nonatomic) NSEnumerator<FIRDataSnapshot *>* children;

/**
 * The priority of the data in this FIRDataSnapshot.
 *
 * @return The priority as a string, or nil if no priority was set.
 */
@property (strong, readonly, nonatomic, nullable) id priority;

@end

NS_ASSUME_NONNULL_END
