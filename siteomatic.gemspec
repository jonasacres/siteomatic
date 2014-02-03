Gem::Specification.new do |s|
	s.name           = 'Siteomatic'
	s.version        = '1.0.0'
	s.date           = '2014-02-02'
	s.summary        = 'Automatic static website deployment interface from Github to Amazon S3'
	s.description    = 'Automatically deploys static websites based on a Push hook from Github. Creates domain names in Route 53 as needed. So, a push to the "green-buttons" branch can automatically create green-buttons.test.example.com in Route 53, aliased to an S3 bucket containing the branch contents.'
	s.authors        = ["Jonas Acres"]
	s.email          = 'acresjonas@gmail.com'
	s.files          = ['lib/siteomatic.rb']
	s.homepage       = 'http://github.com/jonasacres/siteomatic'
	s.license        = 'GPLv3'
end
