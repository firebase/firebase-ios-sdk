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
#import "GULLoggerLevel.h"
#import "GULOSLogger.h"

static id<GULLoggerSystem> sGULLogger;

NSString *const kGULLoggerInvalidLoggerLevelCore = @"I-COR000023";
NSString *const kGULLoggerInvalidLoggerLevelMessage = @"Invalid logger level, %ld";
GULLoggerService const kGULLoggerName = @"[GULLogger]";
const char *const kGULLoggerClientFacilityName = "com.google.utilities.logger";

#ifdef DEBUG
NSString *const kGULLoggerMessageCodePattern = @"^I-[A-Z]{3}[0-9]{6}$";
#endif

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
                 ...) {
  va_list formatArgs;
  va_start(formatArgs, message);
  [GULLogger.logger logWithLevel:level
                     withService:service
                        isForced:forceLog
                        withCode:messageCode
                     withMessage:messageCode, formatArgs];
  va_end(formatArgs);
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
