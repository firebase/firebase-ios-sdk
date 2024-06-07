// Copyright 2021 Google LLC
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

import SwiftUI

#if SWIFT_PACKAGE
  @_exported import FirebaseInAppMessagingInternal
#endif // SWIFT_PACKAGE

// MARK: Image-only messages.

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
struct ImageOnlyInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingImageOnlyDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge = DelegateBridge.shared

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let (message, delegate) = delegateBridge.inAppMessageData,
       let imageOnlyMessage = message as? InAppMessagingImageOnlyDisplay {
      closure(imageOnlyMessage, delegate)
        .onAppear { delegate.impressionDetected?(for: imageOnlyMessage) }
    } else {
      EmptyView()
    }
  }
}

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
public extension View {
  /// Overrides the default display of an image only in-app message as defined on the Firebase
  /// console.
  func imageOnlyInAppMessage<Content: View>(closure: @escaping (InAppMessagingImageOnlyDisplay,
                                                                InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(ImageOnlyInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Banner messages.

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
struct BannerInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingBannerDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge = DelegateBridge.shared

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let (message, delegate) = delegateBridge.inAppMessageData,
       let bannerMessage = message as? InAppMessagingBannerDisplay {
      closure(bannerMessage, delegate).onAppear { delegate.impressionDetected?(for: bannerMessage) }
    } else {
      EmptyView()
    }
  }
}

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
public extension View {
  /// Overrides the default display of a banner in-app message as defined on the Firebase console.
  func bannerInAppMessage<Content: View>(closure: @escaping (InAppMessagingBannerDisplay,
                                                             InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(BannerInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Modal messages.

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
struct ModalInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingModalDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge = DelegateBridge.shared

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let (message, delegate) = delegateBridge.inAppMessageData,
       let modalMessage = message as? InAppMessagingModalDisplay {
      closure(modalMessage, delegate).onAppear { delegate.impressionDetected?(for: modalMessage) }
    } else {
      EmptyView()
    }
  }
}

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
public extension View {
  /// Overrides the default display of a modal in-app message as defined on the Firebase console.
  func modalInAppMessage<Content: View>(closure: @escaping (InAppMessagingModalDisplay,
                                                            InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(ModalInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Card messages.

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
struct CardInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingCardDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge = DelegateBridge.shared

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let (message, delegate) = delegateBridge.inAppMessageData,
       let cardMessage = message as? InAppMessagingCardDisplay {
      closure(cardMessage, delegate).onAppear { delegate.impressionDetected?(for: cardMessage) }
    } else {
      EmptyView()
    }
  }
}

@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
public extension View {
  /// Overrides the default display of a card in-app message as defined on the Firebase console.
  func cardInAppMessage<Content: View>(closure: @escaping (InAppMessagingCardDisplay,
                                                           InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(CardInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Bridge to Firebase In-App Messaging SDK.

/**
 * A singleton that acts as the bridge between view modifiers for displaying custom in-app messages and the
 * in-app message fetch/display/interaction flow.
 */
@available(iOS 13, tvOS 13, *)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
class DelegateBridge: NSObject, InAppMessagingDisplay, InAppMessagingDisplayDelegate,
  ObservableObject {
  @Published var inAppMessageData: (InAppMessagingDisplayMessage,
                                    InAppMessagingDisplayDelegate)? = nil

  static let shared = DelegateBridge()

  override init() {
    super.init()
    InAppMessaging.inAppMessaging().messageDisplayComponent = self
    InAppMessaging.inAppMessaging().delegate = self
  }

  func displayMessage(_ messageForDisplay: InAppMessagingDisplayMessage,
                      displayDelegate: InAppMessagingDisplayDelegate) {
    DispatchQueue.main.async {
      self.inAppMessageData = (messageForDisplay, displayDelegate)
    }
  }

  func messageClicked(_ inAppMessage: InAppMessagingDisplayMessage,
                      with action: InAppMessagingAction) {
    DispatchQueue.main.async {
      self.inAppMessageData = nil
    }
  }

  func messageDismissed(_ inAppMessage: InAppMessagingDisplayMessage,
                        dismissType: InAppMessagingDismissType) {
    DispatchQueue.main.async {
      self.inAppMessageData = nil
    }
  }
}
