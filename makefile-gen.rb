#! /usr/bin/env ruby
require 'optparse'
require 'ostruct'
require 'find'
require 'pp'

class ParseArgs
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.flags = []
    options.restrictive = true
    options.outputType = "executable";
    options.outputName = "a.out"
    
    options.libPath = "./lib"
    
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: makefile-gen.rb [options]"

      opts.separator ""
      opts.separator "Options:"

      # output name
      opts.on("-o NAME", "--output Name", "Choose output name. Default = a.out") do |name|
        options.outputName = name
      end

      
      # custom compilation flags
      opts.on("-f", "--flags {FLAG1,FLAG2}", "Custom flags to add to compilation") do |lib|
        options.flags.concat lib.split(',')
      end

      # lib path
      opts.on("-l PATH", "--library PATH", "Choose library path. Default = ./lib") do |path|
        options.libPath = path
      end

      
      # restrictive
      opts.on("-r", "--[no-]restrictive", "Add restrictive flags") do |v|
        options.restrictive = v
      end

      # Output executable type
      opts.on("-t", "--type [TYPE]", [:lib, :executable],
              "Select output type (lib, executable)") do |t|
        options.outputType = t
      end
      
      # Print usage
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end  # parse()
end  # class ParseArgs

class ParseFolder
  def self.parse

    # define defaults
    @pathes = []
    @compilator = ""
    extension = ""

    # Find source files and define compilator
    Find.find('.') do |path|
      if ((path.end_with? ".c") || (path.end_with? ".cpp"))
        if ((path.end_with? ".c") && extension == "")
          extension = ".c"
          @compilator = "gcc"
        else
          extension = ".cpp"
          @compilator = "g++"
        end
        @pathes << path unless FileTest.directory?(path)
      end
    end # find
    
    puts @pathes
    puts @compilator
  end  # parse()
end  # class ParseFolder

options = ParseArgs.parse(ARGV)
pp options
ParseFolder.parse
