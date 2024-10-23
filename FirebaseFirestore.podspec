Pod::Spec.new do |s|
  s.name             = 'FirebaseFirestore'
  s.version          = '11.5.0'
  s.summary          = 'Google Cloud Firestore'
  s.description      = <<-DESC
Google Cloud Firestore is a NoSQL document database built for automatic scaling, high performance, and ease of application development.
                       DESC
  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache-2.0', :file => 'Firestore/LICENSE' }
  s.authors          = 'Google, Inc.'
  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'

  s.swift_version = '5.9'

  s.weak_framework = 'FirebaseFirestoreInternal'

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.public_header_files = 'FirebaseFirestoreInternal/**/*.h'

  s.requires_arc            = true
  s.source_files = [
    'FirebaseFirestoreInternal/**/*.[mh]',
    'Firestore/Swift/Source/**/*.swift',
  ]
  s.resource_bundles = {
    "#{s.module_name}_Privacy" => 'Firestore/Swift/Source/Resources/PrivacyInfo.xcprivacy'
  }

  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseCoreExtension', '11.5'
  s.dependency 'FirebaseFirestoreInternal', '11.5.0'
  s.dependency 'FirebaseSharedSwift', '~> 11.0'

end
