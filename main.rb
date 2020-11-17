instance_url = ARGV[0]
access_token = ARGV[1]
objects      = ARGV[2]
source_user_name = ARGV[3]
source_password  = ARGV[4]
destination_user_name = ARGV[5]
destination_password  = ARGV[6]
interactive  = !(ARGV[7] == 'false')

raise 'instance_url is not provided' if !instance_url
raise 'access_token is not provided' if !access_token
raise 'objects are not provided'     if !objects
raise 'source_user_name are not provided'      if !source_user_name
raise 'source_password are not provided'       if !source_password
raise 'destination_user_name are not provided' if !destination_user_name
raise 'destination_password are not provided'  if !destination_password

objects = objects.split(',')

puts <<"_EOM_"


## DATA CLONER ##

instance_url: #{instance_url}
access_token: #{access_token}
objects: #{objects.size} objects
         #{objects[0..3].join(',')}...
source_user_name: #{source_user_name}
source_password: #{source_password}
destination_user_name: #{destination_user_name}
destination_password: #{destination_password}
_EOM_



if interactive
  puts "do you want to continue? [y]n"
  continue = STDIN.gets.chomp
  return if continue == 'n'
end

require './lib/describe'
object_fields = describe_objects(instance_url, access_token, objects, interactive)

require './lib/resolve_dependencies'
resolve_dependencies(interactive)

require './lib/export'
export(source_user_name, source_password)

require './lib/import'
import(destination_user_name, destination_password)

