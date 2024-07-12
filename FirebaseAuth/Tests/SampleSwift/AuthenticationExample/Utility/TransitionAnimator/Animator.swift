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

import UIKit

class Animator: NSObject, UIViewControllerAnimatedTransitioning {
  enum TransitionDirection {
    case right
    case left
  }

  let transitionDuration: Double = 0.20
  let transitionDirection: TransitionDirection

  init(_ direction: TransitionDirection) {
    transitionDirection = direction
  }

  func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?)
    -> TimeInterval {
    return transitionDuration as TimeInterval
  }

  func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
    let container = transitionContext.containerView

    guard let fromView = transitionContext.view(forKey: .from),
          let toView = transitionContext.view(forKey: .to) else {
      transitionContext.completeTransition(false)
      return
    }

    let translation: CGFloat = transitionDirection == .right ? container.frame.width : -container
      .frame.width
    let toViewStartFrame = container.frame
      .applying(CGAffineTransform(translationX: translation, y: 0))
    let fromViewFinalFrame = container.frame
      .applying(CGAffineTransform(translationX: -translation, y: 0))

    container.addSubview(toView)
    toView.frame = toViewStartFrame

    UIView.animate(withDuration: transitionDuration, animations: {
      fromView.frame = fromViewFinalFrame
      toView.frame = container.frame

    }) { _ in
      fromView.removeFromSuperview()
      transitionContext.completeTransition(true)
    }
  }
}
