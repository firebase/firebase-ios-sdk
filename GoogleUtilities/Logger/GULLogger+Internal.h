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

#import "GULLogger.h"

#import "GULLoggerSystem.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kGULLoggerInvalidLoggerLevelCore = @"I-COR000023";
static NSString *const kGULLoggerInvalidLoggerLevelMessage = @"Invalid logger level, %ld";
static GULLoggerService const kGULLoggerName = @"[GULLogger]";
static const char *const kGULLoggerClientFacilityName = "com.google.utilities.logger";

@interface GULLogger (Internal)

/**
 * Checks to see if the given logger system would log a message of a given level.
 *
 * @param logger The logger that may be logging a message.
 * @param logLevel The level of the message that may be logged.
 * @return YES if the given logger should be logging a message of the given level.
 */
+ (BOOL)loggerSystem:(id<GULLoggerSystem>)logger shouldLogMessageOfLevel:(GULLoggerLevel)logLevel;

/**
 * Formats the given message, code and service for output by the given logger system.
 *
 * @param logger The logger which will output this message
 * @param service The service sending the message to the logger
 * @param code The code for this message
 * @param message The log message, optionally a format string
 * @return A completed string, ready to be output by a logger system.
 */
+ (NSString *)messageFromLogger:(id<GULLoggerSystem>)logger
                    withService:(GULLoggerService)service
                           code:(NSString *)code
                        message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
