Pod::Spec.new do |s|
  s.name                    = 'FirebaseFunctions'
  s.version                 = '8.12.0'
  s.summary          = 'Cloud Functions for Firebase'

  s.description      = <<-DESC
Cloud Functions for Firebase.
                       DESC

  s.homepage                = 'https://developers.google.com/'
  s.license                 = { :type => 'Apache', :file => 'LICENSE' }
  s.authors                 = 'Google, Inc.'

  s.source                  = {
    :git => 'https://github.com/Firebase/firebase-ios-sdk.git',
    :tag => 'CocoaPods-' + s.version.to_s
  }

  s.swift_version           = '5.3'

  ios_deployment_target = '10.0'
  osx_deployment_target = '10.12'
  tvos_deployment_target = '10.0'
  watchos_deployment_target = '6.0'

  s.ios.deployment_target = ios_deployment_target
  s.osx.deployment_target = osx_deployment_target
  s.tvos.deployment_target = tvos_deployment_target
  s.watchos.deployment_target = watchos_deployment_target

  s.cocoapods_version       = '>= 1.4.0'
  s.prefix_header_file      = false

  s.source_files = [
    'FirebaseFunctions/Sources/**/*.swift',
  ]

  s.dependency 'FirebaseCore', '~> 8.12'
  s.dependency 'FirebaseCoreInternal', '~> 8.12'
  s.dependency 'FirebaseAppCheckInterop', '~> 8.12'
  s.dependency 'FirebaseAuthInterop', '~> 8.12'
  s.dependency 'FirebaseMessagingInterop', '~> 8.12'
  s.dependency 'FirebaseSharedSwift', '~> 8.12'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.5'

  s.test_spec 'integration' do |int_tests|
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'FirebaseFunctions/Tests/Integration/*.swift'
  end
end
