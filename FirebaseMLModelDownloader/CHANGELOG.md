# 12.19.0
- [fixed] Fixed an issue with a transitive import in the device logger, which could cause
  a build error in explicit module mode. (#16563)

# 12.17.0
- [deprecated] Firebase ML is deprecated and will be shut down on June 15, 2027.
  To host custom models, you must migrate to another solution. You can use Cloud
  Storage for Firebase as an alternative for hosting custom models. For more
  info, see https://firebase.google.com/docs/ml/migrate-to-cloud-storage.

# 12.8.0
- [fixed] Remove unused legacy telemetry along with the large swift-protobuf dependency.
