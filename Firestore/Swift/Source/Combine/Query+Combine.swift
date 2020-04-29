/*
 * Copyright 2020 Google LLC
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

#if canImport(Combine)
  import Combine

  import Foundation
  import FirebaseFirestore

  @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
  extension Query {
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
    public struct QuerySnapshotPublisher: Publisher {
      public typealias Output = QuerySnapshot
      public typealias Failure = Error

      private let query: Query

      init(_ query: Query) {
        self.query = query
      }

      public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure,
        Self.Output == S.Input {
        let subscription = QuerySnaphotSubscription(subscriber: subscriber, query: query)
        subscriber.receive(subscription: subscription)
      }
    }

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
    fileprivate class QuerySnaphotSubscription<SubscriberType: Subscriber>: Subscription
      where SubscriberType.Input == QuerySnapshot, SubscriberType.Failure == Error {
      private var subscriber: SubscriberType?
      private var registration: ListenerRegistration?

      init(subscriber: SubscriberType, query: Query) {
        self.subscriber = subscriber

        registration = query.addSnapshotListener { querySnapshot, error in
          if let error = error {
            subscriber.receive(completion: .failure(error))
          } else if let querySnapshot = querySnapshot {
            _ = subscriber.receive(querySnapshot)
          }
        }
      }

      func request(_ demand: Subscribers.Demand) {}

      func cancel() {
        registration?.remove()
        registration = nil
        subscriber = nil
      }
    }

    public func snapshotPublisher() -> QuerySnapshotPublisher {
      return QuerySnapshotPublisher(self)
    }
  }

#endif
