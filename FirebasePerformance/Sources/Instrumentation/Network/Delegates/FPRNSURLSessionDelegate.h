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

@class FPRNetworkTrace;

/** Attaches a new FPRNetworkTrace to task if one has not already been attached.
 *  Called from both FPRNSURLSessionDelegate and FPRNSURLSessionDelegateInstrument.
 *
 *  @param task The task that was created.
 */
FOUNDATION_EXTERN
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void FPRHandleDidCreateTask(NSURLSessionTask *task);

/** Completes and removes the FPRNetworkTrace attached to task using data from metrics.
 *  Called from both FPRNSURLSessionDelegate and FPRNSURLSessionDelegateInstrument.
 *
 *  @param task    The task that finished.
 *  @param metrics The metrics collected for the task.
 */
FOUNDATION_EXTERN
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void FPRHandleDidFinishCollectingMetrics(NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics);
