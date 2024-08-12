import FirebaseDataConnect
import Foundation

public extension DataConnect {
  static var kitchenSinkClient: KitchenSinkClient = {
    let dc = DataConnect.dataConnect(connectorConfig: KitchenSinkClient.connectorConfig)
    return KitchenSinkClient(dataConnect: dc)
  }()
}

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
