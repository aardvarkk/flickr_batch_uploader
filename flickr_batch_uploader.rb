require 'flickraw' # flickr API
require 'trollop' # command line parsing

FlickRaw.api_key = '2ce063626721827c2f7983a402ed16da'
FlickRaw.shared_secret = File.read('secret')

opts = Trollop::options do
  opt :root, 'Root directory', :type => :string
end

p opts