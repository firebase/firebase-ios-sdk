/*
 * Copyright 2018 Google
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

@class GDLLogEvent;

/** This protocol defines the common interface of a log scorer. Log scorers are stateful objects
 *  that score logs upon insertion into storage and remain prepared to return a set of log filenames
 *to the storage system
 **/
@protocol GDLLogScorer <NSObject>

@required

/** Accepts a logEvent and uses the log metadata to make choices on how to prioritize the log. This
 *  method exists as a way to help prioritize which logs should be sent, which is dependent on the
 *  request proto structure of your backend.
 *
 *  @note the logEvent cannot be retained for longer than the execution time of this method. Also,
 *      extension should be nil by this point and should not be used to prioritize logs.
 *
 * @param logEvent The log event to score.
 */
- (NSInteger)scoreLog:(GDLLogEvent *)logEvent;

/** Returns a set of logs based on the prioritization logic  of the scorer.
 *
 * @return A set of logs to upload, presumably based on the logs' priority.
 */
- (NSSet<NSURL *> *)logsForNextUpload;

@end
