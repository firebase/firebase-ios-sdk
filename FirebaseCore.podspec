Pod::Spec.new do |s|
  s.name             = 'FirebaseCore'
  s.version          = '5.0.4'
  s.summary          = 'Firebase Core for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Firebase Core includes FIRApp and FIROptions which provide central configuration for other Firebase services.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
# Undo comment before release
#    :tag => 'Core-' + s.version.to_s
    :tag => 'pre-5.3-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.source_files = 'Firebase/Core/**/*.[mh]'
  s.public_header_files = 'Firebase/Core/Public/*.h', 'Firebase/Core/Private/*.h'
  s.private_header_files = 'Firebase/Core/Private/*.h', 'Firebase/Core/third_party/*.h', 'Firebase/Core/Network/*.h'
  s.frameworks = [
    'Foundation'
  ]
  s.dependency 'GoogleUtilities/Logger', '~> 5.0'
  # TODO delete next line, once FirebaseAnalytics pod is published with the dependency
  s.dependency 'GoogleUtilities/Network', '~> 5.0'
  # TODO delete next line, once FIREnvironment is completely replaced by GULEnvironment
  s.dependency 'GoogleUtilities/Environment', '~> 5.0'
  s.pod_target_xcconfig = {
    'OTHER_CFLAGS' => '-fno-autolink',
    'GCC_PREPROCESSOR_DEFINITIONS' =>
      'FIRCore_VERSION=' + s.version.to_s + ' Firebase_VERSION=5.3.0'
  }
end
