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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** @class FIRAuthOperation
    @brief A class which provides operation types for RPCs that support the operation parameter.
 */
@interface FIRAuthOperation : NSObject

/**
    @brief Indicates the type of operation performed for RPCs that support the operation
        parameter.
 */
typedef NS_ENUM(NSInteger, FIRAuthOperationType) {
  /** Indicates that the operation type is uspecified.
   */
  FIRAuthOperationTypeUnspecified = 0,

  /** Indicates that the operation type is sign in or sign up.
   */
   FIRAuthOperationTypeSignUpOrSignIn = 1,

  /** Indicates that the operation type is reauthentication.
   */
  FIRAuthOperationTypeReauth = 2,

  /** Indicates that the operation type is update.
   */
  FIRAuthOperationTypeUpdate = 3,

  /** Indicates that the operation type is link.
   */
  FIRAuthOperationTypeLink = 4,
};

/** @fn FIRAuthOperationString
    @param operationType The value of the FIRAuthOperationType enum which will be translated to its
        corresponding string value.
    @return The string value corresponding to the FIRAuthOperationType argument.
 */
NSString *const FIRAuthOperationString(FIRAuthOperationType operationType);

/** @fn init
    @brief This class is not supposed to be instantiated.
 */
- (nullable instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
