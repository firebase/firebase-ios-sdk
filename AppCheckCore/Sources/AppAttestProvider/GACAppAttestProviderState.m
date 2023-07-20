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

#import "AppCheckCore/Sources/AppAttestProvider/GACAppAttestProviderState.h"

@implementation GACAppAttestProviderState

- (instancetype)initUnsupportedWithError:(NSError *)error {
  self = [super init];
  if (self) {
    _state = GACAppAttestAttestationStateUnsupported;
    _appAttestUnsupportedError = error;
  }
  return self;
}

- (instancetype)initWithSupportedInitialState {
  self = [super init];
  if (self) {
    _state = GACAppAttestAttestationStateSupportedInitial;
  }
  return self;
}

- (instancetype)initWithGeneratedKeyID:(NSString *)keyID {
  self = [super init];
  if (self) {
    _state = GACAppAttestAttestationStateKeyGenerated;
    _appAttestKeyID = keyID;
  }
  return self;
}

- (instancetype)initWithRegisteredKeyID:(NSString *)keyID artifact:(NSData *)artifact {
  self = [super init];
  if (self) {
    _state = GACAppAttestAttestationStateKeyRegistered;
    _appAttestKeyID = keyID;
    _attestationArtifact = artifact;
  }
  return self;
}

@end
