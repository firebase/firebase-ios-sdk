/*
 * Copyright 2017 Google
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

#import "FIRMessagingLogger.h"

#import "FIRLogger.h"
#import "FIRMessagingFileLogger.h"

/**
 * A log formatter that prefixes log messages with "FIRMessaging".
 */
@interface FIRMessagingLogStandardFormatter : NSObject<FIRMessagingLogFormatter>

@property(nonatomic, readwrite, strong) NSDateFormatter *dateFormatter;

@end

@implementation FIRMessagingLogStandardFormatter

static NSString *const kFIRMessagingLogPrefix = @"FIRMessaging";

- (id)init {
  if ((self = [super init])) {
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
  }
  return self;
}
/**
 * Returns a formatted string prefixed with "FIRMessaging" to allow
 * FIRMessaging output to be easily differentiated in logs.
 *
 * @param func  the name of the function calling the logger
 * @param fmt   the format string
 * @param args  the list of arguments for the format string
 * @param level the logging level (eg. debug, info)
 * @return  the formatted string prefixed with "FIRMessaging".
 */
- (NSString *)stringForFunc:(NSString *)func
                 withFormat:(NSString *)fmt
                     valist:(va_list)args
                      level:(FIRMessagingLogLevel)level NS_FORMAT_FUNCTION(2, 0) {
  if (!(fmt && args)) {
    return nil;
  }

  NSString *logMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  NSString *logLevelString = [self stringForLogLevel:level];
  NSString *dateString = [self.dateFormatter stringFromDate:[NSDate date]];
  return [NSString stringWithFormat:@"%@: <%@/%@> %@",
          dateString, kFIRMessagingLogPrefix, logLevelString, logMessage];
}

- (NSString *)stringForLogLevel:(FIRMessagingLogLevel)level {
  switch (level) {
    case kFIRMessagingLogLevelDebug:
      return @"DEBUG";

    case kFIRMessagingLogLevelInfo:
      return @"INFO";

    case kFIRMessagingLogLevelError:
      return @"WARNING";

    case kFIRMessagingLogLevelAssert:
      return @"ERROR";

    default:
      return @"INFO";
  }
}

@end

@interface FIRMessagingLogLevelFilter ()

@property(nonatomic, readwrite, assign) FIRMessagingLogLevel level;

@end

@implementation FIRMessagingLogLevelFilter

- (instancetype)initWithLevel:(FIRMessagingLogLevel)level {
  self = [super init];
  if (self) {
    _level = level;
  }
  return self;
}

- (BOOL)filterAllowsMessage:(NSString *)msg level:(FIRMessagingLogLevel)level {
#if defined(DEBUG) && DEBUG
  return YES;
#endif

  BOOL allow = YES;

  switch (level) {
    case kFIRMessagingLogLevelDebug:
      allow = NO;
      break;
    case kFIRMessagingLogLevelInfo:
    case kFIRMessagingLogLevelError:
    case kFIRMessagingLogLevelAssert:
      allow = (level >= self.level);
      break;
    default:
      allow = NO;
      break;
  }

  return allow;
}

@end


// Copied from FIRMessagingLogger. Standard implementation to write logs to console.
@interface NSFileHandle (FIRMessagingFileHandleLogWriter) <FIRMessagingLogWriter>
@end

@implementation NSFileHandle (FIRMessagingFileHandleLogWriter)
- (void)logMessage:(NSString *)msg level:(FIRMessagingLogLevel)level {
  @synchronized(self) {
    // Closed pipes should not generate exceptions in our caller. Catch here
    // as well [FIRMessagingLogger logInternalFunc:...] so that an exception in this
    // writer does not prevent other writers from having a chance.
    @try {
      NSString *line = [NSString stringWithFormat:@"%@\n", msg];
      [self writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    }
    @catch (id e) {
      // Ignored
    }
  }
}
@end

@interface FIRMessagingLogger ()

@end

@implementation FIRMessagingLogger

+ (instancetype)standardLogger {

  id<FIRMessagingLogWriter> writer;
  id<FIRMessagingLogFormatter> formatter;
  id<FIRMessagingLogFilter> filter;

#if FIRMessaging_PROBER
  writer = [[FIRMessagingFileLogWriter alloc] init];
  formatter = [[FIRMessagingFileLogFormatter alloc] init];
  filter = [[FIRMessagingFileLogFilter alloc] init];
#else
  writer = [NSFileHandle fileHandleWithStandardOutput];
  formatter = [[FIRMessagingLogStandardFormatter alloc] init];
  filter = [[FIRMessagingLogLevelFilter alloc] init];
#endif

  return [[FIRMessagingLogger alloc] initWithFilter:filter formatter:formatter writer:writer];
}

- (instancetype)initWithFilter:(id<FIRMessagingLogFilter>)filter
                     formatter:(id<FIRMessagingLogFormatter>)formatter
                        writer:(id<FIRMessagingLogWriter>)writer {
  self = [super init];
  if (self) {
    _filter = filter;
    _formatter = formatter;
    _writer = writer;
  }
  return self;
}

#pragma mark - Log Helpers

+ (NSString *)formatMessageCode:(FIRMessagingMessageCode)messageCode {
  return [NSString stringWithFormat:@"I-FCM%06ld", (long)messageCode];
}

- (void)logFuncDebug:(const char *)func
         messageCode:(FIRMessagingMessageCode)messageCode
                 msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
#if FIRMessaging_PROBER
  va_start(args, fmt);
  [self logInternalFunc:func format:fmt valist:args level:kFIRMessagingLogLevelDebug];
  va_end(args);
#endif
}

- (void)logFuncInfo:(const char *)func
        messageCode:(FIRMessagingMessageCode)messageCode
                msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelInfo, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
#if FIRMessaging_PROBER
  va_start(args, fmt);
  [self logInternalFunc:func format:fmt valist:args level:kFIRMessagingLogLevelInfo];
  va_end(args);
#endif
}

- (void)logFuncNotice:(const char *)func
          messageCode:(FIRMessagingMessageCode)messageCode
                  msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelNotice, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
#if FIRMessaging_PROBER
  va_start(args, fmt);
  // Treat FIRLoggerLevelNotice as "info" locally, since we don't have an equivalent
  [self logInternalFunc:func format:fmt valist:args level:kFIRMessagingLogLevelInfo];
  va_end(args);
#endif
}

- (void)logFuncWarning:(const char *)func
           messageCode:(FIRMessagingMessageCode)messageCode
                   msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelWarning, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
#if FIRMessaging_PROBER
  va_start(args, fmt);
  // Treat FIRLoggerLevelWarning as "error" locally, since we don't have an equivalent
  [self logInternalFunc:func format:fmt valist:args level:kFIRMessagingLogLevelError];
  va_end(args);
#endif
}

- (void)logFuncError:(const char *)func
         messageCode:(FIRMessagingMessageCode)messageCode
                 msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelError, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
#if FIRMessaging_PROBER
  va_start(args, fmt);
  [self logInternalFunc:func format:fmt valist:args level:kFIRMessagingLogLevelError];
  va_end(args);
#endif
}

#pragma mark - Internal Helpers

- (void)logInternalFunc:(const char *)func
                 format:(NSString *)fmt
                 valist:(va_list)args
                  level:(FIRMessagingLogLevel)level {
  // Primary point where logging happens, logging should never throw, catch
  // everything.
  @try {
    NSString *fname = func ? [NSString stringWithUTF8String:func] : nil;
    NSString *msg = [self.formatter stringForFunc:fname
                                       withFormat:fmt
                                           valist:args
                                            level:level];
    if (msg && [self.filter filterAllowsMessage:msg level:level])
      [self.writer logMessage:msg level:level];
  }
  @catch (id e) {
    // Ignored
  }
}

@end

FIRMessagingLogger *FIRMessagingSharedLogger() {
  static dispatch_once_t onceToken;
  static FIRMessagingLogger *logger;
  dispatch_once(&onceToken, ^{
    logger = [FIRMessagingLogger standardLogger];
  });

  return logger;
}
