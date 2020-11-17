require 'json'
require 'csv'
require 'fileutils'

def import (username, password)
  file = File.open("data/object_fields.json")
  object_fields = JSON.parse(file.read)

  file = File.open("data/import_order.json")
  import_order = JSON.parse(file.read)
  id_map = {}

  # create SDL files
  puts "Creating SDL files..."
  puts ""
  import_order.each do |object|
    FileUtils.mkdir_p 'data/import/sdl'
    sdl_file_path = "data/import/sdl/#{object}.sdl"
    sdl = ''
    object_fields[object]['fields'].each do |field|
      sdl = sdl + "#{field['name']}=#{field['name']}\n" if field['createable']
    end
    File.open(sdl_file_path, "w") { |f| f.write sdl }
  end


  file = File.open("data/dependant_external_objects.json")
  dependant_external_objects = JSON.parse(file.read)


  dependant_external_objects.each do |object|
    if File.exist?("data/conversion_tables/#{object}.csv")
      records = CSV.read("data/conversion_tables/#{object}.csv")
      records[1..-1].each do |row|
        id_map[object] = {} if !id_map[object]
        id_map[object][row[0]] = row[1] if row[0]
      end
    else
      puts "WARNING!! CONVERSTION TABLE FOR #{object} was not found! It should be located at data/conversion_tables/#{object}.csv (case sensitive)"
      puts "YOU HAVE BEEN WARNED!!!"
      puts ""
    end
  end
  File.open("data/id_map.json", "w") { |f| f.write JSON.dump id_map }


  puts "Import ready..."
  puts ""

  # Convert Custom Object IDs... this is the main process!!
  import_order.each do |object|
    puts "  importing #{object}..."

    fields = object_fields[object]['fields']
    import_file_path = "data/import/#{object}-original.csv"
    converted_file_path = "data/import/#{object}-converted.csv"
    export_file_path = "data/export/#{object}.csv"

    FileUtils.cp export_file_path, import_file_path
    csv = CSV.read(import_file_path)

    header = csv[0]
    data = csv[1..-1]
    if data.size.zero?
      puts "    skipping because it is empty..."
      puts ""
      next
    end


    # convert ids
    depends_on = object_fields[object]['depends_on']
    unless depends_on.empty?
      fields_to_convert = fields.select{|f| f['reference_to'].any? && f['createable']}
      fields_to_convert.each do |f|
        index = header.index(f['name'].upcase)
        f['index'] = index
      end
      data.each do |row|
        fields_to_convert.each do |f|
          index = f['index']

          old_id = row[index]
          reference_to = f['reference_to'].map(&:upcase)
          reference_to.each do |o|
            next if id_map[o].nil?

            new_id = id_map[o][old_id]
            unless new_id.nil?
              row[index] = id_map[o][old_id]
              break
            end
          end
          raise "id conversion failed for #{old_id} which refers to #{reference_to.join(' or ')}" if row[index] == old_id
        end
      end
      puts "    id conversion successful!"
    end

    # write file
    CSV.open(converted_file_path,"w") do |f|
      new_header = header.clone
      new_header[0] = 'OLDID'
      f << new_header
      data.each do |row|
        f << row
      end
    end

    # import file
    bean = <<"_BEAN_"
<bean id=\"#{object}\" class=\"com.salesforce.dataloader.process.ProcessRunner\" singleton=\"false\">
  <description>import #{object}</description>
  <property name=\"name\" value=\"#{object}\"/>
  <property name=\"configOverrideMap\">
    <map>
      <entry key=\"sfdc.endpoint\" value=\"https://login.salesforce.com\"/>
      <entry key=\"sfdc.username\" value=\"#{username}\"/>
      <entry key=\"sfdc.password\" value=\"#{password}\"/>
      <entry key=\"sfdc.entity\" value=\"#{object}\"/>
      <entry key=\"process.operation\" value=\"insert\"/>
      <entry key=\"process.mappingFile\" value=\"data/import/sdl/#{object}.sdl\"/>
      <entry key=\"dataAccess.name\" value=\"data/import/#{object}-converted.csv\"/>
      <entry key=\"process.outputError\" value=\"data/import/#{object}-converted-error.csv\"/>
      <entry key=\"process.outputSuccess\" value=\"data/import/#{object}-converted-success.csv\"/>
      <entry key=\"process.encryptionKeyFile\" value=\"/opt/app/configs/encryption.key\"/>
      <entry key=\"dataAccess.type\" value=\"csvRead\" />
    </map>
  </property>
</bean>
_BEAN_


    xml_file = <<"_XML_"
<!DOCTYPE beans PUBLIC \"-//SPRING//DTD BEAN//EN\" \"http://www.springframework.org/dtd/spring-beans.dtd\">
<beans>#{bean}</beans>
_XML_

    FileUtils.mkdir_p 'configs/import'
    File.open("configs/import/process-conf.xml", "w") { |f| f.write xml_file }
    # system("docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/ --entrypoint dataloader yusukeoshiro/salesforce-dataloader process import #{object}")
    puts "    importing #{object}..."
    system("dataloader process import #{object}")
    # `docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/ --entrypoint dataloader yusukeoshiro/salesforce-dataloader process import #{object}`
    puts "    ...done"
    puts ""
    puts ""

    errors = CSV.read("data/import/#{object}-converted-error.csv")
    raise "#{object} failed! check error file" if errors.size > 1

    # add to id mapping
    success = CSV.read("data/import/#{object}-converted-success.csv")
    success[1..-1].each do |row|
      id_map[object] = {} if !id_map[object]
      id_map[object][row[1]] = row[0]
    end

    # output id_map
    File.open("data/id_map.json", "w") { |f| f.write JSON.dump id_map }
  end

  puts "import complete!!!"
end