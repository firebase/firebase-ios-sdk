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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

FIRLoggerService kFIRLoggerAppCheck = @"[Firebase/AppCheck]";

NSString *const kFIRLoggerAppCheckMessageCodeUnknown = @"I-FAA001001";

void FIRAppCheckDebugLog(NSString *message, ...) {
  va_list args_ptr;
  va_start(args_ptr, message);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeUnknown, message, args_ptr);
  va_end(args_ptr);
}

NS_ASSUME_NONNULL_END
