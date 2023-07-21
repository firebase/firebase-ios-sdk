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

#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckErrors.h"
#import "AppCheckCore/Sources/Public/AppCheckCore/GACAppCheckLogger.h"

NS_ASSUME_NONNULL_BEGIN

/** Prints the given code and message to the console.
 *
 * @param code The message code describing the nature of the log.
 * @param logLevel The log level of this log.
 * @param message The message string to log.
 */
FOUNDATION_EXPORT
void GACAppCheckLog(GACAppCheckMessageCode code,
                    GACAppCheckLogLevel logLevel,
                    NSString *_Nonnull message);

#define GACAppCheckLogFault(MESSAGE_CODE, MESSAGE) \
  GACAppCheckLog(MESSAGE_CODE, GACAppCheckLogLevelFault, MESSAGE);

#define GACAppCheckLogError(MESSAGE_CODE, MESSAGE) \
  GACAppCheckLog(MESSAGE_CODE, GACAppCheckLogLevelError, MESSAGE);

#define GACAppCheckLogWarning(MESSAGE_CODE, MESSAGE) \
  GACAppCheckLog(MESSAGE_CODE, GACAppCheckLogLevelWarning, MESSAGE);

#define GACAppCheckLogInfo(MESSAGE_CODE, MESSAGE) \
  GACAppCheckLog(MESSAGE_CODE, GACAppCheckLogLevelInfo, MESSAGE);

#define GACAppCheckLogDebug(MESSAGE_CODE, MESSAGE) \
  GACAppCheckLog(MESSAGE_CODE, GACAppCheckLogLevelDebug, MESSAGE);

NS_ASSUME_NONNULL_END
