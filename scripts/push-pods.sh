# script to push all the io2018 pods
# When bootstrapping a repo, FirebaseCore must be pushed first, then
# FirebaseInstanceID, then FirebaseAnalytics, then the rest
# Most of the warnings are tvOS specific. The Firestore one needs
# investigation.

pod repo push io2018 FirebaseCore.podspec
pod repo push io2018 FirebaseAuth.podspec --allow-warnings
pod repo push io2018 FirebaseDatabase.podspec --allow-warnings
pod repo push io2018 FirebaseFirestore.podspec --allow-warnings
pod repo push io2018 FirebaseFunctions.podspec
pod repo push io2018 FirebaseMessaging.podspec
pod repo push io2018 FirebaseStorage.podspec --allow-warnings
