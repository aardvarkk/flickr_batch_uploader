require 'find'
require 'flickraw' # flickr API
require 'trollop' # Command line parsing
require 'yaml' # For storing user data

# Extensions we care about
EXTS = %w(.jpg .jpeg .gif .png .tif .tiff)
SECRET_FILENAME = 'secret'
SETTINGS_FILENAME = 'settings.yaml'

FlickRaw.api_key = '2ce063626721827c2f7983a402ed16da' # Our API key
FlickRaw.shared_secret = File.read(SECRET_FILENAME) # Read in the secret

# Command line options
opts = Trollop::options do
  opt :root, 'Root directory', type: :string, default: '.'
  opt :auto_skip, 'Automatically skip existing sets', type: :boolean, default: true
  opt :auto_add, 'Automatically add non-existent sets', type: :boolean, default: true
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

# Setup vars
to_upload = []
set_title = ''
set_desc = ''

# Recurse folders to find material to upload
Find.find(opts[:root]) do |path|
  
  # It's a directory
  if FileTest.directory?(path)
    
    # If we have anything sitting in to_upload, we should upload here
    if to_upload.empty?
      puts "No valid files found in previous directory"
    else
      puts "Found #{to_upload.size} files"

      # p 'To Upload:'
      # p to_upload
        
      puts "About to upload set '#{set_title}'"

      # Does the set exist?
      existing_id = nil
      photosets.each do |set|
        if set["title"] == set_title and set["desciption"] == set_desc
          existing_id = set["id"]
          break
        end
      end

      # Warning
      puts "WARNING: Set '#{set_title}' already exists" if existing_id

      # Upload all of the images
      puts "Would you like to upload #{to_upload.size} files to set '#{set_title}' with description '#{set_desc}'" + (existing_id ? ' anyway?' : '?') + " (y/n)"

      # UPLOAD
      uploaded = []
      if opts[:auto_add] or gets.strip.downcase == 'y'
        to_upload.each do |file|
          title = File.basename(file)
          desc  = nil
          print "Uploading file #{File.basename(file)} with title '#{title}' and description '#{desc}'"
          uploaded << flickr.upload_photo(file, :title => title, :description => desc)
          puts "...OK"
        end
      end

      # Create the set afterward, assigning the first image to the set cover
      unless uploaded.empty?

        # Use the existing one if it's already there
        photoset_id = existing_id ? existing_id : flickr.photosets.create(:title => set_title, :description => set_desc, :primary_photo_id => uploaded.first)

        puts "Created set '#{set_title}'"

        # Add all of the images to it
        # Drop the first item since we used it to create the set
        puts "Adding images to set"
        uploaded.drop(1).each { |photo_id| flickr.photosets.addPhoto(:photoset_id => photoset_id["id"], :photo_id => photo_id) }

        # Final status
        puts "Added #{uploaded.size} images to set '#{set_title}'"

      end

      # Done
      to_upload.clear

    end

    # Generate a set name and description from the folder
    parent = path.split(File::SEPARATOR).last
    partitions = parent.partition(" - ")
    set_title = partitions.first
    set_desc = partitions.last

    # If it's existing and we're on auto-skip, we can hop through this folder
    set_exists = photosets.any? { |set| set_title == set["title"] and set_desc == set["description"] }
    if opts[:auto_skip] and set_exists
      puts "Skipping set '#{set_title}' because it already exists"
      Find.prune
    else
      puts "Processing set '#{set_title}'"
    end
  
  # It's a file -- we should already have a set_title and set_desc
  # These will come from our parent directory!
  else

    # Only care about files with specific extensions
    Find.prune unless EXTS.include?(File.extname(path).downcase)

    # Add to our set to upload
    to_upload << path

    # Debug
    # p 'File: ' + path

  end

end