#!/usr/bin/env ruby
# Fix Firebase Crashlytics header issues for Flutter iOS builds

require 'fileutils'

# Find the Firebase Crashlytics plugin directory
plugin_dir = File.expand_path("~/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.3.5/ios/Classes")
pods_dir = File.expand_path("Pods/Headers/Public")

puts "Starting Firebase Crashlytics header fix..."

def backup_and_patch_file(file_path)
  backup_path = "#{file_path}.orig"
  
  # Create backup if it doesn't exist
  unless File.exist?(backup_path)
    FileUtils.cp(file_path, backup_path)
    puts "Created backup: #{backup_path}"
  end
  
  # Read file content
  content = File.read(file_path)
  
  # Replace problematic import
  new_content = content.gsub(
    '#import <Firebase/Firebase.h>',
    "// Modified by fix_firebase_crashlytics.rb\n#import \"Firebase/Firebase.h\""
  )
  
  # Write back if changes were made
  if content != new_content
    File.write(file_path, new_content)
    puts "Patched: #{file_path}"
    return true
  end
  
  puts "No changes needed for: #{file_path}"
  return false
end

# Fix the plugin files
if Dir.exist?(plugin_dir)
  puts "Found Crashlytics plugin at: #{plugin_dir}"
  
  # List of files to patch
  files_to_patch = [
    "#{plugin_dir}/Crashlytics_Platform.h",
    "#{plugin_dir}/ExceptionModel_Platform.h"
  ]
  
  files_to_patch.each do |file|
    if File.exist?(file)
      backup_and_patch_file(file)
    else
      puts "Warning: File does not exist: #{file}"
    end
  end
else
  puts "Warning: Crashlytics plugin directory not found at: #{plugin_dir}"
end

# Create a simplified Firebase.h if needed
firebase_header_dir = "#{pods_dir}/Firebase"
if Dir.exist?(pods_dir)
  FileUtils.mkdir_p(firebase_header_dir) unless Dir.exist?(firebase_header_dir)
  
  firebase_header = "#{firebase_header_dir}/Firebase.h"
  custom_header_content = <<~HEADER
    // Custom Firebase.h created by fix_firebase_crashlytics.rb
    #ifndef Firebase_h
    #define Firebase_h
    
    #if __has_include(<FirebaseCore/FirebaseCore.h>)
      #import <FirebaseCore/FirebaseCore.h>
    #elif __has_include("FirebaseCore/FirebaseCore.h")
      #import "FirebaseCore/FirebaseCore.h"
    #endif
    
    #if __has_include(<FirebaseCrashlytics/FirebaseCrashlytics.h>)
      #import <FirebaseCrashlytics/FirebaseCrashlytics.h>
    #elif __has_include("FirebaseCrashlytics/FirebaseCrashlytics.h")
      #import "FirebaseCrashlytics/FirebaseCrashlytics.h"
    #endif
    
    #endif /* Firebase_h */
  HEADER
  
  # Only write if file doesn't exist or is different
  if !File.exist?(firebase_header) || File.read(firebase_header) != custom_header_content
    File.write(firebase_header, custom_header_content)
    puts "Created custom Firebase.h header at: #{firebase_header}"
  else
    puts "Custom Firebase.h header already exists and is up to date"
  end
else
  puts "Warning: Pods directory not found at: #{pods_dir}"
end

puts "Firebase Crashlytics header fix completed!" 