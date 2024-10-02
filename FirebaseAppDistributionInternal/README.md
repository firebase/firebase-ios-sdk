This library currently contains upcoming changes, and isn't meant to be used in production.

It exists in `main` for CI purposes.

## Steps to copy over changes in FirebaseAppDistributionInternal to main

For CI builds, this pod needs to be in main. To copy over changes, do the following:

1. `git checkout -b fad/appdistributioninternal`
1. `git checkout fad/in-app-feedback FirebaseAppDistributionInternal/`

Then open a PR to merge these changes to main. This won't affect the public version of `FirebaseAppDistribution`.