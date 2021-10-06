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

#ifndef FIRESTORE_CORE_SRC_CREDENTIALS_FIREBASE_APP_CHECK_CREDENTIALS_PROVIDER_APPLE_H_
#define FIRESTORE_CORE_SRC_CREDENTIALS_FIREBASE_APP_CHECK_CREDENTIALS_PROVIDER_APPLE_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++."
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <memory>
#include <mutex>  // NOLINT(build/c++11)
#include <string>
#include <utility>

#include "Firestore/core/src/credentials/credentials_provider.h"

@class FIRApp;
@protocol FIRAppCheckInterop;

namespace firebase {
namespace firestore {
namespace credentials {

class FirebaseAppCheckCredentialsProvider
    : public CredentialsProvider<std::string, std::string> {
 public:
  FirebaseAppCheckCredentialsProvider();

  ~FirebaseAppCheckCredentialsProvider() override;

  void GetToken(TokenListener<std::string> completion) override;

  void SetCredentialChangeListener(
      CredentialChangeListener<std::string> change_listener) override;

  void InvalidateToken() override;
};

}  // namespace credentials
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_CREDENTIALS_FIREBASE_APP_CHECK_CREDENTIALS_PROVIDER_APPLE_H_
