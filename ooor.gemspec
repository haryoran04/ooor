Gem::Specification.new do |s|
  s.name = %q{ooor}
  s.version = "1.0.1"
  s.date = %q{2009-10-31}
  s.authors = ["Raphael Valyi - www.akretion.com"]
  s.email = %q{rvalyi@akretion.com}
  s.summary = %q{OpenObject on Rails}
  s.homepage = %q{http://github.com/rvalyi/ooor}
  s.description = %q{OOOR exposes business object proxies to your Ruby (Rails or not) application, that map seamlessly to your remote OpenObject/OpenERP server using webservices. It extends the standard ActiveResource API.}
  s.files = [ "README.md", "MIT-LICENSE", "lib/ooor.rb", "lib/app/models/open_object_resource.rb", "lib/app/controllers/open_objects_controller.rb"]
  s.add_dependency('activeresource')
end