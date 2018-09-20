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

#import "DynamicLinks/Logging/FDLLogging.h"

#ifdef GIN_SCION_LOGGING
#import <FirebaseCore/FIRLogger.h>
#endif  // GIN_SCION_LOGGING

#ifdef GIN_SCION_LOGGING

#if __LP64__  // 64-bit
NSString *const FDLMessageCodeIntegerFormat = @"%06ld";
#else   // 32-bit
NSString *const FDLMessageCodeIntegerFormat = @"%06d";
#endif  // #if __LP64__

NSString *FDLMessageCodeForLogIdentifier(FDLLogIdentifier identifer) {
  static NSString *const kMessageCodePrefix = @"I-FDL";
  NSString *intString = [NSString stringWithFormat:FDLMessageCodeIntegerFormat, identifer];
  return [kMessageCodePrefix stringByAppendingString:intString];
}
#endif  // GIN_SCION_LOGGING

void FDLLog(FDLLogLevel logLevel, FDLLogIdentifier identifer, NSString *message, ...) {
  va_list args_ptr;
  va_start(args_ptr, message);
#ifdef GIN_SCION_LOGGING
  NSString *messageCode = FDLMessageCodeForLogIdentifier(identifer);

  switch (logLevel) {
    case FDLLogLevelError:
      FIRLogError(kFIRLoggerDynamicLinks, messageCode, message, args_ptr);
      break;
    case FDLLogLevelWarning:
      FIRLogWarning(kFIRLoggerDynamicLinks, messageCode, message, args_ptr);
      break;
    case FDLLogLevelNotice:
      FIRLogNotice(kFIRLoggerDynamicLinks, messageCode, message, args_ptr);
      break;
    case FDLLogLevelInfo:
      FIRLogInfo(kFIRLoggerDynamicLinks, messageCode, message, args_ptr);
      break;
    case FDLLogLevelDebug:
      FIRLogDebug(kFIRLoggerDynamicLinks, messageCode, message, args_ptr);
      break;
  }

#else
  NSLogv(message, args_ptr);
#endif  // GIN_SCION_LOGGING
  va_end(args_ptr);
}
