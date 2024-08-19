import FirebaseDataConnect
import Foundation

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension DataConnect {
  static var kitchenSinkClient: KitchenSinkClient = {
    let dc = DataConnect.dataConnect(connectorConfig: KitchenSinkClient.connectorConfig)
    return KitchenSinkClient(dataConnect: dc)
  }()
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public class KitchenSinkClient {
  var dataConnect: DataConnect

  public static let connectorConfig = ConnectorConfig(
    serviceId: "fdc-kitchensink",
    location: "us-central1",
    connector: "kitchen-sink"
  )

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public func useEmulator(host: String = DataConnect.EmulatorDefaults.host,
                          port: Int = DataConnect.EmulatorDefaults.port) {
    dataConnect.useEmulator(host: host, port: port)
  }
}
