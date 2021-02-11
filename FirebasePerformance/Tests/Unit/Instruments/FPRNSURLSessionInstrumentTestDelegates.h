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

NS_ASSUME_NONNULL_BEGIN

/** This class implements a single method of NSURLSessionDelegate to be used during testing. */
@interface FPRNSURLSessionTestDelegate : NSObject <NSURLSessionDelegate>

/** Is set to YES when URLSession:didBecomeInvalidWithError is called. */
@property(nonatomic) BOOL URLSessionDidBecomeInvalidWithErrorWasCalled;

/** Set to YES when didCallNonStandardDelegateMethod is called, used for testing. */
@property(nonatomic) BOOL nonStandardDelegateMethodCalled;

/** Sets nonStandardDelegateMethodCalled to YES. */
- (void)didCallNonStandardDelegateMethod;

@end

/** This class implements all NSURLSession delegates to test methods used for automated tracing. */
@interface FPRNSURLSessionCompleteTestDelegate : NSObject <NSURLSessionDelegate,
                                                           NSURLSessionTaskDelegate,
                                                           NSURLSessionDataDelegate,
                                                           NSURLSessionDownloadDelegate>

/** Set to YES when URLSession:task:didCompleteWithError: is called, used for testing. */
@property(nonatomic) BOOL URLSessionTaskDidCompleteWithErrorCalled;

/** Set to YES when URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:
 *  is called, used for testing.
 */
@property(nonatomic) BOOL URLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedCalled;

/** Set to YES when URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler: is
 *  called, used for testing.
 */
@property(nonatomic) BOOL URLSessionTaskWillPerformHTTPRedirectionNewRequestCompletionHandlerCalled;

/** Set to YES when URLSession:dataTask:didReceiveData: is called, used for testing. */
@property(nonatomic) BOOL URLSessionDataTaskDidReceiveDataCalled;

/** Set to YES when URLSession:downloadTask:didFinishDownloadingToURL: is called, used for testing.
 */
@property(nonatomic) BOOL URLSessionDownloadTaskDidFinishDownloadingToURLCalled;

/** Set to YES when URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes is called, used for
 *  testing.
 */
@property(nonatomic) BOOL URLSessionDownloadTaskDidResumeAtOffsetExpectedTotalBytesCalled;

/** Set to YES when
 * URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite: is called, used
 * for testing.
 */
@property(nonatomic) BOOL URLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesCalled;

@end

/** This class implements the methods necessary to cancel and resume a download. */
@interface FPRNSURLSessionTestDownloadDelegate : NSObject <NSURLSessionDownloadDelegate>

/** Set to YES when URLSession:downloadTask:didFinishDownloadingToURL: is called, used for testing.
 */
@property(nonatomic) BOOL URLSessionDownloadTaskDidFinishDownloadingToURLCalled;

/** Set to YES when URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes is called, used for
 *  testing.
 */
@property(nonatomic) BOOL URLSessionDownloadTaskDidResumeAtOffsetExpectedTotalBytesCalled;

/** Set to YES when
 * URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite: is called, used
 * for testing.
 */
@property(nonatomic) BOOL URLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesCalled;

@end

NS_ASSUME_NONNULL_END
