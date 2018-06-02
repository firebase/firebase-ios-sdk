Pod::Spec.new do |s|
  s.name             = 'FirebaseUtilities'
  s.version          = '5.0.2'
  s.summary          = 'Firebase Utilities for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Firebase Utilities including Network, Environment, Logger, and Swizzling.
                       DESC

  s.homepage         = 'https://firebase.google.com'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
# Undo comment before release
#    :tag => 'Utilities-' + s.version.to_s
    :tag => 'pre-5.3-' + s.version.to_s
  }
  s.social_media_url = 'https://twitter.com/Firebase'
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.static_framework = true
  s.prefix_header_file = false

  s.subspec 'Network' do |ns|
    ns.source_files = 'Firebase/Utilities/Network/**/*.[mh]'
    ns.public_header_files = 'Firebase/Utilities/Network/Private/*.h'
    ns.private_header_files = 'Firebase/Utilities/Network/Private/*.h'
    ns.frameworks = [
      'SystemConfiguration'
    ]
    ns.dependency 'GoogleToolboxForMac/NSData+zlib', '~> 2.1'
    ns.dependency 'FirebaseUtilities/Logger'
  end

  s.subspec 'Environment' do |es|
    es.source_files = 'Firebase/Utilities/Environment/third_party/*.[mh]'
    es.public_header_files = 'Firebase/Utilities/Environment/third_party/*.h'
    es.private_header_files = 'Firebase/Utilities/Environment/third_party/*.h'
  end

  s.subspec 'Logger' do |ls|
    ls.source_files = 'Firebase/Utilities/Logger/**/*.[mh]'
    ls.public_header_files = 'Firebase/Utilities/Logger/Private/*.h', 'Firebase/Utilities/Logger/Public/*.h'
    ls.private_header_files = 'Firebase/Utilities/Logger/Private/*.h'
    ls.dependency 'FirebaseUtilities/Environment'
  end
end
