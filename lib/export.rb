require 'json'
require 'fileutils'

def export (username, password, interactive, path='data/export')
  file = File.open("data/object_fields.json")
  object_fields = JSON.parse(file.read)

  file = File.open("data/import_order.json")
  import_order = JSON.parse(file.read)

  # check if this can be skipped
  files_missing = []
  files_existing = []
  export_mode = '' # "FULL" or "PARTIAL"
  import_order.each do |object|
    export_path = "#{path}/#{object}.csv"
    if File.exists?(export_path)
      files_existing << object
    else
      files_missing << object
    end
  end

  if interactive && files_existing.any? && files_missing.empty?
    puts "looks like all objects are already exported: "
    puts "Do you still want to export all the objects? [y]n"
    continue = STDIN.gets.chomp
    return if continue == 'n'

    export_mode = "FULL"
  end

  if interactive && files_existing.empty? && files_missing.any?
    export_mode = "FULL"
  end

  if interactive && files_existing.any? && files_missing.any?
    puts "looks like some of the objects are already exported: "
    puts "Do you still want to export all the objects? (if you select no, we only export missing objects) [y]n"
    continue = STDIN.gets.chomp
    if continue == 'n'
      export_mode = "PARTIAL"
    else
      export_mode = "FULL"
    end
  end

  # generate xml file
  beans = []
  import_order.each do |object|
    next if (export_mode == 'PARTIAL' && files_existing.include?(object))


    fields = object_fields[object]['fields'].map{|f| f['name']}.join(', ')
    soql_statement = "SELECT #{fields} FROM #{object}"

    bean =
    "<bean id=\"#{object}\" class=\"com.salesforce.dataloader.process.ProcessRunner\" singleton=\"false\">" +
    "<description>export #{object}</description>" +
    "<property name=\"name\" value=\"#{object}\"/>" +
    "<property name=\"configOverrideMap\">" +
    "  <map>" +
    "    <entry key=\"sfdc.endpoint\" value=\"https://login.salesforce.com\"/>" +
    "    <entry key=\"sfdc.username\" value=\"#{username}\"/>" +
    "    <entry key=\"sfdc.password\" value=\"#{password}\"/>" +
    "    <entry key=\"sfdc.entity\" value=\"#{object}\"/>" +
    "    <entry key=\"process.operation\" value=\"extract\"/>" +
    "    <entry key=\"sfdc.extractionSOQL\" value=\"#{soql_statement}\"/>" +
    "    <entry key=\"dataAccess.name\" value=\"#{path}/#{object}.csv\"/>" +
    "    <entry key=\"process.outputError\" value=\"#{path}/#{object}-error.csv\"/>" +
    "    <entry key=\"process.outputSuccess\" value=\"#{path}/#{object}-success.csv\"/>" +
    "    <entry key=\"process.encryptionKeyFile\" value=\"/opt/app/configs/encryption.key\"/>" +
    "    <entry key=\"dataAccess.type\" value=\"csvWrite\" />" +
    "  </map>" +
    "</property>" +
    "</bean>"
    beans.append bean
  end

  xml_file =
  "<!DOCTYPE beans PUBLIC \"-//SPRING//DTD BEAN//EN\" \"http://www.springframework.org/dtd/spring-beans.dtd\">" +
  "<beans>" +
  beans.join('') +
  "</beans>"


  FileUtils.mkdir_p 'configs/export'
  File.open("configs/export/process-conf.xml", "w") { |f| f.write xml_file }

  # READY! EXPORT ALL THE OBJECTS!!!
  puts "Export ready..."
  puts ""
  import_order.each do |object|
    next if (export_mode == 'PARTIAL' && files_existing.include?(object))

    puts "  exporting #{object}"
    system("dataloader process export #{object}")
    # `docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/  --entrypoint dataloader yusukeoshiro/salesforce-dataloader process export #{object}`
    # system("docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/  --entrypoint dataloader yusukeoshiro/salesforce-dataloader process export #{object}")
  end
end
