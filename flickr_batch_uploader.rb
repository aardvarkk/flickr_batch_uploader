require 'flickraw'

FlickRaw.api_key = '2ce063626721827c2f7983a402ed16da'
FlickRaw.shared_secret = File.open('secret', 'r').read

puts FlickRaw.api_key
puts FlickRaw.shared_secret