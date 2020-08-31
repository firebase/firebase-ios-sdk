/*
 * Copyright 2020 Google LLC
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

/// Connector for bridging communication between Firebase SDKs and FirebaseABTesting API.
@protocol FIRABTInterop

/// Updates the list of experiments. Experiments already
/// existing in payloads are not affected, whose state and payload is preserved. This method
/// compares whether the experiments have changed or not by their variant ID. This runs in a
/// background queue..
/// @param origin         The originating service affected by the experiment.
/// @param lastStartTime  The last known experiment start timestamp for this affected service.
///                       (Timestamps are specified by the number of seconds from 00:00:00 UTC on 1
///                       January 1970.).
/// @param payloads       List of experiment metadata.
- (void)updateExperimentsWithServiceOrigin:(NSString *)origin
                             lastStartTime:(NSTimeInterval)lastStartTime
                                  payloads:(NSArray<NSData *> *)payloads;

/// Returns the latest experiment start timestamp given a current latest timestamp and a list of
/// experiment payloads. Timestamps are specified by the number of seconds from 00:00:00 UTC on 1
/// January 1970.
/// @param timestamp  Current latest experiment start timestamp. If not known, affected service
///                   should specify -1;
/// @param payloads   List of experiment metadata.
- (NSTimeInterval)latestExperimentStartTimestampBetweenTimestamp:(NSTimeInterval)timestamp
                                                     andPayloads:(NSArray<NSData *> *)payloads;

@end

NS_ASSUME_NONNULL_END
