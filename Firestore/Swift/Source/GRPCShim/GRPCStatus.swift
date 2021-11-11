import GRPC

@objc public class GRPCStatusShim :NSObject {
    private var status: GRPCStatus
    @objc public override init(){
        status = GRPCStatus.ok
    }
}
