import FirebaseInAppMessaging
import SwiftUI

// Handle delegate for FIAM actions.
struct CustomInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  // Closures for different message sub-types.
  var imageOnlyClosure: ((InAppMessagingImageOnlyDisplay, InAppMessagingDisplayDelegate)
    -> DisplayMessage)?
  var bannerClosure: ((InAppMessagingBannerDisplay, InAppMessagingDisplayDelegate)
    -> DisplayMessage)?
  var modalClosure: ((InAppMessagingModalDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage)?
  var cardClosure: ((InAppMessagingCardDisplay, InAppMessagingDisplayDelegate) -> DisplayMessage)?

  @ObservedObject var delegateBridge: DelegateBridge = DelegateBridge()

  init(imageOnlyClosure: ((InAppMessagingImageOnlyDisplay, InAppMessagingDisplayDelegate)
         -> DisplayMessage)? = nil,
  bannerClosure: ((InAppMessagingBannerDisplay, InAppMessagingDisplayDelegate)
    -> DisplayMessage)? = nil,
  modalClosure: ((InAppMessagingModalDisplay,
                  InAppMessagingDisplayDelegate)
      -> DisplayMessage)? =
    nil,
  cardClosure: ((InAppMessagingCardDisplay,
                 InAppMessagingDisplayDelegate)
      -> DisplayMessage)? =
    nil) {
    self.imageOnlyClosure = imageOnlyClosure
    self.bannerClosure = bannerClosure
    self.modalClosure = modalClosure
    self.cardClosure = cardClosure
  }

  func body(content: Content) -> some View {
    return content.overlay(overlayView())
  }

  func overlayView() -> some View {
    if let imageOnlyMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingImageOnlyDisplay,
      let delegate = delegateBridge.inAppMessageData?.1,
      let closure = imageOnlyClosure {
      return AnyView(closure(imageOnlyMessage, delegate))
    }

    if let bannerMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingBannerDisplay,
      let delegate = delegateBridge.inAppMessageData?.1,
      let closure = bannerClosure {
      return AnyView(closure(bannerMessage, delegate))
    }

    if let modalMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingModalDisplay,
      let delegate = delegateBridge.inAppMessageData?.1,
      let closure = modalClosure {
      return AnyView(closure(modalMessage, delegate))
    }

    if let cardMessage = delegateBridge.inAppMessageData?.0 as? InAppMessagingCardDisplay,
      let delegate = delegateBridge.inAppMessageData?.1,
      let closure = cardClosure {
      return AnyView(closure(cardMessage, delegate))
    }

    return AnyView(EmptyView())
  }
}

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

public extension View {
  func imageOnlyInAppMessage<Content: View>(closure: @escaping (InAppMessagingImageOnlyDisplay,
                                                                InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(CustomInAppMessageDisplayViewModifier(imageOnlyClosure: closure))
  }
}

public extension View {
  func bannerInAppMessage<Content: View>(closure: @escaping (InAppMessagingBannerDisplay,
                                                             InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(CustomInAppMessageDisplayViewModifier(bannerClosure: closure))
  }
}

public extension View {
  func modalInAppMessage<Content: View>(closure: @escaping (InAppMessagingModalDisplay,
                                                            InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(CustomInAppMessageDisplayViewModifier(modalClosure: closure))
  }
}

public extension View {
  func cardInAppMessage<Content: View>(closure: @escaping (InAppMessagingCardDisplay,
                                                           InAppMessagingDisplayDelegate)
      -> Content)
    -> some View {
    modifier(CustomInAppMessageDisplayViewModifier(cardClosure: closure))
  }
}
