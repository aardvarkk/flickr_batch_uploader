require 'find'
require 'flickraw' # flickr API
require 'trollop' # Command line parsing
require 'yaml' # For storing user data

require_relative 'uploader' # To upload stuff

# Extensions we care about
JPGS = %w(.jpg .jpeg)
EXTS = JPGS + %w(.gif .png .tif .tiff)
SECRET_FILENAME = 'secret'
SETTINGS_FILENAME = 'settings.yaml'
PROBLEMS = %w(WARNING ERROR)

FlickRaw.api_key = '2ce063626721827c2f7983a402ed16da' # Our API key
FlickRaw.shared_secret = File.read(SECRET_FILENAME) # Read in the secret

# Command line options
opts = Trollop::options do
  opt :root, 'Root directory', type: :string, default: '.'
end

# Read in the settings
settings = {}
settings = YAML::load_file SETTINGS_FILENAME rescue

# flickr authentication if we don't have that info
unless settings.has_key?(:access_token) and settings.has_key?(:access_secret)

  token    = flickr.get_request_token
  auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')

  puts "Open this url in your process to complete the authication process : #{auth_url}"
  puts "Copy here the number given when you complete the process."
  verify = gets.strip

  begin
    flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
    login = flickr.test.login
    puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"
  rescue FlickRaw::FailedResponse => e
    abort "Authentication failed : #{e.msg}"
  end

  # Set up the settings and save the file for next time
  begin
    settings[:access_token] = flickr.access_token
    settings[:access_secret] = flickr.access_secret
    settings[:username] = login.username
    settings[:id] = login.id
    File.open(SETTINGS_FILENAME, 'w') {|f| f.write(settings.to_yaml) }
  rescue Exception
    puts $!, $@
    abort "Unable to save authentication data"
  end

end

# Test that we're logged in
flickr.access_token  = settings[:access_token]
flickr.access_secret = settings[:access_secret]
flickr.test.login

# Get a list of the user's existing photosets
puts "Getting list of your photosets"
photosets = flickr.photosets.getList(:user_id => settings[:id]).to_a
puts "Found #{photosets.size} photosets"

# Debug: Print out the photosets
# photosets.each { |set| p set }

# Recurse folders to find material to upload
Find.find(opts[:root]) do |path|

  # Get the set title and description for this path
  dir = File.directory?(path) ? path : File.dirname(path)
  partitions = dir.split(File::SEPARATOR).last.partition(" - ")
  set_title = partitions.first
  set_desc = partitions.last

  # If it's a directory, we may want to skip the whole thing if the set already exists
  if File.directory?(path)
    puts "Entering folder #{path}"
    
    # Check if it exists
    exists = Uploader.get_existing_photoset(set_title, set_desc, photosets)

    # Is the photo count correct for the images we support?
    if exists

      # Get the online count
      online_count = flickr.photosets.getInfo(:photoset_id => exists["id"])["photos"]
      puts "Found #{online_count} online photos"

      # Get the local count
      local_count = 0
      EXTS.each do |ext|
        dir_check = "#{path}#{File::SEPARATOR}*#{ext}"
        # puts "Checking path #{dir_check}"
        local_count += Dir.glob(dir_check, File::FNM_CASEFOLD).count
      end
      puts "Counted #{local_count} local photos"

      # Compare them
      # We have ones we missed!
      if online_count < local_count
        puts "There are local photos missing online!"
        puts "We'll add them."
        next
      elsif online_count == local_count
        puts "Skipping set '#{set_title}' because it already exists"
        Find.prune
      else
        abort("Aborting because there are more photos in your online set than locally")
      end

    else
      next
    end
  end

  # Only care about files and certain extensions
  next unless EXTS.include?(File.extname(path).downcase)

  # # Does the set exist?
  # existing_id = nil
  # photosets.each do |set|
  #   if set["title"] == set_title and set["desciption"] == set_desc
  #     existing_id = set["id"]
  #     break
  #   end
  # end

  # # Warning
  # puts "WARNING: Set '#{set_title}' already exists" if existing_id

  # # Upload all of the images
  # puts "Would you like to upload #{set_upload.size} files to set '#{set_title}' with description '#{set_desc}'" + (existing_id ? ' anyway?' : '?') + " (y/n)"

  # if opts[:auto_add] or gets.strip.downcase == 'y'

  Uploader.do_upload(path, set_title, set_desc, photosets)

  # Debug
  # p 'File: ' + path

end
