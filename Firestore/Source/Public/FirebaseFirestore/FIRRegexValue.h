/*
 * Copyright 2025 Google LLC
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
 * Represents a regular expression type in Firestore documents.
 */
NS_SWIFT_SENDABLE
NS_SWIFT_NAME(RegexValue)
@interface FIRRegexValue : NSObject <NSCopying>

/** The regular expression pattern */
@property(atomic, copy, readonly) NSString *pattern;

/** The regular expression options */
@property(atomic, copy, readonly) NSString *options;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a `RegexValue` constructed with the given pattern and options.
 * @param pattern The regular expression pattern.
 * @param options The regular expression options.
 */
- (instancetype)initWithPattern:(nonnull NSString *)pattern options:(nonnull NSString *)options;

/** Returns true if the given object is equal to this, and false otherwise. */
- (BOOL)isEqual:(id)object;

@end

NS_ASSUME_NONNULL_END
