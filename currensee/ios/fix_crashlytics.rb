#!/usr/bin/env ruby

require 'fileutils'

# Define path to the Firebase Crashlytics plugin
plugin_dir = File.expand_path("~/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios/Classes")

# Files that need fixing
files_to_fix = [
  "#{plugin_dir}/Crashlytics_Platform.h",
  "#{plugin_dir}/ExceptionModel_Platform.h"
]

puts "Starting fix for Firebase Crashlytics headers..."

# Fix each file
files_to_fix.each do |file_path|
  if File.exist?(file_path)
    # Create backup
    backup_path = "#{file_path}.orig"
    if !File.exist?(backup_path)
      FileUtils.cp(file_path, backup_path)
      puts "Created backup: #{backup_path}"
    end
    
    # Read the file content
    content = File.read(file_path)
    
    # Replace the problematic import
    modified_content = content.gsub('#import <Firebase/Firebase.h>', 
                                    '#import "Firebase.h"')
    
    # Write back to the file
    File.write(file_path, modified_content)
    puts "Fixed: #{file_path}"
  else
    puts "Warning: File not found: #{file_path}"
  end
end

puts "Firebase Crashlytics headers fixed!" 