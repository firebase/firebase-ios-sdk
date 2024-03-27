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

/// Defined namespace for alternative auth methods
/// Used in configuring the UI for `OtherAuthViewController` subclasses
/// - Tag: OtherAuthMethods
enum OtherAuthMethod: String {
  case Passwordless = "Email Link/Passwordless"
  case PhoneNumber = "Phone Auth"
  case Custom = "a Custom Auth System"

  var navigationTitle: String { "Sign in using \(rawValue)" }

  var textFieldPlaceholder: String {
    switch self {
    case .Passwordless:
      return "Enter Authentication Email"
    case .PhoneNumber:
      return "Enter Phone Number"
    case .Custom:
      return "Enter Custom Auth Token"
    }
  }

  var textFieldIcon: String {
    switch self {
    case .Passwordless:
      return "envelope.circle"
    case .PhoneNumber:
      return "phone.circle"
    case .Custom:
      return "lock.shield"
    }
  }

  var textFieldInputText: String? {
    switch self {
    case .PhoneNumber:
      return "Example input for +1 (123)456-7890 would be 11234567890"
    default:
      return nil
    }
  }

  var buttonTitle: String {
    switch self {
    case .Passwordless:
      return "Send Sign In Link"
    case .PhoneNumber:
      return "Send Verification Code"
    case .Custom:
      return "Login"
    }
  }

  var infoText: String {
    switch self {
    case .Passwordless:
      return passwordlessInfoText
    case .PhoneNumber:
      return phoneNumberInfoText
    case .Custom:
      return customAuthInfoText
    }
  }

  private var passwordlessInfoText: String {
    """
    Authenticate users with only their email, \
    no password required! This login flow signs in \
    users by emailing them a verification link. \
    Opening the link sends users back to the app, \
    completing the verification step and signing them in. \
    \n
    To demo, enter an email for the link to be sent to. \
    Without dismissing the current view, switch \
    to a mail app and open the link that was emailed to you. \
    This should return you to this app, completing the sign in process!
    """
  }

  private var phoneNumberInfoText: String {
    """
    Firebase can authenticate a user by sending an SMS message \
    to the user's phone, prompting them to sign in using a one-time code. \
    It is recommended to alert users that standard rates apply to this message. \
    Silent APNs notifications are used to verify \
    the request is coming from a user's device. If APNs notifications \
    are not configured, a reCAPTCHA verification flow will be presented. \
    \n
    To demo, enter a phone number and wait a few seconds for Firebase \
    to present the designated login flow.
    """
  }

  private var customAuthInfoText: String {
    """
    Create a custom authentication \
    system by configuring an authentication \
    server to produce custom signed \
    tokens when a user successfully signs in. \
    These tokens can then be used to \
    authenticate with Firebase. \
    \n
    To demo this login flow, generate a \
    custom signed token and paste it in \
    the textfield to begin. Visit the docs \
    for more info.
    """
  }
}
