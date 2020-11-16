require 'json'

def resolve_dependencies (interactive)
  file = File.open("data/object_fields.json")
  object_fields = JSON.parse(file.read)

  file = File.open("data/dependant_external_objects.json")
  dependant_external_objects = JSON.parse(file.read)



  objects = []
  import_order = []

  object_fields.keys.each do |key|
    objects.append(object_fields[key])
  end


  while (objects.size > 0) do

    not_dependant = objects.find do |object|
      depends_on = object['depends_on'] - dependant_external_objects
      depends_on.size == 0
    end

    if not_dependant.nil?
      pp objects
      raise "oops could not resolve dependencies... there are #{objects.size} objects remaining..."
    end

    # not_dependant
    import_order << not_dependant['object']

    # remove itself from array
    objects.delete not_dependant

    # remove itself from depends_on array
    objects.each do |object|
      depends_on = object['depends_on'] - dependant_external_objects
      if depends_on.include? not_dependant['object']
        object['depends_on'].delete not_dependant['object']
      end
    end
  end

  puts ""
  puts ""
  puts "This is the dependency order (order to migrate the objects): "
  puts ""

  import_order.each_with_index{|o, i| puts "#{i+1} - #{o}"}
  puts ""

  if interactive
    puts "do you want to continue? [y]n"
    continue = STDIN.gets.chomp
    return if continue == 'n'
  end

  File.open("data/import_order.json", "w") { |f| f.write JSON.dump import_order }
  return import_order
end
