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
 * Controls the return value for server timestamps that have not yet been set to
 * their final value.
 */
typedef NS_ENUM(NSInteger, FIRTimestampBehavior) {
  /**
   * Return `NSNull` for `FieldValue.serverTimestamp()` fields that have not yet
   * been set to their final value.
   */
  FIRTimestampBehaviorReturnTimestamp,

  /**
   * Return the previous value for `FieldValue.serverTimestamp()` fields that
   * have not yet been set to their final value.
   */
  FIRTimestampBehaviorReturnNativeDate
} NS_SWIFT_NAME(TimestampBehavior);

/** Settings used to configure a `FIRFirestore` instance. */
NS_SWIFT_NAME(FirestoreSettings)
@interface FIRFirestoreSettings : NSObject <NSCopying>

/**
 * Creates and returns an empty `FIRFirestoreSettings` object.
 *
 * @return The created `FIRFirestoreSettings` object.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/** The hostname to connect to. */
@property(nonatomic, copy) NSString *host;

/** Whether to use SSL when connecting. */
@property(nonatomic, getter=isSSLEnabled) BOOL sslEnabled;

/**
 * A dispatch queue to be used to execute all completion handlers and event handlers. By default,
 * the main queue is used.
 */
@property(nonatomic, strong) dispatch_queue_t dispatchQueue;

/** Set to false to disable local persistent storage. */
@property(nonatomic, getter=isPersistenceEnabled) BOOL persistenceEnabled;

@property(nonatomic) FIRTimestampBehavior timestampBehavior;

@end

NS_ASSUME_NONNULL_END
