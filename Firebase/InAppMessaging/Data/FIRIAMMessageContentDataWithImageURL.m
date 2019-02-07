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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMMessageContentData.h"
#import "FIRIAMMessageContentDataWithImageURL.h"
#import "FIRIAMSDKRuntimeErrorCodes.h"

static NSInteger const SuccessHTTPStatusCode = 200;

@interface FIRIAMMessageContentDataWithImageURL ()
@property(nonatomic, readwrite, nonnull, copy) NSString *titleText;
@property(nonatomic, readwrite, nonnull, copy) NSString *bodyText;
@property(nonatomic, copy, nullable) NSString *actionButtonText;
@property(nonatomic, copy, nullable) NSURL *actionURL;
@property(nonatomic, nullable, copy) NSURL *imageURL;
@property(readonly) NSURLSession *URLSession;
@end

@implementation FIRIAMMessageContentDataWithImageURL
- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
                           actionURL:(nullable NSURL *)actionURL
                            imageURL:(nullable NSURL *)imageURL
                     usingURLSession:(nullable NSURLSession *)URLSession {
  if (self = [super init]) {
    _titleText = title;
    _bodyText = body;
    _imageURL = imageURL;
    _actionButtonText = actionButtonText;
    _actionURL = actionURL;

    if (imageURL) {
      _URLSession = URLSession ? URLSession : [NSURLSession sharedSession];
    }
  }
  return self;
}

#pragma protocol FIRIAMMessageContentData

- (NSString *)description {
  return [NSString stringWithFormat:@"Message content: title '%@',"
                                     "body '%@', imageURL '%@', action URL '%@'",
                                    self.titleText, self.bodyText, self.imageURL, self.actionURL];
}

- (NSString *)getTitleText {
  return _titleText;
}

- (NSString *)getBodyText {
  return _bodyText;
}

- (nullable NSString *)getActionButtonText {
  return _actionButtonText;
}

- (void)loadImageDataWithBlock:(void (^)(NSData *_Nullable imageData,
                                         NSError *_Nullable error))block {
  if (!block) {
    // no need for any further action if block is nil
    return;
  }

  if (!_imageURL) {
    // no image data since image url is nil
    block(nil, nil);
  } else {
    NSURLRequest *imageDataRequest = [NSURLRequest requestWithURL:_imageURL];
    NSURLSessionDataTask *task = [_URLSession
        dataTaskWithRequest:imageDataRequest
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
              FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM000003",
                            @"Error in fetching image: %@", error);
              block(nil, error);
            } else {
              if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == SuccessHTTPStatusCode) {
                  if (httpResponse.MIMEType == nil || ![httpResponse.MIMEType hasPrefix:@"image"]) {
                    NSString *errorDesc =
                        [NSString stringWithFormat:@"None image MIME type %@"
                                                    " detected for url %@",
                                                   httpResponse.MIMEType, self.imageURL];
                    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM000004", @"%@", errorDesc);

                    NSError *error =
                        [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                                            code:FIRIAMSDKRuntimeErrorNonImageMimetypeFromImageURL
                                        userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                    block(nil, error);
                  } else {
                    block(data, nil);
                  }
                } else {
                  NSString *errorDesc =
                      [NSString stringWithFormat:@"Failed HTTP request to crawl image %@: "
                                                  "HTTP status code as %ld",
                                                 self->_imageURL, (long)httpResponse.statusCode];
                  FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM000001", @"%@", errorDesc);
                  NSError *error =
                      [NSError errorWithDomain:NSURLErrorDomain
                                          code:httpResponse.statusCode
                                      userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                  block(nil, error);
                }
              } else {
                FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM000002",
                              @"Internal error: got a non http response from fetching image for "
                              @"image url as %@",
                              self->_imageURL);
              }
            }
          }];
    [task resume];
  }
}
@end
