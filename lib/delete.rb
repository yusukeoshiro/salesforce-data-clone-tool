require './lib/export'
require 'csv'
require 'fileutils'


def delete (username, password, interactive)
  FileUtils.mkdir_p 'data/delete/sdl'

  export(username, password, false, 'data/delete')
  file = File.open("data/import_order.json")
  import_order = JSON.parse(file.read)
  delete_order = import_order.reverse

  File.open("data/delete/sdl/delete.sdl", "w") { |f| f.write 'Id=Id' }




  delete_order.each do |object|
    bean =
    "<bean id=\"#{object}\" class=\"com.salesforce.dataloader.process.ProcessRunner\" singleton=\"false\">" +
    "<description>delete #{object}</description>" +
    "<property name=\"name\" value=\"#{object}\"/>" +
    "<property name=\"configOverrideMap\">" +
    "  <map>" +
    "    <entry key=\"sfdc.endpoint\" value=\"https://login.salesforce.com\"/>" +
    "    <entry key=\"sfdc.username\" value=\"#{username}\"/>" +
    "    <entry key=\"sfdc.password\" value=\"#{password}\"/>" +
    "    <entry key=\"sfdc.entity\" value=\"#{object}\"/>" +
    "    <entry key=\"process.operation\" value=\"delete\"/>" +
    "    <entry key=\"process.mappingFile\" value=\"data/delete/sdl/delete.sdl\"/>" +
    "    <entry key=\"dataAccess.name\" value=\"data/delete/#{object}.csv\"/>" +
    "    <entry key=\"process.outputError\" value=\"data/delete/#{object}-error.csv\"/>" +
    "    <entry key=\"process.outputSuccess\" value=\"data/delete/#{object}-success.csv\"/>" +
    "    <entry key=\"process.encryptionKeyFile\" value=\"/opt/app/configs/encryption.key\"/>" +
    "    <entry key=\"dataAccess.type\" value=\"csvRead\" />" +
    "  </map>" +
    "</property>" +
    "</bean>"

    xml_file =
    "<!DOCTYPE beans PUBLIC \"-//SPRING//DTD BEAN//EN\" \"http://www.springframework.org/dtd/spring-beans.dtd\">" +
    "<beans>" +
    bean +
    "</beans>"

    FileUtils.mkdir_p 'configs/delete'
    File.open("configs/delete/process-conf.xml", "w") { |f| f.write xml_file }

    puts "    deleting #{object}..."
    system("dataloader process delete #{object}")

    puts "    ...done"
    puts ""
    puts ""


    errors = CSV.read("data/delete/#{object}-error.csv")
    raise "#{object} failed! check error file" if errors.size > 1
  end

  puts "delete complete!!!"


end
