Pod::Spec.new do |s|
  s.name         = "CVTEExtension"
  s.version      = "3.1.0-snapshot"
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.8'
  s.summary      = "A fast and convenient conversion between JSON and model"
  s.homepage     = "https://github.com/luhui/MJExtension"
  s.license      = "MIT"
  s.author             = { "luhui" => "luhui@cvte.com" }
  s.social_media_url   = "http://weibo.com/exceptions"
  s.source       = { :git => "https://github.com/luhui/MJExtension.git", :tag => s.version }
  s.source_files  = "MJExtension"
  s.requires_arc = true
end
