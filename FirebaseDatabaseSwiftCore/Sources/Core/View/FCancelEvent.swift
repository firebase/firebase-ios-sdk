//
//  File.swift
//  
//
//  Created by Morten Bek Ditlevsen on 09/03/2022.
//

import Foundation


@objc public class FCancelEvent: NSObject, FEvent {
    @objc public var eventRegistration: FEventRegistration
    @objc public var error: Error
    @objc public var path: FPath

    @objc public init(eventRegistration: FEventRegistration, error: Error, path: FPath) {
        self.eventRegistration = eventRegistration
        self.error = error
        self.path = path
    }

    public func fireEventOnQueue(_ queue: DispatchQueue) {
        eventRegistration.fireEvent(self, queue: queue)
    }
    public var isCancelEvent: Bool { true }
    public override var description: String {
        "\(path): cancel"
    }
}
