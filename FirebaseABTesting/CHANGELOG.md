# v3.2.0
- [added] Added completion handler for FIRExperimentController's updateExperimentsWithServiceOrigin method.
- [deprecated] Deprecated `FIRExperimentController.updateExperiments(serviceOrigin:events:policy:lastStartTime:payloads:)`.
- [added] Added `FIRExperimentController.validateRunningExperiments(serviceOrigin:runningExperimentPayloads:)`, allowing callers to expire experiments that are no longer running.
- [added] Added `FIRExperimentController.activateExperiment(experimentPayload:origin:)`, allowing callers to directly activates an experiment.

# v3.1.1
- [fixed] Fixed an Analyzer issue (#3622).

# v3.1.0
- [added] Initial Open Source (#3507).
