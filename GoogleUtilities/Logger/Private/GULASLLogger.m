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

#import "GULASLLogger.h"

#import <asl.h>

#import <GoogleUtilities/GULAppEnvironmentUtil.h>

#import "GULLogger.h"

NS_ASSUME_NONNULL_BEGIN

static GULLoggerService kGULLoggerName = @"[GULLogger]";

const char *kGULLoggerASLClientFacilityName = "com.google.utilities.logger";

#ifdef DEBUG
static NSString *const kMessageCodePattern = @"^I-[A-Z]{3}[0-9]{6}$";
static NSRegularExpression *sMessageCodeRegex;
#endif

@interface GULASLLogger() {
  // Internal storage for properties declared in the GULLoggerSystem
  GULLoggerLevel _logLevel;
  const char * _version;
}

@property (nonatomic) aslclient aslClient;
@property (nonatomic) dispatch_queue_t dispatchQueue;
@property (nonatomic) BOOL forcedDebug;

@end

@implementation GULASLLogger

- (instancetype)init {
  self = [super init];
  if (self) {
    _forcedDebug = NO;
    _logLevel = GULLoggerLevelNotice;
    _version = "";
    _dispatchQueue = dispatch_queue_create("GULLoggerQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_dispatchQueue,
                              dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
  }
  return self;
}

- (void)initializeLogger {
  dispatch_sync(self.dispatchQueue, ^{
    if (!self.aslClient) {
      NSInteger majorOSVersion = [[GULAppEnvironmentUtil systemVersion] integerValue];
      uint32_t aslOptions = ASL_OPT_STDERR;  // Older iOS versions need this flag.
#if TARGET_OS_SIMULATOR
      // The iOS 11 simulator doesn't need the ASL_OPT_STDERR flag.
      if (majorOSVersion >= 11) {
        aslOptions = 0;
      }
#else
      // Devices running iOS 10 or higher don't need the ASL_OPT_STDERR flag.
      if (majorOSVersion >= 10) {
        aslOptions = 0;
      }
#endif  // TARGET_OS_SIMULATOR

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  // asl is deprecated
      self.aslClient = asl_open(NULL, kGULLoggerASLClientFacilityName, aslOptions);
      asl_set_filter(self.aslClient, ASL_FILTER_MASK_UPTO(ASL_LEVEL_NOTICE));
#pragma clang diagnostic pop

#ifdef DEBUG
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        sMessageCodeRegex = [NSRegularExpression regularExpressionWithPattern:kMessageCodePattern
                                                                      options:0
                                                                        error:NULL];
      });
#endif
    }
  });
}

@synthesize version = _version;

- (void)setLogLevel:(GULLoggerLevel)logLevel {
  if (logLevel < GULLoggerLevelMin || logLevel > GULLoggerLevelMax) {
    GULLogError(kGULLoggerName, NO, @"I-COR000023", @"Invalid logger level, %ld", (long)logLevel);
  }

  // We should not raise the logger level if we are running from App Store.
  if (logLevel >= GULLoggerLevelNotice && [GULAppEnvironmentUtil isFromAppStore]) {
    return;
  }
  self.logLevel = logLevel;
}

- (GULLoggerLevel)logLevel {
  return _logLevel;
}

- (void)forceDebug {
  // We should not enable debug mode if we're running from App Store.
  if (![GULAppEnvironmentUtil isFromAppStore]) {
    self.forcedDebug = YES;
    self.logLevel = GULLoggerLevelDebug;
  }
}

- (BOOL)isLoggableLevel:(GULLoggerLevel)logLevel {
  if (self.forcedDebug) {
    return YES;
  } else if (logLevel < GULLoggerLevelMin || logLevel > GULLoggerLevelMax) {
    return NO;
  }
  return logLevel <= self.logLevel;
}

- (void)printToSTDERR {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"  // asl is deprecated
  asl_add_log_file(self.aslClient, STDERR_FILENO);
#pragma clang diagnostic pop
}

- (void)logWithLevel:(GULLoggerLevel)level
         withService:(GULLoggerService)service
            withCode:(NSString *)messageCode
         withMessage:(NSString *)message, ... {
  [self initializeLogger];
  if (![self isLoggableLevel:level]) {
    return;
  }

#ifdef DEBUG
  NSCAssert(messageCode.length == 11, @"Incorrect message code length.");
  NSRange messageCodeRange = NSMakeRange(0, messageCode.length);
  NSUInteger numberOfMatches = [sMessageCodeRegex numberOfMatchesInString:messageCode
                                                                  options:0
                                                                    range:messageCodeRange];
  NSCAssert(numberOfMatches == 1, @"Incorrect message code format.");
#endif

  va_list formatArgs;
  va_start(formatArgs, message);
  NSString *logMsg = [[NSString alloc] initWithFormat:message arguments:formatArgs];
  va_end(formatArgs);
  logMsg =
      [NSString stringWithFormat:@"%s - %@[%@] %@", self.version, service, messageCode, logMsg];
  dispatch_async(self.dispatchQueue, ^{
    asl_log(self.aslClient, NULL, level, "%s", logMsg.UTF8String);
  });
}

@end

NS_ASSUME_NONNULL_END
