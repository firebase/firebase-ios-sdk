/*
 * Copyright 2018 Google
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

#define UNUSED(x) (void)(x)

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"

namespace firebase {
namespace firestore {
namespace auth {

void EmptyCredentialsProvider::GetToken(bool force_refresh,
                                        TokenListener completion) {
  UNUSED(force_refresh);
  if (completion) {
    // Unauthenticated token will force the GRPC fallback to use default
    // settings.
    completion(Token::Unauthenticated());
    // completion(Token{"eyJhbGciOiJSUzI1NiIsImtpZCI6ImFhNzE5ZDE4MjQ2OTAyN2ZkYWQ5YzVlMjVmNTA0NWUzZjRhZTBjMTAifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vZnMtY2xpZW50cy1wbGF5Z3JvdW5kLW5pZ2h0bHkiLCJhdWQiOiJmcy1jbGllbnRzLXBsYXlncm91bmQtbmlnaHRseSIsImF1dGhfdGltZSI6MTUyNzc5NTc3NCwidXNlcl9pZCI6InhOSkZxa3lKZ3Nkb0pCWTJhSmZES1JVY0VJZjEiLCJzdWIiOiJ4TkpGcWt5SmdzZG9KQlkyYUpmREtSVWNFSWYxIiwiaWF0IjoxNTI3Nzk1Nzc0LCJleHAiOjE1Mjc3OTkzNzQsImVtYWlsIjoiZXhhbXBsZUBleGFtcGxlLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJleGFtcGxlQGV4YW1wbGUuY29tIl19LCJzaWduX2luX3Byb3ZpZGVyIjoicGFzc3dvcmQifX0.ocoGaVEg_fBmiakCgS0P9xmb2YufSzU9jVXQuiQMDy0pvyEXnalsRRnKf0qhAo1l1sgRHJ0_zrFM6we9vy3qRN8wXkI6k2LPecLKR4xSARxFN5hdNJDy5yvFoxlf7PPRLDKB4W7VmHckq9spilIx0OQR6XQwUZzSeyY38BvDfq595Q0meg4qJqahPdRfz9CsLhQ_y2mjLu1fTE3kd9jvZPsW-QvXATPw--kB2bIOApNZjF-U8mMtVPhekAxTB1BHS7wNJvh1Ngk9DvvkmOEul0oiH_Yx7kMlIdMoP1WI4PU5T9QPQXD4ALcshmrDhfCy5pbGcbbPf9v2DgUkuHt23Q", User{"xNJFqkyJgsdoJBY2aJfDKRUcEIf1"}});
  }
}

void EmptyCredentialsProvider::SetUserChangeListener(
    UserChangeListener listener) {
  if (listener) {
    listener(User::Unauthenticated());
  }
}

}  // namespace auth
}  // namespace firestore
}  // namespace firebase
