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

@class GDTLogEvent;

NS_ASSUME_NONNULL_BEGIN

/** Defines the API that log transformers must adopt. */
@protocol GDTLogTransformer <NSObject>

@required

/** Transforms a log by applying some logic to it. Logs returned can be nil, for example, in
 *  instances where the log should be sampled.
 *
 * @param logEvent The log event to transform.
 * @return A transformed log event, or nil if the transformation removed the log event.
 */
- (GDTLogEvent *)transform:(GDTLogEvent *)logEvent;

@end

NS_ASSUME_NONNULL_END
