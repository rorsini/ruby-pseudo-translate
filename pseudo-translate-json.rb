#!/usr/bin/env ruby

# pseudo-translate-json.rb
#
# A script to convert an English json i18n
# resource file to pseudo translated strings.

require 'json'
require 'optparse'
require 'ostruct'
require 'fileutils'

# Config
PSEUDO_LANG = 'hr' # used to replace 'en' (English)

BASE_PATH = File.join(Dir.pwd, "public")

INPUTDIR = "#{BASE_PATH}/languages/en"
INPUTDIR_JA = "#{BASE_PATH}/languages/ja"
INPUTDIR_ZH = "#{BASE_PATH}/languages/zh-hans"

OUTPUTDIR = "#{BASE_PATH}/languages/#{PSEUDO_LANG}"
OUTPUTDIR_JA = "#{BASE_PATH}/languages/ja-x-pt"
OUTPUTDIR_ZH = "#{BASE_PATH}/languages/zh-hans-x-pt"

module QuickPT

  class MyHash < Hash

    def pseudoize_string(value = self)
      case value
      when Hash
        Hash[value.map { |k, v| [k, pseudoize_string(v)] }]
      when Array
        value.map {|v| process_value(v)}
      else
        process_value(value)
      end
    end

    private

    CHARS = {'a'=>'ä', 'c'=>'ç', 'i'=>'ï', 'C'=>'Ç', 'A'=>'Ä', 'e'=>'é',
             'E'=>'É', 'D'=>'Ð', 'o'=>'ö', 'O'=>'Ö', 'u'=>'ü', 'U'=>'Ü',
             'n'=>'ñ', 'r'=>'ř', 'Y'=>'Ý', 'w'=>'ω', 'N'=>'Ñ'}

    def process_value(value)
      if value =~ /%{.*}/
        words = value.split(" ")
        words.each do |w|
          unless w =~ /%{.*}/
            replace_chars(w)
          end
        end
        value = words.join(" ")
      elsif value =~ /{{.*}}/
        # handle special case by adding special placeholders
        value = value.gsub('&quot;', '^^^^^')
        value = value.gsub(/}}([\S])/, '}} _____\1').gsub(/([\S]){{/, '\1 _____{{')
        # take the space out: {{- html_var}} --> {{-html_var}}
        value = value.gsub(/{{-(\s+)/, '{{-')
        words = value.split(" ")
        words.each do |w|
          unless w =~ /{{.*}}/
            replace_chars(w)
          end
        end
        value = words.join(" ")
        # remove special placeholders
        value = value.gsub('^^^^^', '&quot;')
        value = value.gsub(/ _____/, '').gsub(/_____ /, '')
        # put the space back in: {{-html_var}} --> {{- html_var}}
        value = value.gsub(/{{-/, '{{- ')
      else
        value = value.gsub('&quot;', '^^^^^')
        replace_chars(value)
        value = value.gsub('^^^^^', '&quot;')
      end

      if value =~ /«.*»/
        return value
      else
        if value.length == 0
          return value
        end
        return "«#{value}»"
      end
    end

    def replace_chars(value)
      CHARS.map do |k,v|
        if value.respond_to?('gsub!')
          value.gsub!(k, v)
        end
      end
      return value
    end
  end
end

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end
  def red
    colorize(31)
  end
  def green
    colorize(32)
  end
end

def get_translation(lang)
  json = {}
  Dir.glob("#{BASE_PATH}/languages/#{lang}/*.json") do |f|
    key = File.basename(f, '.json')
    json[key] = JSON.parse(File.read(f, :encoding => "UTF-8"))
  end
  json
end

def nuke_existing_dir(dir_name)
  # Handle a directory of files:
  begin
    ##Disabled code that prompts for confirmation:
    # puts "Are you sure you want to delete #{dir_name.red}? (y/n)"
    # input = gets.chomp
    # command, *params = input.split(/\s/)
    command, *params = 'y'
    case command
    when /\Ay\z/i
      FileUtils.rm_rf(dir_name)
    when /\An\z/i
      puts "Please deal with #{dir_name.red}, and try again. Exiting..."
      exit
    else
      puts 'Invalid command'
    end
    FileUtils.mkdir(dir_name)
  rescue Errno::EEXIST
    puts "ERROR: Can't create the #{dir_name} directory, it already exists!"
    exit
  end
end

def generate_pt(options, input_dir, output_dir, merge_dir=nil)
  files = Dir.entries(input_dir).select {|f| f.end_with?(".json") }
  files.each do |file|
    if md = file.match(/(?'name'.*).json/)
      new_file = md['name'] + '.json'
      puts(file)
      file_contents = File.read "#{input_dir}/#{file}"
      data = QuickPT::MyHash.new
      # this step essentially converts a Hash to a QuickPT::MyHash
      data = data.merge(JSON.parse(file_contents))
      data_pt = data.pseudoize_string
      if merge_dir
        if File.file?("#{merge_dir}/#{file}")
          puts "\t Translated JSON file exists! Merging translations with PT...".red
          file_ja = File.read "#{merge_dir}/#{file}"
          data_ja = JSON.parse(file_ja)
          data_pt.merge!(data_ja)
          if options.verbose
            puts data_pt
          end
        end
      end
      output = JSON.pretty_generate(data_pt, :indent => ' '*4)
      File.open("#{output_dir}/#{new_file}", 'w') { |file| file.write(output.to_s + "\n")}
    end
  end
  puts "\nCompleted on #{Time.now.strftime("%m/%d/%Y at %H:%M%P")}."
end

if $0 == __FILE__

  include QuickPT

  options = OpenStruct.new
  options.string_input = nil
  options.verbose = false
  options.vim_mode = false
  options.verify_keys = false
  options.backfill_japanese = false
  options.backfill_chinese = false

  parser = OptionParser.new do |opts|

    opts.banner = "Usage: pseudo_translate_json.rb [options]"
    opts.on('-s', '--string-input "Your String"',
            'A custom string to pseudo-translate.') do |string|
      options.string_input = string
    end

    opts.on('-v', '--vim-mode "Your String"',
            'For pseudo-translating in vim.') do |string|
      options.vim_mode = string
    end

    opts.on('-t', '--verify-keys',
            'Verify keys are consistant for all langs, unique, used at least once, etc.') do |string|
      options.verify_keys = string
    end

    opts.on('-j', '--backfill-japanese',
            'Backfill Japanese with PT into folder: "ja-x-pt"') do |string|
      options.backfill_japanese = true
    end

    opts.on('-c', '--backfill-chinese',
            'Backfill Chinese with PT into folder: "zh-hans-x-pt"') do |string|
      options.backfill_chinese = true
    end

    opts.on('-v', '--verbose', 'Adds some extra output in case you need it.') do
      options.verbose = true
    end

    opts.on('-h', '--help', 'Displays Help.') do
      puts opts
      exit
    end
  end

  parser.parse!

  if options.string_input

    # Handle text passed via the command line:
    data = QuickPT::MyHash.new
    string_input = options[:string_input]
    data[:string_input] = options[:string_input]
    puts
    puts " input: #{string_input}"
    puts "output: #{data.pseudoize_string[:string_input]}"
    puts

  elsif options.vim_mode

    data = QuickPT::MyHash.new
    string_input = options[:vim_mode]
    data[:vim_mode] = options[:vim_mode]
    print "#{data.pseudoize_string[:vim_mode]}"

  elsif options.verify_keys

    puts "Verify JSON keys..."
    puts get_translation('hr')

  elsif options.backfill_japanese

    nuke_existing_dir(OUTPUTDIR_JA)
    generate_pt(options, INPUTDIR, OUTPUTDIR_JA, INPUTDIR_JA)

  elsif options.backfill_chinese

    nuke_existing_dir(OUTPUTDIR_ZH)
    generate_pt(options, INPUTDIR, OUTPUTDIR_ZH, INPUTDIR_ZH)

  else

    Dir.glob("#{OUTPUTDIR}/*.json_nx") do |file|
      # if '*.json_nx' file(s) exists, move to avoid deleting
      FileUtils.mv(
        file,
        File.join(File.dirname(OUTPUTDIR), File.basename(file))
      )
    end
    nuke_existing_dir(OUTPUTDIR)
    # default is to run PT on "en" dir
    generate_pt(options, INPUTDIR, OUTPUTDIR)
    Dir.glob("#{File.dirname(OUTPUTDIR)}/*.json_nx") do |file|
      # put '*.json_nx' file(s) back in PT dir if they exists
      FileUtils.mv(
        file,
        File.join(OUTPUTDIR, File.basename(file))
      )
    end

  end
end
