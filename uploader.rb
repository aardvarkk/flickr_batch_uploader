class Uploader

  # Does the set already exist?
  def self.get_existing_photoset(set_title, set_desc, photosets)
    found = nil
    photosets.each do |set| 
      if set_title == set["title"] and set_desc == set["description"]
        found = set
        break
      end
    end
    return found
  end

  def self.get_or_create_photoset(photo, set_title, set_desc, photosets)
    # Try to get existing photoset, and use that if it's thre
    existing = Uploader.get_existing_photoset(set_title, set_desc, photosets)
    return existing, false if existing

    # Create the photoset
    response = flickr.photosets.create(:title => set_title, :description => set_desc, :primary_photo_id => photo)
    puts "Created set '#{set_title}' with description '#{set_desc}'"

    # Need to add it so that we discover it next time around
    added = { "id" => response["id"], "title" => set_title, "description" => set_desc }
    photosets << added 
    return added, true
  end

  def self.do_upload(path, set_title, set_desc, photosets)

    puts "About to upload #{File.basename(path)}"

    # Get a name and description
    title = File.basename(path)
    desc  = nil

    # Log what we're looking for
    puts "Searching for set with title " + title.to_s + " and description " + desc.to_s

    # Check if this file already exists
    # For it to already exist, its set must exist, and the title must match
    existing = Uploader.get_existing_photoset(set_title, set_desc, photosets)
    if existing

      puts "Found existing photoset with id " + existing["id"]

      # Does the file already exist?
      # Get the whole list of photos and see if there's a matching title
      # puts "Getting photos in this photoset"
      # Sometimes this seems to fail on the first photo, so we'll keep going until it succeeds
      begin
        photos = flickr.photosets.getPhotos(:photoset_id => existing["id"])["photo"]
      rescue
        puts "Failed Response. Retrying..."
        retry
      end

      # puts "Got the photos"
      photos.each do |photo|
        if title == photo["title"]
          puts "#{File.basename(path)} already exists in the set. Skipping..."
          return
        end
      end
    end

    # Check integrity if we support it
    if JPGS.include?(File.extname(path).downcase)
      puts "Checking integrity of file #{File.basename(path)}"
      check = `jpeginfo -c "#{path}"` 
      if PROBLEMS.any? { |p| check.include?(p) }
        puts "Found an error in file #{path}."
        puts "Please fix it before trying to upload." 
        abort    
      end
      puts "Integrity OK!"
    end

    # Do the actual upload
    print "Uploading file #{File.basename(path)} with title '#{title}' and description '#{desc}'"

    begin
      uploaded = flickr.upload_photo(path, :title => title, :description => desc)
    rescue
      puts "Failed upload. Retrying..."
      retry
    end
    
    puts "...OK"


    # Get or create the photoset if it doesn't exist
    photoset, was_created = Uploader.get_or_create_photoset(uploaded, set_title, set_desc, photosets)
    
    # Add it to the set
    unless was_created

      begin
        flickr.photosets.addPhoto(:photoset_id => photoset["id"], :photo_id => uploaded)
      rescue
        puts "Failed adding photo to set. Retrying..."
        retry
      end

      puts "Added #{File.basename(path)} to set '#{set_title}'"
      
    end

  end

end
