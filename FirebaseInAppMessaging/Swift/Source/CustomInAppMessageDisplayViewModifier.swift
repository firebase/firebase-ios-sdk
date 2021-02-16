import FirebaseInAppMessaging
import SwiftUI

// MARK: Image-only messages.

struct ImageOnlyInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingImageOnlyDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge: DelegateBridge = DelegateBridge()

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let imageOnlyMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingImageOnlyDisplay,
      let delegate = delegateBridge.inAppMessageData?.1 {
      closure(imageOnlyMessage, delegate)
        .onAppear { delegate.impressionDetected?(for: imageOnlyMessage) }
    } else {
      EmptyView()
    }
  }
}

public extension View {
  func imageOnlyInAppMessage<Content: View>(closure: @escaping (InAppMessagingImageOnlyDisplay,
                                                                InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(ImageOnlyInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Banner messages.

struct BannerInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingBannerDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge: DelegateBridge = DelegateBridge()

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let bannerMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingBannerDisplay,
      let delegate = delegateBridge.inAppMessageData?.1 {
      closure(bannerMessage, delegate).onAppear { delegate.impressionDetected?(for: bannerMessage) }
    } else {
      EmptyView()
    }
  }
}

public extension View {
  func bannerInAppMessage<Content: View>(closure: @escaping (InAppMessagingBannerDisplay,
                                                             InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(BannerInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Modal messages.

struct ModalInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingModalDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge: DelegateBridge = DelegateBridge()

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let modalMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingModalDisplay,
      let delegate = delegateBridge.inAppMessageData?.1 {
      closure(modalMessage, delegate).onAppear { delegate.impressionDetected?(for: modalMessage) }
    } else {
      EmptyView()
    }
  }
}

public extension View {
  func modalInAppMessage<Content: View>(closure: @escaping (InAppMessagingModalDisplay,
                                                            InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(ModalInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Card messages.

struct CardInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingCardDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage
  @ObservedObject var delegateBridge: DelegateBridge = DelegateBridge()

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  @ViewBuilder
  func overlayView() -> some View {
    if let cardMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingCardDisplay,
      let delegate = delegateBridge.inAppMessageData?.1 {
      closure(cardMessage, delegate).onAppear { delegate.impressionDetected?(for: cardMessage) }
    } else {
      EmptyView()
    }
  }
}

public extension View {
  func cardInAppMessage<Content: View>(closure: @escaping (InAppMessagingCardDisplay,
                                                           InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(CardInAppMessageDisplayViewModifier(closure: closure))
  }
}

// MARK: Bridge to Firebase In-App Messaging SDK.

class DelegateBridge: NSObject, InAppMessagingDisplay, InAppMessagingDisplayDelegate,
  ObservableObject {
  @Published var inAppMessageData: (InAppMessagingDisplayMessage,
                                    InAppMessagingDisplayDelegate)? = nil

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
                        dismissType: FIRInAppMessagingDismissType) {
    DispatchQueue.main.async {
      self.inAppMessageData = nil
    }
  }
}
