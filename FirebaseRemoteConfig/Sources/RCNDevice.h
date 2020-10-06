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

typedef NS_ENUM(NSInteger, RCNDeviceModel) {
  RCNDeviceModelOther,
  RCNDeviceModelPhone,
  RCNDeviceModelTablet,
  RCNDeviceModelTV,
  RCNDeviceModelGlass,
  RCNDeviceModelCar,
  RCNDeviceModelWearable,
};

/// CocoaPods SDK version
NSString *FIRRemoteConfigPodVersion(void);

/// App version.
NSString *FIRRemoteConfigAppVersion(void);

/// App build version
NSString *FIRRemoteConfigAppBuildVersion(void);

/// Device country, in lowercase.
NSString *FIRRemoteConfigDeviceCountry(void);

/// Device locale, in language_country format, e.g. en_US.
NSString *FIRRemoteConfigDeviceLocale(void);

/// Device subtype.
RCNDeviceModel FIRRemoteConfigDeviceSubtype(void);

/// Device timezone.
NSString *FIRRemoteConfigTimezone(void);

/// Update device context to the given dictionary.
NSMutableDictionary *FIRRemoteConfigDeviceContextWithProjectIdentifier(
    NSString *GMPProjectIdentifier);

/// Check whether client has changed device context, including app version,
/// iOS version, device country etc. This is used to determine whether to throttle.
BOOL FIRRemoteConfigHasDeviceContextChanged(NSDictionary *deviceContext,
                                            NSString *GMPProjectIdentifier);
