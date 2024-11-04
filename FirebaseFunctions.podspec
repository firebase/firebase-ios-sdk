Pod::Spec.new do |s|
  s.name             = 'FirebaseFunctions'
  s.version          = '11.5.0'
  s.summary          = 'Cloud Functions for Firebase'

  s.description      = <<-DESC
Cloud Functions for Firebase.
                       DESC

  s.homepage         = 'https://developers.google.com/'
  s.license          = { :type => 'Apache-2.0', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version    = '5.9'

  ios_deployment_target = '13.0'
  osx_deployment_target = '10.15'
  tvos_deployment_target = '13.0'
  watchos_deployment_target = '7.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version = '>= 1.12.0'
  s.prefix_header_file = false

  s.source_files = [
    'FirebaseFunctions/Sources/**/*.swift',
  ]

  s.dependency 'FirebaseCore', '11.5'
  s.dependency 'FirebaseCoreExtension', '11.5'
  s.dependency 'FirebaseAppCheckInterop', '~> 11.0'
  s.dependency 'FirebaseAuthInterop', '~> 11.0'
  s.dependency 'FirebaseMessagingInterop', '~> 11.0'
  s.dependency 'FirebaseSharedSwift', '~> 11.0'
  s.dependency 'GTMSessionFetcher/Core', '>= 3.4', '< 5.0'

  s.test_spec 'objc' do |objc_tests|
    objc_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => '10.15',
      :tvos => tvos_deployment_target
    }
    objc_tests.source_files = [
      'FirebaseFunctions/Tests/ObjCIntegration/ObjC*'
    ]
    objc_tests.requires_app_host = true
  end

  s.test_spec 'integration' do |int_tests|
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'FirebaseFunctions/Tests/Integration/*.swift'
    int_tests.requires_app_host = true
  end
end
