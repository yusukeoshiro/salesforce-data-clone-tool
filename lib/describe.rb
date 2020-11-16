require 'httparty'
require 'fileutils'

instance_url = ARGV[0]
access_token = ARGV[1]

def describe_objects(instance_url, access_token, objects, interactive)

  puts ""
  puts ""
  puts ""
  puts "getting description of #{objects.size} objects..."

  object_fields = {}
  dependant_external_objects = [] # these are objects that are not being migrated, but are depended by those that are

  objects.each do |object|
    object = object.chomp # clean the input just in case
    object = object.upcase

    puts "  getting description of #{object}..."

    url = "#{instance_url}/services/data/v20.0/sobjects/#{object}/describe/"
    response = HTTParty.get(url, headers: {
      "Authorization": "Bearer #{access_token}"
    })
    result = JSON.parse(response.body)
    raise "ERROR failed get meta data from Salesforce check your auth information" if response.code != 200
    fields = result['fields']

    object_fields[object] = {
      'fields': [],
      'depends_on': [],
      'object': object,
    }

    fields.each do |field|
      object_fields[object][:fields].append({
        name: field['name'],
        type: field['type'],
        reference_to: field['referenceTo'],
        updateable: field['updateable'],
        createable: field['createable']
      })

      if field['referenceTo'].size > 0 # this is a reference field
        # are these objects in the migrating objects
        objects_not_in_list = field['referenceTo'] - objects
        dependant_external_objects.concat objects_not_in_list

        # add these to :depends_on field
        object_fields[object][:depends_on].concat(field['referenceTo'])
      end

    end

    object_fields[object][:depends_on] = object_fields[object][:depends_on].uniq          # remove duplicated
    # object_fields[object][:depends_on] = object_fields[object][:depends_on] & objects     # remove objects that are not passed
    object_fields[object][:depends_on] = object_fields[object][:depends_on].map(&:upcase) # upcase
    object_fields[object][:depends_on].delete(object)                                     # remove it self
  end

  dependant_external_objects = dependant_external_objects.uniq
  dependant_external_objects = dependant_external_objects.map(&:upcase)
  puts ""
  puts ""
  puts ""
  puts "ATTENTION looks like you need to migrate these objects too"
  puts "   #{dependant_external_objects.join(', ')}"
  puts ""
  puts "If you do not wish to migrate the objects yourself, we expect ID conversion table to be located in data/conversion_table/object_name.csv"

  if interactive
    puts "do you want to continue? [y]n"
    continue = STDIN.gets.chomp
    return if continue == 'n'
  end

  FileUtils.mkdir_p 'data'
  FileUtils.mkdir_p 'data/conversion_tables'
  FileUtils.mkdir_p 'data/import'
  FileUtils.mkdir_p 'data/export'

  File.open("data/object_fields.json", "w") { |f| f.write JSON.dump object_fields }
  File.open("data/dependant_external_objects.json", "w") { |f| f.write JSON.dump dependant_external_objects }
  return object_fields
end
