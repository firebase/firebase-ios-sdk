// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

/** Defines the interface that allows adding/removing attributes to any object.
 */
NS_SWIFT_NAME(PerformanceAttributable)
@protocol FIRPerformanceAttributable <NSObject>

/** List of attributes. */
@property(nonatomic, nonnull, readonly) NSDictionary<NSString *, NSString *> *attributes;

/**
 * Sets a value as a string for the specified attribute. Updates the value of the attribute if a
 * value had already existed.
 *
 * @param value The value that needs to be set/updated for an attribute. If the length of the value
 *    exceeds the maximum allowed, the value will be truncated to the maximum allowed.
 * @param attribute The name of the attribute. If the length of the value exceeds the maximum
 *    allowed, the value will be truncated to the maximum allowed.
 */
- (void)setValue:(nonnull NSString *)value forAttribute:(nonnull NSString *)attribute;

/**
 * Reads the value for the specified attribute. If the attribute does not exist, returns nil.
 *
 * @param attribute The name of the attribute.
 * @return The value for the attribute. Returns nil if the attribute does not exist.
 */
- (nullable NSString *)valueForAttribute:(nonnull NSString *)attribute;

/**
 * Removes an attribute from the list. Does nothing if the attribute does not exist.
 *
 * @param attribute The name of the attribute.
 */
- (void)removeAttribute:(nonnull NSString *)attribute;

@end
