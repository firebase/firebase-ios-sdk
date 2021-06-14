# v8.2.0
- [fixed] Fixed analyze issue introduced in Xcode 12.5. (#8209)

# v7.7.0
- [added] Added community support for watchOS. ABTesting can now build on watchOS, but some functions might not work yet. (#7481)

# v7.0.0
- [removed] Removed `FIRExperimentController.updateExperiments(serviceOrigin:events:policy:lastStartTime:payloads:)`, which was deprecated. (#6543)

# v4.1.0
- [changed] Functionally neutral source reorganization for preliminary Swift Package Manager support. (#6016)

# v4.0.0
- [changed] Removed Protobuf dependency (#5890).

# v3.2.0
- [added] Added completion handler for FIRExperimentController's updateExperimentsWithServiceOrigin method.
- [deprecated] Deprecated `FIRExperimentController.updateExperiments(serviceOrigin:events:policy:lastStartTime:payloads:)`.
- [added] Added `FIRExperimentController.validateRunningExperiments(serviceOrigin:runningExperimentPayloads:)`, allowing callers to expire experiments that are no longer running.
- [added] Added `FIRExperimentController.activateExperiment(experimentPayload:origin:)`, allowing callers to directly activates an experiment.

# v3.1.1
- [fixed] Fixed an Analyzer issue (#3622).

# v3.1.0
- [added] Initial Open Source (#3507).
