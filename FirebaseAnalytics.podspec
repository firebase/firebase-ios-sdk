Pod::Spec.new do |s|
    s.name             = 'FirebaseAnalytics'
    s.version          = '11.5.0'
    s.summary          = 'Firebase Analytics for iOS'

    s.description      = <<-DESC
    Firebase Analytics is a free, out-of-the-box analytics solution that
    inspires actionable insights based on app usage and user engagement.
    DESC

    s.homepage         = 'https://firebase.google.com/features/analytics/'
    s.license          = { :type => 'Copyright', :text => 'Copyright 2022 Google' }
    s.authors          = 'Google, Inc.'

    s.source           = {
        :http => 'https://dl.google.com/firebase/ios/analytics/edf73aefd77661bd/FirebaseAnalytics-11.4.0.tar.gz'
    }

    s.cocoapods_version = '>= 1.12.0'
    s.swift_version     = '5.9'

    s.ios.deployment_target  = '12.0'
    s.osx.deployment_target  = '10.15'
    s.tvos.deployment_target = '13.0'

    s.libraries  = 'c++', 'sqlite3', 'z'
    s.frameworks = 'StoreKit'

    s.dependency 'FirebaseCore', '11.5'
    s.dependency 'FirebaseInstallations', '~> 11.0'
    s.dependency 'GoogleUtilities/AppDelegateSwizzler', '~> 8.0'
    s.dependency 'GoogleUtilities/MethodSwizzler', '~> 8.0'
    s.dependency 'GoogleUtilities/NSData+zlib', '~> 8.0'
    s.dependency 'GoogleUtilities/Network', '~> 8.0'
    s.dependency 'nanopb', '~> 3.30910.0'

    s.default_subspecs = 'AdIdSupport'

    s.subspec 'AdIdSupport' do |ss|
        ss.dependency 'GoogleAppMeasurement', '11.5.0'
        ss.vendored_frameworks = 'Frameworks/FirebaseAnalytics.xcframework'
    end

    s.subspec 'WithoutAdIdSupport' do |ss|
        ss.dependency 'GoogleAppMeasurement/WithoutAdIdSupport', '11.5.0'
        ss.vendored_frameworks = 'Frameworks/FirebaseAnalytics.xcframework'
    end

end
