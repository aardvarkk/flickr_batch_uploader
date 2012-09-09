require 'find'
require 'trollop' # Command line parsing

# Extensions we care about
JPGS = %w(.jpg .jpeg)
PROBLEMS = %w(WARNING ERROR)

# Command line options
opts = Trollop::options do
  opt :root, 'Root directory', type: :string, default: '.'
  opt :auto_fix, 'Automatically try fix files with warnings or errors', type: :boolean, default: true
end

# Recurse folders to find material to upload
Find.find(opts[:root]) do |path|
  
  # Only care about files
  next if FileTest.directory?(path)

  # Only care about jpegs
  next unless JPGS.include?(File.extname(path).downcase)

  # CHECK all of the jpg and jpeg files for errors and stop if they exist
  check = `jpeginfo -c "#{path}"`
  puts check
  if PROBLEMS.any? { |p| check.include?(p) }
    puts "Found an error in one of your files."
    if (opts[:auto_fix])
      fix = `jpegoptim -o "#{path}"`
      puts fix
    end
  end

end