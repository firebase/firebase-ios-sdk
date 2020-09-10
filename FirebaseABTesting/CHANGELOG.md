# v4.3.0
- [changed] Enabled Firebase ABTesting to be a soft dependency. To use enable ABTesting,
  make sure to include `Firebase/ABTesting` in the Podfile. This will be required at the next
  major release.

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
