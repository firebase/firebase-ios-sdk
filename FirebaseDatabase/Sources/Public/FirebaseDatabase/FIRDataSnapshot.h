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
 * A DataSnapshot contains data from a Firebase Database location. Any time
 * you read Firebase data, you receive the data as a DataSnapshot.
 *
 * DataSnapshots are passed to the blocks you attach with
 * `observe(_:with:)` or `observeSingleEvent(of:with:)`. They are
 * efficiently-generated immutable copies of the data at a Firebase Database
 * location. They can't be modified and will never change. To modify data at a
 * location, use a DatabaseReference (e.g. with `setValue(_:)`).
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(DataSnapshot)
@interface FIRDataSnapshot : NSObject

#pragma mark - Navigating and inspecting a snapshot

/**
 * Gets a DataSnapshot for the location at the specified relative path.
 * The relative path can either be a simple child key (e.g. 'fred')
 * or a deeper slash-separated path (e.g. 'fred/name/first'). If the child
 * location has no data, an empty DataSnapshot is returned.
 *
 * @param childPathString A relative path to the location of child data.
 * @return The DataSnapshot for the child location.
 */
- (FIRDataSnapshot *)childSnapshotForPath:(NSString *)childPathString;

/**
 * Return true if the specified child exists.
 *
 * @param childPathString A relative path to the location of a potential child.
 * @return true if data exists at the specified childPathString, else false.
 */
- (BOOL)hasChild:(NSString *)childPathString;

/**
 * Return true if the DataSnapshot has any children.
 *
 * @return true if this snapshot has any children, else false.
 */
- (BOOL)hasChildren;

/**
 * Return true if the DataSnapshot contains a non-null value.
 *
 * @return true if this snapshot contains a non-null value, else false.
 */
- (BOOL)exists;

#pragma mark - Data export

/**
 * Returns the raw value at this location, coupled with any metadata, such as
 * priority.
 *
 * Priorities, where they exist, are accessible under the ".priority" key in
 * instances of NSDictionary. For leaf locations with priorities, the value will
 * be under the ".value" key.
 */
- (id _Nullable)valueInExportFormat;

#pragma mark - Properties

/**
 * Returns the contents of this data snapshot as native types.
 *
 * Data types returned:
 * + `Dictionary`
 * + `Array`
 * + `NSNumber`-bridgeable types, including `Bool`
 * + `String`
 *
 * @return The data as a native object.
 */
@property(strong, readonly, nonatomic, nullable) id value;

/**
 * Gets the number of children for this DataSnapshot.
 *
 * @return An integer indicating the number of children.
 */
@property(readonly, nonatomic) NSUInteger childrenCount;

/**
 * Gets a DatabaseReference for the location that this data came from.
 *
 * @return A DatabaseReference instance for the location of this data.
 */
@property(nonatomic, readonly, strong) FIRDatabaseReference *ref;

/**
 * The key of the location that generated this DataSnapshot.
 *
 * @return A `String` containing the key for the location of this
 * DataSnapshot.
 */
@property(strong, readonly, nonatomic) NSString *key;

/**
 * An iterator for snapshots of the child nodes in this snapshot.
 *
 * ```
 * for var child in snapshot.children {
 *   // ...
 * }
 * ```
 *
 * @return An NSEnumerator of the children.
 */
@property(strong, readonly, nonatomic)
    NSEnumerator<FIRDataSnapshot *> *children;

/**
 * The priority of the data in this DataSnapshot.
 *
 * @return The priority as a `String`, or `nil` if no priority was set.
 */
@property(strong, readonly, nonatomic, nullable) id priority;

@end

NS_ASSUME_NONNULL_END
