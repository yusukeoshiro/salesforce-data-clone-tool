require 'json'
require 'fileutils'

def export (username, password)
  file = File.open("data/object_fields.json")
  object_fields = JSON.parse(file.read)

  file = File.open("data/import_order.json")
  import_order = JSON.parse(file.read)

  # generate xml file
  beans = []
  import_order.each do |object|
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
    "    <entry key=\"dataAccess.name\" value=\"data/export/#{object}.csv\"/>" +
    "    <entry key=\"process.outputError\" value=\"data/export/#{object}-error.csv\"/>" +
    "    <entry key=\"process.outputSuccess\" value=\"data/export/#{object}-success.csv\"/>" +
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
    puts "  exporting #{object}"
    system("dataloader process export #{object}")
    # `docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/  --entrypoint dataloader yusukeoshiro/salesforce-dataloader process export #{object}`
    # system("docker container run --rm -it -v $(pwd)/data:/opt/app/data/ -v $(pwd)/configs:/opt/app/configs/  --entrypoint dataloader yusukeoshiro/salesforce-dataloader process export #{object}")
  end
end
