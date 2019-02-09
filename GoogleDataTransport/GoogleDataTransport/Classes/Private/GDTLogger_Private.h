/*
 * Copyright 2019 Google
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

#import <GoogleDataTransport/GDTLogger.h>

@class GDTLogWriter;

NS_ASSUME_NONNULL_BEGIN

@interface GDTLogger ()

/** The log mapping identifier that a GDTLogBackend will use to map the extension to proto. */
@property(nonatomic) NSString *logMapID;

/** The log transformers that will operate on logs logged by this logger. */
@property(nonatomic) NSArray<id<GDTLogTransformer>> *logTransformers;

/** The target backend of this logger. */
@property(nonatomic) NSInteger logTarget;

/** The log writer instance to used to write logs. Allows injecting a fake during testing. */
@property(nonatomic) GDTLogWriter *logWriterInstance;

@end

NS_ASSUME_NONNULL_END
