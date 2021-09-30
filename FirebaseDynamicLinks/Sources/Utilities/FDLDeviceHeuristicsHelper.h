/*
 * Copyright 2021 Google LLC
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

@interface FDLDeviceHeuristicsHelper : NSObject

/**
 * Creates DeviceInfo dictionary based on the provided information.
 */
+ (NSDictionary<NSString *, NSObject *> *)
    FDLDeviceInfoDictionaryFromResolutionHeight:(NSInteger)resolutionHeight
                                resolutionWidth:(NSInteger)resolutionWidth
                                         locale:(NSString *)locale
                                      localeRaw:(NSString *)localeRaw
                              localeFromWebview:(NSString *)localeFromWebView
                                       timeZone:(NSString *)timezone
                                      modelName:(NSString *)modelName;

@end
