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

#import "FIRAuthOperation.h"

@implementation FIRAuthOperation

NS_ASSUME_NONNULL_BEGIN

NSString *const FIRAuthOperationString(FIRAuthOperationType operation) {
  switch(operation){
    case FIRAuthOperationTypeUnspecified:
      return @"VERIFY_OP_UNSPECIFIED";
    case FIRAuthOperationTypeSignUpOrSignIn:
      return @"SIGN_UP_OR_IN";
    case FIRAuthOperationTypeReauth:
      return @"REAUTH";
    case FIRAuthOperationTypeLink:
      return @"LINK";
    case FIRAuthOperationTypeUpdate:
      return @"UPDATE";
  }
}

@end

NS_ASSUME_NONNULL_END
