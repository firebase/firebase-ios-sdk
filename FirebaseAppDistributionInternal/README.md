This library currently contains upcoming changes, and isn't meant to be used in production.

It exists in `master` for CI purposes.

## Steps to copy over changes in FirebaseAppDistributionInternal to master

For CI builds, this pod needs to be in master. To copy over changes, do the following:

1. `git checkout -b fad/appdistributioninternal`
1. `git checkout fad/in-app-feedback FirebaseAppDistributionInternal/`

Then open a PR to merge these changes to master. This won't affect the public version of `FirebaseAppDistribution`.