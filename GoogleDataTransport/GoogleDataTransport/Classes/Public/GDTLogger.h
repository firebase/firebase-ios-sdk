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

#import "GDTLogTransformer.h"

@class GDTLogEvent;

NS_ASSUME_NONNULL_BEGIN

@interface GDTLogger : NSObject

// Please use the designated initializer.
- (instancetype)init NS_UNAVAILABLE;

/** Initializes a new logger that will log events to the given target backend.
 *
 * @param logMapID The mapping identifier used by the backend to map the extension to a proto.
 * @param logTransformers A list of transformers to be applied to log events that are logged.
 * @param logTarget The target backend of this logger.
 * @return A logger that will log events.
 */
- (instancetype)initWithLogMapID:(NSString *)logMapID
                 logTransformers:(nullable NSArray<id<GDTLogTransformer>> *)logTransformers
                       logTarget:(NSInteger)logTarget NS_DESIGNATED_INITIALIZER;

/** Copies and logs an internal telemetry event. Logs sent using this API are lower in priority, and
 * sometimes won't be sent on their own.
 *
 * @note This will convert the log event's extension proto to data and release the original log.
 *
 * @param logEvent The log event to log.
 */
- (void)logTelemetryEvent:(GDTLogEvent *)logEvent;

/** Copies and logs an SDK service data event. Logs send using this API are higher in priority, and
 * will cause a network request at some point in the relative near future.
 *
 * @note This will convert the log event's extension proto to data and release the original log.
 *
 * @param logEvent The log event to log.
 */
- (void)logDataEvent:(GDTLogEvent *)logEvent;

/** Creates a log event for use by this logger.
 *
 * @return A log event that is suited for use by this logger.
 */
- (GDTLogEvent *)newEvent;

@end

NS_ASSUME_NONNULL_END
