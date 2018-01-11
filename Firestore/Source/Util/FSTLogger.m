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

#import "Firestore/Source/Util/FSTLogger.h"

#import <FirebaseCore/FIRLogger.h>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRFirestoreVersion.h"

NS_ASSUME_NONNULL_BEGIN

// assumes the first variable argument is the sdk version, and adds a space for it to the format
// string.
void logInternal(FIRLoggerLevel level, NSString* format, ...) {
  NSString* formatWithVersion = [@"v%s - " stringByAppendingString:format];
  va_list args;
  va_start(args, format);
  FIRLogBasic(level, kFIRLoggerFirestore, @"I-FST000001", formatWithVersion, args);
  va_end(args);
}

void FSTLog(NSString *format, ...) {
  if ([FIRFirestore isLoggingEnabled]) {
    va_list args;
    va_start(args, format);
    logInternal(FIRLoggerLevelDebug, format, FirebaseFirestoreVersionString, args);
    va_end(args);
  }
}

void FSTWarn(NSString *format, ...) {
  va_list args;
  va_start(args, format);
  logInternal(FIRLoggerLevelWarning, format, FirebaseFirestoreVersionString, args);
  va_end(args);
}

NS_ASSUME_NONNULL_END
