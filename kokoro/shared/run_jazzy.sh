#!/usr/bin/env bash

set -euxo pipefail

pushd "$1"

mkdir FirebaseInstanceID;
mkdir FirebaseInstallations;
mkdir FirebaseCore;

cp -r FirebaseAnalytics/FirebaseInstallations.framework FirebaseInstallations/FirebaseInstallations.framework;
cp -r FirebaseAnalytics/FirebaseCore.framework FirebaseCore/FirebaseCore.framework;
cp -r FirebaseAnalytics/FirebaseInstanceID.framework FirebaseInstanceID/FirebaseInstanceID.framework;

popd
