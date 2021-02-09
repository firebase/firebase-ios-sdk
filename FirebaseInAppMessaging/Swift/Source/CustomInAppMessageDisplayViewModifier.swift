import FirebaseInAppMessaging
import SwiftUI

// Handle delegate for FIAM actions.
struct CustomInAppMessageDisplayViewModifier<DisplayMessage: View>: ViewModifier {
  var closure: (InAppMessagingDisplayMessage, InAppMessagingDisplayDelegate) -> DisplayMessage

  @ObservedObject var delegateBridge: DelegateBridge = DelegateBridge()

  init(closure: @escaping (InAppMessagingDisplayMessage, InAppMessagingDisplayDelegate)
    -> DisplayMessage) {
    self.closure = closure
  }

  func body(content: Content) -> some View {
    let inAppMessageData = delegateBridge.inAppMessageData
    return content
      .overlay(inAppMessageData == nil ? AnyView(EmptyView()) :
        AnyView(closure(inAppMessageData!.0, inAppMessageData!.1)))
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

// View modifier that takes a closure for handling in-app message display.
public extension View {
  func onDisplayInAppMessage<T: View>(closure: @escaping (InAppMessagingDisplayMessage,
                                                          InAppMessagingDisplayDelegate) -> T)
    -> some View {
    modifier(CustomInAppMessageDisplayViewModifier(closure: closure))
  }
}
