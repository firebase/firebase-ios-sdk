Pod::Spec.new do |s|
    s.name             = 'GoogleAppMeasurementOnDeviceConversion'
    s.version          = '10.13.0'
    s.summary          = <<-SUMMARY
    On device conversion measurement plugin for Google App Measurement. Not
    intended for direct use.
    SUMMARY

    s.description      = <<-DESC
    On device conversion measurement plugin for Google App Measurement. This
    pod does not expose any headers and isn't intended for direct use, but
    rather as a plugin of Google App Measurement.
    DESC

    s.homepage         = 'https://developers.google.com/ios'
    s.license          = { :type => 'Copyright', :text => 'Copyright 2022 Google' }
    s.authors          = 'Google, Inc.'

    s.source           = {
        :http => 'https://dl.google.com/firebase/ios/analytics/69bb50195b3d6c40/GoogleAppMeasurementOnDeviceConversion-10.10.0.tar.gz'
    }

    s.cocoapods_version = '>= 1.10.2'

    s.ios.deployment_target  = '10.0'

    s.libraries  = 'c++'

    s.vendored_frameworks = 'Frameworks/GoogleAppMeasurementOnDeviceConversion.xcframework'
end

