Pod::Spec.new do |s|
  s.name         = "HIPNetworking"
  s.version      = "1.0.0"
  s.summary      = "iOS7 framework for simple and robust network handling, built on NSURLSession."
  s.homepage     = "https://github.com/Hipo/HIPNetworking"
  s.license      = { :type => 'Apache', :file => 'LICENSE' }
  s.authors      = { "Taylan Pince" => "taylan@hipolabs.com" }
  s.source       = { :git => "https://github.com/Hipo/HIPNetworking.git", :tag => "1.0.0" }
  s.platform     = :ios, '7.0'
  s.source_files = 'HIPNetworking/*.{h,m}'
  s.requires_arc = true
  s.dependency 'TMCache', '~> 1.2.0'
end
