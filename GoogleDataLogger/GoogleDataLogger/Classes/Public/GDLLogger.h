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

#import "GDLLogTransformer.h"

NS_ASSUME_NONNULL_BEGIN

@interface GDLLogger : NSObject

/** Please use the designated initializer. */
- (instancetype)init NS_UNAVAILABLE;

/** Initializes a new logger that will log events to the given target backend.
 *
 * @param logMapID The mapping identifier used by the backend to map the extension to a proto.
 * @param logTransformers A list of transformers to be applied to log events that are logged.
 * @param logTarget The target backend of this logger.
 * @return A logger that will log events.
 */
- (instancetype)initWithLogMapID:(NSString *)logMapID
                  logTransformers:(nullable NSArray<id<GDLLogTransformer>> *)logTransformers
                        logTarget:(NSInteger)logTarget;

@end

NS_ASSUME_NONNULL_END
