Pod::Spec.new do |s|
  s.name         = "WPIAPManager"
  s.version      = "0.1"
  s.summary      = "WPIAPManager"
  s.homepage     = "https://github.com/wenyhooo/WPIAPManager"
  s.license      = 'MIT'
  s.authors      = { "wenyhooo" => "871531334@qq.com"}
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/wenyhooo/WPIAPManager.git" ,:tag => s.version}
  s.source_files = 'WPIAPManager/*.{h,m,mm}'
  s.requires_arc = true
  s.frameworks = 'UIKit','CoreFoundation'
  s.dependency 'UICKeyChainStore', '~> 2.0.7'
end