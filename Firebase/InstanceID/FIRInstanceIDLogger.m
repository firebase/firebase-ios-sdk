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

#import "FIRInstanceIDLogger.h"

#import <FirebaseCore/FIRLogger.h>

// Re-definition of FIRLogger service, as it is not included in :FIRAppHeaders target
NSString *const kFIRInstanceIDLoggerService = @"[Firebase/InstanceID]";

@implementation FIRInstanceIDLogger

#pragma mark - Log Helpers

+ (NSString *)formatMessageCode:(FIRInstanceIDMessageCode)messageCode {
  return [NSString stringWithFormat:@"I-IID%06ld", (long)messageCode];
}

- (void)logFuncDebug:(const char *)func
         messageCode:(FIRInstanceIDMessageCode)messageCode
                 msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  NSString *formattedMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRInstanceIDLoggerService,
              [FIRInstanceIDLogger formatMessageCode:messageCode], @"%@", formattedMessage);
}

- (void)logFuncInfo:(const char *)func
        messageCode:(FIRInstanceIDMessageCode)messageCode
                msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  NSString *formattedMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  FIRLogBasic(FIRLoggerLevelInfo, kFIRInstanceIDLoggerService,
              [FIRInstanceIDLogger formatMessageCode:messageCode], @"%@", formattedMessage);
}

- (void)logFuncNotice:(const char *)func
          messageCode:(FIRInstanceIDMessageCode)messageCode
                  msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  NSString *formattedMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  FIRLogBasic(FIRLoggerLevelNotice, kFIRInstanceIDLoggerService,
              [FIRInstanceIDLogger formatMessageCode:messageCode], @"%@", formattedMessage);
}

- (void)logFuncWarning:(const char *)func
           messageCode:(FIRInstanceIDMessageCode)messageCode
                   msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  NSString *formattedMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  FIRLogBasic(FIRLoggerLevelWarning, kFIRInstanceIDLoggerService,
              [FIRInstanceIDLogger formatMessageCode:messageCode], @"%@", formattedMessage);
}

- (void)logFuncError:(const char *)func
         messageCode:(FIRInstanceIDMessageCode)messageCode
                 msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  NSString *formattedMessage = [[NSString alloc] initWithFormat:fmt arguments:args];
  va_end(args);
  FIRLogBasic(FIRLoggerLevelError, kFIRInstanceIDLoggerService,
              [FIRInstanceIDLogger formatMessageCode:messageCode], @"%@", formattedMessage);
}

@end

FIRInstanceIDLogger *FIRInstanceIDSharedLogger() {
  static dispatch_once_t onceToken;
  static FIRInstanceIDLogger *logger;
  dispatch_once(&onceToken, ^{
    logger = [[FIRInstanceIDLogger alloc] init];
  });

  return logger;
}
