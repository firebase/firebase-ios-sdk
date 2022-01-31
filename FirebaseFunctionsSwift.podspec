Pod::Spec.new do |s|
  s.name                    = 'FirebaseFunctionsSwift'
  s.version                 = '8.12.0-beta'
  s.summary                 = 'Swift Extensions for Firebase Functions'

  s.description      = <<-DESC
Swift SDK Extensions for Cloud Functions for Firebase.
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
    'FirebaseFunctionsSwift/Sources/**/*.swift',
  ]

  s.dependency 'FirebaseCore', '~> 8.12'
  s.dependency 'FirebaseSharedSwift', '~> 8.12'
  s.dependency 'GTMSessionFetcher/Core', '~> 1.5'

  s.test_spec 'integration' do |int_tests|
    int_tests.platforms = {
      :ios => ios_deployment_target,
      :osx => osx_deployment_target,
      :tvos => tvos_deployment_target
    }
    int_tests.source_files = 'FirebaseFunctionsSwift/Tests/Integration/*.swift'
  end
end
