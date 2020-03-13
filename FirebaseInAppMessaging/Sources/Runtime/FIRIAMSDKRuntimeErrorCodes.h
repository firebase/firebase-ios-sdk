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

typedef NS_ENUM(NSInteger, FIRIAMSDKRuntimeError) {
  // Failed to crawl the image URL.
  FIRIAMSDKRuntimeErrorImageNotFetchable = 0,

  // Crawling the image URL sees non-image type data being returned.
  FIRIAMSDKRuntimeErrorNonImageMimetypeFromImageURL = 1,

  // The response when fetching the image is non-HTTP.
  FIRIAMSDKRuntimeErrorNonHTTPResponseForImage = 2,

  // Failed to fetch Firebase Installations object.
  FIRIAMSDKRuntimeErrorNoFirebaseInstallationsObject = 3,
};
