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

<<<<<<<< HEAD:Firestore/core/src/credentials/firebase_app_check_credentials_provider_apple.mm
#include "Firestore/core/src/credentials/firebase_app_check_credentials_provider_apple.h"
========
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
>>>>>>>> master:Firestore/core/src/credentials/empty_credentials_provider.cc

namespace firebase {
namespace firestore {
namespace credentials {

<<<<<<<< HEAD:Firestore/core/src/credentials/firebase_app_check_credentials_provider_apple.mm
FirebaseAppCheckCredentialsProvider::FirebaseAppCheckCredentialsProvider() {
========
void EmptyCredentialsProvider::GetToken(TokenListener completion) {
  if (completion) {
    // Unauthenticated token will force the GRPC fallback to use default
    // settings.
    completion(AuthToken::Unauthenticated());
  }
>>>>>>>> master:Firestore/core/src/credentials/empty_credentials_provider.cc
}

FirebaseAppCheckCredentialsProvider::~FirebaseAppCheckCredentialsProvider() {
}

void FirebaseAppCheckCredentialsProvider::GetToken(TokenListener<std::string>) {
}

<<<<<<<< HEAD:Firestore/core/src/credentials/firebase_app_check_credentials_provider_apple.mm
void FirebaseAppCheckCredentialsProvider::InvalidateToken() {
}

void FirebaseAppCheckCredentialsProvider::SetCredentialChangeListener(
    CredentialChangeListener<std::string>) {
}

========
>>>>>>>> master:Firestore/core/src/credentials/empty_credentials_provider.cc
}  // namespace credentials
}  // namespace firestore
}  // namespace firebase
