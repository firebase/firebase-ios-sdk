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

#import "GULLoggerSystem.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * Initialize the default GULLogger.
 *
 * @discussion On iOS 9 and earlier. GULLogger will use ASL. For iOS 10 and later, os_log is used.
 */
extern void GULLoggerInitialize(void);

/**
 * Initialize GULLogger.
 *
 * @discussion This version should no longer be used. ASL is deprecated by Apple to be replaced by
 *             os_log. Calls to this function are redirected to GULLoggerInitialize to ensure
 *             functionality on all iOS versions.
 */
extern void GULLoggerInitializeASL(void);

/**
 * Override log level to Debug.
 */
void GULLoggerForceDebug(void);

/**
 * Turn on logging to STDERR.
 */
extern void GULLoggerEnableSTDERR(void);

/**
 * Changes the default logging level of GULLoggerLevelNotice to a user-specified level.
 * The default level cannot be set above GULLoggerLevelNotice if the app is running from App Store.
 * @param loggerLevel Log level (one of the GULLoggerLevel enum values).
 */
extern void GULSetLoggerLevel(GULLoggerLevel loggerLevel);

/**
 * Checks if the specified logger level is loggable given the current settings.
 * @param loggerLevel Log level (one of the GULLoggerLevel enum values).
 */
extern BOOL GULIsLoggableLevel(GULLoggerLevel loggerLevel);

/**
 * Register version to include in logs.
 * @param version The version to register with the logger.
 */
extern void GULLoggerRegisterVersion(const char *version);

/**
 * Logs a message to the Xcode console and the device log. If running from AppStore, will
 * not log any messages with a level higher than GULLoggerLevelNotice to avoid log spamming.
 * @param level Log level (one of the GULLoggerLevel enum values).
 * @param service Service name of type GULLoggerService.
 * @param forceLog If this message should be output regardless of its level.
 * @param messageCode starting with "I-" which means iOS, followed by a capitalized
 *            three-character service identifier and a six digit integer message ID that is unique
 *            within the service.
 *            An example of the message code is @"I-COR000001".
 * @param message string which can be a format string.
 * @param args_ptr the list of arguments to substitute into the format string.
 */
extern void GULLogBasic(GULLoggerLevel level,
                        GULLoggerService service,
                        BOOL forceLog,
                        NSString *messageCode,
                        NSString *message,
// On 64-bit simulators, va_list is not a pointer, so cannot be marked nullable
// See: http://stackoverflow.com/q/29095469
#if __LP64__ && TARGET_OS_SIMULATOR || TARGET_OS_OSX
                        va_list args_ptr
#else
                        va_list _Nullable args_ptr
#endif
);

/**
 * The following functions accept the following parameters in order:
 * @param service Name of type GULLoggerService.
 * @param messageCode Starting from "I-" which means iOS, followed by a capitalized
 *            three-character service identifier and a six digit integer message ID that is unique
 *            within the service.
 *            An example of the message code is @"I-COR000001".
 *            See go/firebase-log-proposal for details.
 * @param message String which can be a format string.
 * @param ... The list of arguments to substitute into the format string.
 *
 * @discussion
 * Example usage:
 * GULLogError(kGULLoggerCore, @"I-COR000001", @"Configuration of %@ failed.", app.name);
 */
extern void GULLogError(GULLoggerService service,
                        BOOL force,
                        NSString *messageCode,
                        NSString *message,
                        ...) NS_FORMAT_FUNCTION(4, 5);
extern void GULLogWarning(GULLoggerService service,
                          BOOL force,
                          NSString *messageCode,
                          NSString *message,
                          ...) NS_FORMAT_FUNCTION(4, 5);
extern void GULLogNotice(GULLoggerService service,
                         BOOL force,
                         NSString *messageCode,
                         NSString *message,
                         ...) NS_FORMAT_FUNCTION(4, 5);
extern void GULLogInfo(GULLoggerService service,
                       BOOL force,
                       NSString *messageCode,
                       NSString *message,
                       ...) NS_FORMAT_FUNCTION(4, 5);
extern void GULLogDebug(GULLoggerService service,
                        BOOL force,
                        NSString *messageCode,
                        NSString *message,
                        ...) NS_FORMAT_FUNCTION(4, 5);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

@interface GULLogger : NSObject

/// The current default logger.
@property(nonatomic, class, readonly) id<GULLoggerSystem> logger;

@end

NS_ASSUME_NONNULL_END
