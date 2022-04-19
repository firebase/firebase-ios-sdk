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

/**
 * A `MutableData` instance is populated with data from a Firebase Database
 * location. When you are using `runTransactionBlock(_:)`, you will be given an
 * instance containing the current data at that location. Your block will be
 * responsible for updating that instance to the data you wish to save at that
 * location, and then returning using `TransactionResult.success(withValue:)`.
 *
 * To modify the data, set its value property to any of the Objective-C types
 * supported by Firebase Database, or any equivalent natively bridgeable Swift
 * type:
 *
 * + `NSNumber` (includes booleans)
 * + `NSDictionary`
 * + `NSArray`
 * + `NSString`
 * + `nil` / `NSNull` to remove the data
 *
 * Note that changes made to a child `MutableData` instance will be visible to
 * the parent.
 */
NS_SWIFT_NAME(MutableData)
@interface FIRMutableData : NSObject

#pragma mark - Inspecting and navigating the data

/**
 * Returns boolean indicating whether this mutable data has children.
 *
 * @return YES if this data contains child nodes.
 */
- (BOOL)hasChildren;

/**
 * Indicates whether this mutable data has a child at the given path.
 *
 * @param path A path string, consisting either of a single segment, like
 * 'child', or multiple segments, 'a/deeper/child'
 * @return YES if this data contains a child at the specified relative path
 */
- (BOOL)hasChildAtPath:(NSString *)path;

/**
 * Used to obtain a `MutableData` instance that encapsulates the data at the
 * given relative path. Note that changes made to the child will be visible to
 * the parent.
 *
 * @param path A path string, consisting either of a single segment, like
 * 'child', or multiple segments, 'a/deeper/child'
 * @return A `MutableData` instance containing the data at the given path
 */
- (FIRMutableData *)childDataByAppendingPath:(NSString *)path;

#pragma mark - Properties

/**
 * To modify the data contained by this instance of `MutableData`, set this to
 * any of the Objective-C types supported by Firebase Database, or any
 * equivalent natively bridgeable Swift type:
 *
 * + `NSNumber` (includes booleans)
 * + `NSDictionary`
 * + `NSArray`
 * + `NSString`
 * + `nil` / `NSNull` to remove the data
 *
 * Note that setting this value will override the priority at this location.
 *
 * @return The current data at this location as a native object
 */
@property(strong, nonatomic, nullable) id value;

/**
 * Set this property to update the priority of the data at this location. Can be
 * set to any of the following Objective-C types supported by Firebase Database,
 * or any equivalent natively bridgeable Swift type:
 *
 * + `NSNumber` (includes booleans)
 * + `NSString`
 * + `nil` / `NSNull` to remove the data
 *
 * @return The priority of the data at this location
 */
@property(strong, nonatomic, nullable) id priority;

/**
 * @return The number of child nodes at this location
 */
@property(readonly, nonatomic) NSUInteger childrenCount;

/**
 * An enumeration of the children at this location.
 *
 * for var child in data.children {
 *   // ...
 * }
 *
 * Note that this enumerator operates on an immutable copy of the child list.
 * So, you can modify the instance during iteration, but the new additions will
 * not be visible until you get a new enumerator.
 */
@property(readonly, nonatomic, strong) NSEnumerator<FIRMutableData *> *children;

/**
 * @return The key name of this node, or `nil` if it is the top-most location
 */
@property(readonly, nonatomic, strong, nullable) NSString *key;

@end

NS_ASSUME_NONNULL_END
