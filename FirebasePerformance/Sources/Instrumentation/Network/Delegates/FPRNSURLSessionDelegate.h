// Copyright 2020 Google LLC
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

#import <Foundation/Foundation.h>

/** This class exists as a supplier of implementations for delegates that do not implement all
 *  methods. While swizzling a delegate, if their class doesn't implement the below methods, these
 *  implementations will be copied onto the delegate class.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FPRNSURLSessionDelegate : NSObject <NSURLSessionDelegate,
                                               NSURLSessionDataDelegate,
                                               NSURLSessionTaskDelegate,
                                               NSURLSessionDownloadDelegate>

@end
