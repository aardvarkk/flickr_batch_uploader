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
    title = File.basename(path)
    desc  = nil
    print "Uploading file #{File.basename(path)} with title '#{title}' and description '#{desc}'"
    uploaded = flickr.upload_photo(path, :title => title, :description => desc)
    puts "...OK"

    # Get or create the photoset if it doesn't exist
    photoset, was_created = Uploader.get_or_create_photoset(uploaded, set_title, set_desc, photosets)
    
    # Add it to the set
    unless was_created
      flickr.photosets.addPhoto(:photoset_id => photoset["id"], :photo_id => uploaded)
      puts "Added #{File.basename(path)} to set '#{set_title}'"
    end

  end

end
