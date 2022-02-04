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

#import "SharedTestUtilities/FIRComponentTestUtilities.h"
#import "SharedTestUtilities/FIROptionsMock.h"

// Firebase Storage
#import "FirebaseStorage/Sources/FIRStorageComponent.h"

// Firebase Core
#import "FirebaseCore/Internal/FirebaseCoreInternal.h"

// Firebase Functions
#import "FirebaseFunctions/Sources/FIRFunctions+Internal.h"

// Firebase Auth
#import <FirebaseAuth/FIRAuth.h>
#import <FirebaseAuth/FirebaseAuth.h>

#import "FirebaseAuth/Sources/Auth/FIRAuthGlobalWorkQueue.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"

#import "FirebaseAuth/Sources/AuthProvider/FIRAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/AuthProvider/GameCenter/FIRGameCenterAuthCredential.h"
#import "FirebaseAuth/Sources/AuthProvider/OAuth/FIROAuthCredential_Internal.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRCreateAuthURIResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRDeleteAccountRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRDeleteAccountResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIREmailLinkSignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIREmailLinkSignInResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetAccountInfoRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetAccountInfoResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetOOBConfirmationCodeResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRGetProjectConfigResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRResetPasswordRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRResetPasswordResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSecureTokenRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSecureTokenResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSendVerificationCodeResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSetAccountInfoRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSetAccountInfoResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignInWithGameCenterRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignInWithGameCenterResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignUpNewUserRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRSignUpNewUserResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyClientResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyCustomTokenRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyCustomTokenResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPasswordResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPhoneNumberRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyPhoneNumberResponse.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthURLPresenter.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthWebUtils.h"
