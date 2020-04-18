
require 'json'
require 'ostruct'

exit unless File.exist? 'gists.json'
gists = JSON.parse File.read('gists.json'), object_class: OpenStruct
gists.each { |h|
  folder = h.url[24..-1]
  next unless Dir.exist? folder
  puts "delete #{folder[0, 8]} #{h.description}"
  system "del /s/f/q #{folder} && rd /s/q #{folder}", out: File::NULL, err: File::NULL
}
File.delete 'gists.json'
