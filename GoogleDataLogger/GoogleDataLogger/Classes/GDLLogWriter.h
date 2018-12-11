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

@protocol GDLLogTransformer;

/** Manages the writing and log-time transforming of logs. */
@interface GDLLogWriter : NSObject

/** Instantiates or returns the log writer singleton.
 *
 * @return The singleton instance of the log writer.
 */
+ (instancetype)sharedInstance;

/** Writes the result of applying the given transformers' -transform method on the given log.
 *
 * @param log The log to apply transformers on.
 * @param logTransformers The list of transformers to apply.
 */
- (void)writeLog:(GDLLogEvent *)log
    afterApplyingTransformers:(nullable NSArray<id<GDLLogTransformer>> *)logTransformers;

@end
