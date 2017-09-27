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
 * Simple wrapper around a nullable UID. Mostly exists to make code more readable and for use as
 * a key in dictionaries (since keys cannot be nil).
 */
@interface FSTUser : NSObject<NSCopying>

/** Returns an FSTUser with a nil UID. */
+ (instancetype)unauthenticatedUser;

// Porting note: no GOOGLE_CREDENTIALS or FIRST_PARTY equivalent on iOS, see FSTGetTokenResult for
// more details.

/** Initializes an FSTUser with the given UID. */
- (instancetype)initWithUID:(NSString *_Nullable)UID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, copy, nullable, readonly) NSString *UID;

@property(nonatomic, assign, readonly, getter=isUnauthenticated) BOOL unauthenticated;

@end

NS_ASSUME_NONNULL_END
