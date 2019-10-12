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

#import <Foundation/Foundation.h>

@class FIRInstallationsStoredRegistrationParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * This class serializes and deserializes the installation data into/from `NSData` to be stored in
 * Keychain. This class is primarily used by `FIRInstallationsStore`. It is also used on the logic
 * level as a data object (see `FIRInstallationsItem.registrationError`).
 *
 * WARNING: Modification of the class properties can lead to incompatibility with the stored data
 * encoded by the previous class versions. Any modification must be evaluated and, if it is really
 * needed, the `storageVersion` must be bumped and proper migration code added.
 */

@interface FIRInstallationsStoredRegistrationError : NSObject <NSSecureCoding>

@property(nonatomic, readonly) FIRInstallationsStoredRegistrationParameters *registrationParameters;
@property(nonatomic, readonly) NSDate *date;
@property(nonatomic, readonly) NSError *APIError;

/// The version of local storage.
@property(nonatomic, readonly) NSInteger storageVersion;

- (instancetype)initWithRegistrationParameters:
                    (FIRInstallationsStoredRegistrationParameters *)registrationParameters
                                          date:(NSDate *)date
                                      APIError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
