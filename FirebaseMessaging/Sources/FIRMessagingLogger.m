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

#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

FIRLoggerService kFIRLoggerMessaging = @"[Firebase/Messaging]";

@implementation FIRMessagingLogger

+ (instancetype)standardLogger {
  return [[FIRMessagingLogger alloc] init];
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
}

- (void)logFuncInfo:(const char *)func
        messageCode:(FIRMessagingMessageCode)messageCode
                msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelInfo, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
}

- (void)logFuncNotice:(const char *)func
          messageCode:(FIRMessagingMessageCode)messageCode
                  msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelNotice, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
}

- (void)logFuncWarning:(const char *)func
           messageCode:(FIRMessagingMessageCode)messageCode
                   msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelWarning, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
}

- (void)logFuncError:(const char *)func
         messageCode:(FIRMessagingMessageCode)messageCode
                 msg:(NSString *)fmt, ... {
  va_list args;
  va_start(args, fmt);
  FIRLogBasic(FIRLoggerLevelError, kFIRLoggerMessaging,
              [FIRMessagingLogger formatMessageCode:messageCode], fmt, args);
  va_end(args);
}

@end

FIRMessagingLogger *FIRMessagingSharedLogger(void) {
  static dispatch_once_t onceToken;
  static FIRMessagingLogger *logger;
  dispatch_once(&onceToken, ^{
    logger = [FIRMessagingLogger standardLogger];
  });

  return logger;
}
