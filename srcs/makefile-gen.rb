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
    options.restrictive = false
    options.outputType = "executable";
    options.outputName = "program"
    
    options.libPath = ""
    
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: makefile-gen [options]"

      opts.separator ""
      opts.separator "Options:"

      # output name
      opts.on("-o NAME", "--output Name", "Choose output name. Default = program") do |name|
        options.outputName = name
      end

      
      # custom compilation flags
      opts.on("-f", "--flags {FLAG1,FLAG2}", "Custom flags to add to compilation") do |lib|
        options.flags.concat lib.split(',')
      end

      # lib path
      opts.on("-l PATH", "--library PATH", "Choose library path. Default = autofind") do |path|
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
    @libPath = ""
    extension = ""

    # Find source files and define compilator
    Find.find('.') do |path|
      # Get sources paths
      if ((path.end_with? ".c") || (path.end_with? ".cpp"))
        if ((path.end_with? ".c") && extension == "")
          extension = ".c"
          @compilator = "gcc"
        else
          if (extension == "")
            extension = ".cpp"
            @compilator = "g++"
          end
        end
        @pathes << path unless FileTest.directory?(path)
      end

      # Get lib paths
      if (((path.end_with? ".h") || (path.end_with? ".hpp")) && @libPath == "")
        @libPath = path.gsub(/\w*\.h/, "")
      end
    end # find
  end  # parse()

  def self.getCompilator()
    return @compilator
  end

  def self.getPaths()
    return @pathes
  end

  def self.getLibPath()
    return @libPath
  end
  
end  # class ParseFolder

def write_makefile(options, parsed_folder)
  if (parsed_folder.getCompilator == "g++")
    compile_flag_name = "CPPFLAGS"
  else
    compile_flag_name = "CFLAGS"
  end
  text = ""
  text << "NAME\t= #{options.outputName}\n\n"
  text << "CC\t= #{parsed_folder.getCompilator}\n\n"
  text << "RM\t= rm -f\n\n"
  text << "SRCS\t= "
  parsed_folder.getPaths().each do |path|
    text << path + " \\\n\t  "
  end
  text << "\n\n"
  text = text.gsub("\\\n\t  \n", "\n")
  if (parsed_folder.getCompilator == "g++")
    text << "OBJS\t= $(SRCS:.cpp=.o)\n\n"
  else
    text << "OBJS\t= $(SRCS:.c=.o)\n\n"
  end
  libPath = options.libPath
  if (libPath == "")
    text << "#{compile_flag_name} = -I#{parsed_folder.getLibPath}\n"
  else
    text << "#{compile_flag_name} = -I#{libPath}\n"
  end
  options.flags.each do |flag|
    text << "#{compile_flag_name} += -#{flag}\n" 
  end
  text << "#{compile_flag_name} += -W -Wall -Wextra\n"
  if (options.restrictive)
    text << "#{compile_flag_name} += -Werror\n"
  end
  if (options.outputType == "lib")
    text << "#{compile_flag_name} += -fpic -shared"
  end
  text << "\nall: $(NAME)\n\n"
  text << "$(NAME): $(OBJS)\n"
  text << "\t $(CC) $(OBJS) -o $(NAME)\n\n"
  text << "clean:\n"
  text << "\t$(RM) $(OBJS)\n\n"
  text << "fclean: clean\n"
  text << "\t$(RM) $(NAME)\n\n"
  text << "re: fclean all\n\n"
  text << ".PHONY: all clean fclean re\n"
  File.open("Makefile", 'w') { |file| file.write(text) }
end

options = ParseArgs.parse(ARGV)
parsed_folder = ParseFolder
parsed_folder.parse
write_makefile(options, parsed_folder)
