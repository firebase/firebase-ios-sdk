Pod::Spec.new do |s|
  s.name             = 'GoogleUtilities'
  s.version          = '5.0.5'
  s.summary          = 'Google Utilities for iOS (plus community support for macOS and tvOS)'

  s.description      = <<-DESC
Internal Google Utilities including Network, Reachability Environment, Logger, and Swizzling for
other Google CocoaPods. They're not intended for direct public usage.
                       DESC

# TODO update homepage link with GoogleUtilities is moved to another repo.
  s.homepage         = 'https://github.com/firebase/firebase-ios-sdk'
  s.license          = { :type => 'Apache', :file => 'LICENSE' }
  s.authors          = 'Google, Inc.'

  s.source           = {
    :git => 'https://github.com/firebase/firebase-ios-sdk.git',
# Undo comment before release.
#    :tag => 'Utilities-' + s.version.to_s
    :tag => 'pre-5.3-' + s.version.to_s
  }
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '10.0'

  s.cocoapods_version = '>= 1.4.0'
  s.prefix_header_file = false

  s.subspec 'Environment' do |es|
    es.source_files = 'GoogleUtilities/Environment/third_party/*.[mh]'
    es.public_header_files = 'GoogleUtilities/Environment/third_party/*.h'
    es.private_header_files = 'GoogleUtilities/Environment/third_party/*.h'
  end

  s.subspec 'Logger' do |ls|
    ls.source_files = 'GoogleUtilities/Logger/**/*.[mh]'
    ls.public_header_files = 'GoogleUtilities/Logger/Private/*.h', 'GoogleUtilities/Logger/Public/*.h'
    ls.private_header_files = 'GoogleUtilities/Logger/Private/*.h'
    ls.dependency 'GoogleUtilities/Environment'
  end

  s.subspec 'Network' do |ns|
    ns.source_files = 'GoogleUtilities/Network/**/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/Network/Private/*.h'
    ns.private_header_files = 'GoogleUtilities/Network/Private/*.h'
    ns.dependency 'GoogleUtilities/NSData+zlib'
    ns.dependency 'GoogleUtilities/Logger'
    ns.dependency 'GoogleUtilities/Reachability'
    ns.frameworks = [
      'Security'
    ]
  end

  s.subspec 'NSData+zlib' do |ns|
    ns.source_files = 'GoogleUtilities/NSData+zlib/*.[mh]'
    ns.public_header_files = 'GoogleUtilities/NSData+zlib/GULNSData+zlib.h'
    ns.libraries = [
      'z'
    ]
  end

  s.subspec 'Reachability' do |rs|
    rs.source_files = 'GoogleUtilities/Reachability/**/*.[mh]'
    rs.public_header_files = 'GoogleUtilities/Reachability/Private/*.h'
    rs.private_header_files = 'GoogleUtilities/Reachability/Private/*.h'
    rs.frameworks = [
      'SystemConfiguration'
    ]
    rs.dependency 'GoogleUtilities/Logger'
  end
end
