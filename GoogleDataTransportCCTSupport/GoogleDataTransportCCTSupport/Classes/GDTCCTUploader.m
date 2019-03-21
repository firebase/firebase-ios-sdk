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

#import "GDTCCTUploader.h"

#import <GoogleDataTransport/GDTRegistrar.h>
#import <nanopb/pb.h>
#import <nanopb/pb_encode.h>

#import "GDTCCTNanopbHelpers.h"
#import "GDTCCTPrioritizer.h"
#import "cct.nanopb.h"

@implementation GDTCCTUploader

+ (void)load {
  GDTCCTUploader *uploader = [GDTCCTUploader sharedInstance];
  [[GDTRegistrar sharedInstance] registerUploader:uploader target:kGDTTargetCCT];
}

+ (instancetype)sharedInstance {
  static GDTCCTUploader *sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[GDTCCTUploader alloc] init];
  });
  return sharedInstance;
}

- (void)uploadPackage:(nonnull GDTUploadPackage *)package
           onComplete:(nonnull GDTUploaderCompletionBlock)onComplete {
}

@end
