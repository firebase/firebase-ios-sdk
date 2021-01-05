// Copyright 2017 Google
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

#import "Functions/FirebaseFunctions/FUNUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

NSException *FUNInvalidUsage(NSString *exceptionName, NSString *format, ...) {
  va_list arg_list;
  va_start(arg_list, format);
  NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
  va_end(arg_list);

  return [[NSException alloc] initWithName:exceptionName reason:formattedString userInfo:nil];
}

NS_ASSUME_NONNULL_END
