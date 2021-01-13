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

/** This class implements only the connectionDidReceiveDataCalled method, because if
 *  connection:didFinishDownloadingDestinationURL: is implemented, that will always be called.
 */
@interface FPRNSURLConnectionDidReceiveDataDelegate : NSObject <NSURLConnectionDataDelegate>

/** Set to YES when connection:didReceiveData: is called, used for testing. */
@property(nonatomic) BOOL connectionDidReceiveDataCalled;

/** Set to YES when connectionDidFinishLoading: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishLoadingCalled;

@end

/** This class implements only a couple methods that we care about, and is used for testing. */
@interface FPRNSURLConnectionTestDelegate : NSObject <NSURLConnectionDelegate,
                                                      NSURLConnectionDataDelegate,
                                                      NSURLConnectionDownloadDelegate>

/** Set to YES when connection:didFailWithError: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFailWithErrorCalled;

/** Set to YES when connection:willSendRequest:redirectResponse: is called, used for testing. */
@property(nonatomic) BOOL connectionWillSendRequestRedirectResponseCalled;

/** Set to YES when connectionDidFinishDownloading:destinationURL: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishDownloadingDestinationURLCalled;

@end

/** This class implements only a couple methods that we care about, and is used for testing. */
@interface FPRNSURLConnectionOperationTestDelegate : NSOperation <NSURLConnectionDelegate,
                                                                  NSURLConnectionDataDelegate,
                                                                  NSURLConnectionDownloadDelegate>

/** Set to YES when connection:didFailWithError: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFailWithErrorCalled;

/** Set to YES when connection:willSendRequest:redirectResponse: is called, used for testing. */
@property(nonatomic) BOOL connectionWillSendRequestRedirectResponseCalled;

/** Set to YES when connectionDidFinishDownloading:destinationURL: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishDownloadingDestinationURLCalled;

@end

/** This class implements only data delegate methods, and is used for testing. */
@interface FPRNSURLConnectionDataTestDelegate
    : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

/** Set to YES when connectionDidFinishLoading: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishLoadingCalled;

@end

/** This class implements only download delegate methods, and is used for testing. */
@interface FPRNSURLConnectionDownloadTestDelegate
    : NSObject <NSURLConnectionDelegate, NSURLConnectionDownloadDelegate>

/** Set to YES when connectionDidFinishDownloading:destinationURL: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishDownloadingDestinationURLCalled;

@end

/** This class implements every delegate method we care about, and is used for testing. */
@interface FPRNSURLConnectionCompleteTestDelegate : NSObject <NSURLConnectionDelegate,
                                                              NSURLConnectionDataDelegate,
                                                              NSURLConnectionDownloadDelegate>

/** Set to YES when connection:didFailWithError: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFailWithErrorCalled;

/** Set to YES when connection:willSendRequest:redirectResponse: is called, used for testing. */
@property(nonatomic) BOOL connectionWillSendRequestRedirectResponseCalled;

/** Set to YES when connection:didReceiveResponse: is called, used for testing. */
@property(nonatomic) BOOL connectionDidReceiveResponseCalled;

/** Set to YES when connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite: is
 *  called. Used for testing.
 */
@property(nonatomic) BOOL connectionDidSendBodyDataTotalBytesWrittenTotalBytesExpectedToWriteCalled;

/** Set to YES when connectionDidFinishLoading: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishLoadingCalled;

/** Set to YES when connection:didWriteData:totalBytesWritten:expectedTotalBytes: is called, used
 *  for testing.
 */
@property(nonatomic) BOOL connectionDidWriteDataTotalBytesWrittenExpectedTotalBytesCalled;

/** Set to YES when connectionDidFinishDownloading:destinationURL: is called, used for testing. */
@property(nonatomic) BOOL connectionDidFinishDownloadingDestinationURLCalled;

@end

NS_ASSUME_NONNULL_END
