// Copyright 2018 Google
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

#import "GULLogger.h"

#import "GULASLLogger.h"
#import "GULAppEnvironmentUtil.h"
#import "GULLogger+Internal.h"
#import "GULLoggerLevel.h"
#import "GULOSLogger.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

#ifdef DEBUG
/// The regex pattern for the message code.
NSRegularExpression *GULMessageCodeRegex() {
  static dispatch_once_t onceToken;
  static NSRegularExpression *messageCodeRegex;
  dispatch_once(&onceToken, ^{
    messageCodeRegex = [NSRegularExpression regularExpressionWithPattern:@"^I-[A-Z]{3}[0-9]{6}$"
                                                                 options:0
                                                                   error:NULL];
  });
  return messageCodeRegex;
}

// GULResetLogger is unused but depended on by FirebaseCore versions 5.3.x and earlier.
// It cannot be removed until GoogleUtilities does a breaking change release since FirebaseCore
// allows GoogleUtilities to float up to the highest 5.x version.
void GULResetLogger() {
}
#endif

@implementation GULLogger (Internal)

+ (BOOL)loggerSystem:(id<GULLoggerSystem>)logger shouldLogMessageOfLevel:(GULLoggerLevel)logLevel {
  if (logger.forcedDebug) {
    return YES;
  } else if (logLevel < GULLoggerLevelMin || logLevel > GULLoggerLevelMax) {
    return NO;
  }
  return logLevel <= logger.logLevel;
}

+ (NSString *)messageFromLogger:(id<GULLoggerSystem>)logger
                    withService:(GULLoggerService)service
                           code:(NSString *)code
                        message:(NSString *)message {
#ifdef DEBUG
  NSCAssert(code.length == 11, @"Incorrect message code length.");
  NSRegularExpression *messageCodeRegex = GULMessageCodeRegex();
  NSRange messageCodeRange = NSMakeRange(0, code.length);
  NSUInteger numberOfMatches = [messageCodeRegex numberOfMatchesInString:code
                                                                 options:0
                                                                   range:messageCodeRange];
  NSCAssert(numberOfMatches == 1, @"Incorrect message code format.");
#endif
  return [NSString stringWithFormat:@"%@ - %@[%@] %@", logger.version, service, code, message];
}

@end

static id<GULLoggerSystem> sGULLogger;

void GULLoggerInitialize(void) {
  [GULLogger.logger initializeLogger];
}

void GULLoggerInitializeASL(void) {
  GULLoggerInitialize();
}

void GULLoggerEnableSTDERR(void) {
  [GULLogger.logger printToSTDERR];
}

void GULLoggerForceDebug(void) {
  GULLogger.logger.forcedDebug = YES;
}

void GULSetLoggerLevel(GULLoggerLevel loggerLevel) {
  GULLogger.logger.logLevel = loggerLevel;
}

BOOL GULIsLoggableLevel(GULLoggerLevel loggerLevel) {
  return [GULLogger.logger isLoggableLevel:loggerLevel];
}

void GULLoggerRegisterVersion(const char *version) {
  GULLogger.logger.version = [NSString stringWithUTF8String:version];
}

void GULLogBasic(GULLoggerLevel level,
                 GULLoggerService service,
                 BOOL forceLog,
                 NSString *messageCode,
                 NSString *message,
                 va_list args_ptr) {
#ifdef DEBUG
  NSRegularExpression *messageCodeRegex = GULMessageCodeRegex();
  NSCAssert(messageCode.length == 11, @"Incorrect message code length.");
  NSRange messageCodeRange = NSMakeRange(0, messageCode.length);
  NSUInteger numberOfMatches = [messageCodeRegex numberOfMatchesInString:messageCode
                                                                 options:0
                                                                   range:messageCodeRange];
  NSCAssert(numberOfMatches == 1, @"Incorrect message code format.");
#endif
  NSString *logMsg = [[NSString alloc] initWithFormat:message arguments:args_ptr];
  NSString *formattedMsg =
      [NSString stringWithFormat:@"%@ - [%@] %@", GULLogger.logger.version, messageCode, logMsg];
  [GULLogger.logger logWithLevel:level
                     withService:service
                        isForced:forceLog
                     withMessage:formattedMsg];
}

/**
 * Generates the logging functions using macros.
 *
 * Calling GULLogError(kGULLoggerCore, @"I-COR000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [{service}][I-COR000001] Configure blah failed.
 * Calling GULLogDebug(kGULLoggerCore, @"I-COR000001", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [{service}][I-COR000001] Configure succeed.
 */
#define GUL_LOGGING_FUNCTION(level)                                                     \
  void GULLog##level(GULLoggerService service, BOOL force, NSString *messageCode,       \
                     NSString *message, ...) {                                          \
    va_list args_ptr;                                                                   \
    va_start(args_ptr, message);                                                        \
    GULLogBasic(GULLoggerLevel##level, service, force, messageCode, message, args_ptr); \
    va_end(args_ptr);                                                                   \
  }

GUL_LOGGING_FUNCTION(Error)
GUL_LOGGING_FUNCTION(Warning)
GUL_LOGGING_FUNCTION(Notice)
GUL_LOGGING_FUNCTION(Info)
GUL_LOGGING_FUNCTION(Debug)

#undef GUL_MAKE_LOGGER

// Redefine logger property as readwrite as a form of dependency injection.
@interface GULLogger ()
@property(nonatomic, nullable, class, readwrite) id<GULLoggerSystem> logger;
@end

@implementation GULLogger

+ (id<GULLoggerSystem>)logger {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // Synchronize here to avoid undefined behaviour if a setLogger: call happened before the
    // first get.
    @synchronized(self) {
      if (!sGULLogger) {
#if __has_builtin(__builtin_available)
        if (@available(iOS 9.0, *)) {
#else
        if ([[UIDevice currentDevice].systemVersion integerValue] >= 9) {
#endif
          sGULLogger = [[GULOSLogger alloc] init];
        } else {
          sGULLogger = [[GULASLLogger alloc] init];
        }
      }
    }
  });
  return sGULLogger;
}

+ (void)setLogger:(nullable id<GULLoggerSystem>)logger {
  @synchronized(self) {
    sGULLogger = logger;
  }
}

@end
