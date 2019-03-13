// Copyright 2019 Google
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

#import "GULLoggerLevel.h"

NS_ASSUME_NONNULL_BEGIN

/// The service name used by the logger.
typedef NSString *const GULLoggerService;

/// This protocol describes a GoogleUtilities Logger System implementation.
@protocol GULLoggerSystem <NSObject>

/// The current log level of this logger. Defaults to GULLoggerLevelNotice.
@property(nonatomic) GULLoggerLevel logLevel;

/// The version to report to the logs. Defaults to the empty string.
@property(nonatomic) NSString *version;

/// Forces the current log level to be set to debug. Defaults to NO.
@property(nonatomic) BOOL forcedDebug;

/// Initializes the logger before use.
- (void)initializeLogger;

/// Enables output to STDERR. Not enabled by default.
- (void)printToSTDERR;

/// Checks to see if a given level would be logged given the current level of the logger.
- (BOOL)isLoggableLevel:(GULLoggerLevel)logLevel;

/// Logs the given message.
- (void)logWithLevel:(GULLoggerLevel)level
         withService:(GULLoggerService)service
            isForced:(BOOL)forced
         withMessage:(NSString *)message;
@end

NS_ASSUME_NONNULL_END
