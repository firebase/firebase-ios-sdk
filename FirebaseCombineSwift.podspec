Pod::Spec.new do |s|
  s.name             = 'FirebaseCombineSwift'
  s.version          = '7.1.0-beta'
  s.summary          = 'Swift extensions with Combine support for Firebase'

  s.description      = <<-DESC
  Combine Puboishers for Firebase.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.social_media_url = 'https://twitter.com/Firebase'
  s.swift_version         = '5.0'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '7.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.requires_arc            = true
  source = 'FirebaseCombineSwift/Sources/'  
  s.source_files = [
    source + '**/*.swift',
  ]

  s.dependency 'FirebaseCore', '~> 7.0'
  s.dependency 'FirebaseAuth', '~> 7.0'
  s.dependency 'FirebaseFirestore', '~> 7.0'

  s.test_spec 'unit' do |unit_tests|
    # Unit tests can't run on watchOS.
    unit_tests.platforms = {:ios => '13.0', :osx => '10.11', :tvos => '10.0'}
    unit_tests.source_files = 'FirebaseCombineSwift/Tests/Unit/**/*.swift'
    # app_host is needed for tests with keychain
    unit_tests.requires_app_host = true
    unit_tests.dependency 'OCMock'
  end
end
