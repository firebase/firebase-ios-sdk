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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentData.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentDataWithImageURL.h"
#import "FirebaseInAppMessaging/Sources/Runtime/FIRIAMSDKRuntimeErrorCodes.h"

static NSInteger const SuccessHTTPStatusCode = 200;

@interface FIRIAMMessageContentDataWithImageURL ()
@property(nonatomic, readwrite, nonnull, copy) NSString *titleText;
@property(nonatomic, readwrite, nonnull, copy) NSString *bodyText;
@property(nonatomic, copy, nullable) NSString *actionButtonText;
@property(nonatomic, copy, nullable) NSString *secondaryActionButtonText;
@property(nonatomic, copy, nullable) NSURL *actionURL;
@property(nonatomic, copy, nullable) NSURL *secondaryActionURL;
@property(nonatomic, nullable, copy) NSURL *imageURL;
@property(nonatomic, nullable, copy) NSURL *landscapeImageURL;
@property(readonly) NSURLSession *URLSession;
@end

@implementation FIRIAMMessageContentDataWithImageURL
- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
           secondaryActionButtonText:(nullable NSString *)secondaryActionButtonText
                           actionURL:(nullable NSURL *)actionURL
                  secondaryActionURL:(nullable NSURL *)secondaryActionURL
                            imageURL:(nullable NSURL *)imageURL
                   landscapeImageURL:(nullable NSURL *)landscapeImageURL
                     usingURLSession:(nullable NSURLSession *)URLSession {
  if (self = [super init]) {
    _titleText = title;
    _bodyText = body;
    _imageURL = imageURL;
    _landscapeImageURL = landscapeImageURL;
    _actionButtonText = actionButtonText;
    _secondaryActionButtonText = secondaryActionButtonText;
    _actionURL = actionURL;
    _secondaryActionURL = secondaryActionURL;

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

- (void)loadImageDataWithBlock:(void (^)(NSData *_Nullable standardImageData,
                                         NSData *_Nullable landscapeImageData,
                                         NSError *_Nullable error))block {
  if (!block) {
    // no need for any further action if block is nil
    return;
  }

  if (!_imageURL && !_landscapeImageURL) {
    // no image data since image url is nil
    block(nil, nil, nil);
  } else if (!_landscapeImageURL) {
    // Only fetch standard image.
    [self fetchImageFromURL:_imageURL
                  withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
                    block(imageData, nil, error);
                  }];
  } else if (!_imageURL) {
    // Only fetch portrait image.
    [self fetchImageFromURL:_landscapeImageURL
                  withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
                    block(nil, imageData, error);
                  }];
  } else {
    // Fetch both images separately, call completion when they're both fetched.
    __block NSData *portrait = nil;
    __block NSData *landscape = nil;
    __block NSError *landscapeImageLoadError = nil;

    [self fetchImageFromURL:_imageURL
                  withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
                    __weak FIRIAMMessageContentDataWithImageURL *weakSelf = self;

                    // If the portrait image fails to load, we treat this as a failure.
                    if (error) {
                      // Cancel landscape image fetch.
                      [weakSelf.URLSession invalidateAndCancel];

                      block(nil, nil, error);
                      return;
                    }

                    portrait = imageData;
                    if (landscape || landscapeImageLoadError) {
                      block(portrait, landscape, nil);
                    }
                  }];

    [self fetchImageFromURL:_landscapeImageURL
                  withBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
                    if (error) {
                      landscapeImageLoadError = error;
                    } else {
                      landscape = imageData;
                    }

                    if (portrait) {
                      block(portrait, landscape, nil);
                    }
                  }];
  }
}

- (void)fetchImageFromURL:(NSURL *)imageURL
                withBlock:(void (^)(NSData *_Nullable imageData, NSError *_Nullable error))block {
  NSURLRequest *imageDataRequest = [NSURLRequest requestWithURL:imageURL];
  NSURLSessionDataTask *task = [_URLSession
      dataTaskWithRequest:imageDataRequest
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error) {
            FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM000003", @"Error in fetching image: %@",
                          error);
            block(nil, error);
          } else {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
              if (httpResponse.statusCode == SuccessHTTPStatusCode) {
                if (httpResponse.MIMEType == nil || ![httpResponse.MIMEType hasPrefix:@"image"]) {
                  NSString *errorDesc =
                      [NSString stringWithFormat:@"No image MIME type %@"
                                                  " detected for URL %@",
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
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                     code:httpResponse.statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                block(nil, error);
              }
            } else {
              NSString *errorDesc =
                  [NSString stringWithFormat:@"Internal error: got a non HTTP response from "
                                             @"fetching image for image URL as %@",
                                             imageURL];
              FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM000002", @"%@", errorDesc);
              NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                   code:FIRIAMSDKRuntimeErrorNonHTTPResponseForImage
                                               userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
              block(nil, error);
            }
          }
        }];
  [task resume];
}

@end

#endif  // TARGET_OS_IOS
