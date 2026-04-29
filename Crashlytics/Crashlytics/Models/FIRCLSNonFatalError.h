// Copyright 2026 Google LLC
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

NS_ASSUME_NONNULL_BEGIN

/**
 * An internal model representing a logged non-fatal error.
 * This class synchronously captures the thread state and timestamp upon
 * initialization to safely preserve the execution context.
 */
@interface FIRCLSNonFatalError : NSObject

@property(nonatomic, strong, readonly) NSError *error;
@property(nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *userInfo;
@property(nonatomic, copy, readonly, nullable) NSString *rolloutsInfoJSON;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *stackTrace;
@property(nonatomic, assign, readonly) uint64_t timestamp;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Initializes a non-fatal error, recording the stack trace at initialization.
 * Fails to initialize if error is nil.
 *
 * @param error The NSError being logged. If nil, initialization fails.
 * @param userInfo Optional dictionary of custom key-value pairs.
 * @param rolloutsInfoJSON Optional JSON string containing active feature rollouts.
 */
- (nullable instancetype)initWithError:(NSError *)error
                              userInfo:(nullable NSDictionary<NSString *, id> *)userInfo
                      rolloutsInfoJSON:(nullable NSString *)rolloutsInfoJSON
    NS_DESIGNATED_INITIALIZER;

/**
 * Records the error to disk. No-op if intialization failed.
 */
- (void)recordError;

@end

NS_ASSUME_NONNULL_END
