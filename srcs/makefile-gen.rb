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
    @compiler = ""
    @libPath = ""
    @extension = ""

    # Find source files and define compiler
    Find.find('.') do |path|
      # Get sources paths
      if ((path.end_with? ".c") || (path.end_with? ".cpp") || (path.end_with? ".S") || (path.end_with? ".s"))
        if ((path.end_with? ".c") && @extension == "")
          @extension = ".c"
          @compiler = "gcc"
        elsif ((path.end_with? ".S") || (path.end_with? ".s"))
          if (@extension == "")
            @extension = path[-2, 2]
            @compiler = "nasm"
          end
        else
          if (@extension == "")
            @extension = ".cpp"
            @compiler = "g++"
          end
        end
        @pathes << path unless FileTest.directory?(path)
      end

      # Get lib paths
      if (@libPath == "")
        if (((path.end_with? ".h") || (path.end_with? ".hpp")) && @compiler != "nasm")
          @libPath = path.gsub(/\w*\.h/, "")
        elsif ((path.end_with? ".inc") && @compiler == "nasm")
          @libPath = path.gsub(/\w*\.inc/, "")
        end
      end
    end # find
  end  # parse()

  def self.getCompiler()
    return @compiler
  end

  def self.getExtension()
    return @extension
  end

  def self.getPaths()
    return @pathes
  end

  def self.getLibPath()
    return @libPath
  end
  
end  # class ParseFolder

### Function to write the Makefile with the parsed data
def write_makefile(options, parsed_folder)

  # BEGIN check which compiler to use
  if (parsed_folder.getCompiler == "g++")
    compile_flag_name = "CPPFLAGS"
  elsif (parsed_folder.getCompiler == "nasm")
    compile_flag_name = "ASFLAGS"
  else
    compile_flag_name = "CFLAGS"
  end
  # END check which compiler to use
  
  text = ""
  text << "NAME\t= #{options.outputName}\n\n"
  text << "CC\t= #{parsed_folder.getCompiler}\n\n"
  text << "RM\t= rm -f\n\n"
  text << "SRCS\t= "
  # Write the different sources paths after sources
  parsed_folder.getPaths().each do |path|
    text << path + " \\\n\t  "
  end
  text << "\n\n"
  text = text.gsub("\\\n\t  \n", "\n")

  # Write file extension to the prepared text
  text << "OBJS\t= $(SRCS:#{parsed_folder.getExtension}=.o)\n\n"

  ### BEGIN Compilation flags management
  # Adding the path of the lib as compilation flag
  libPath = options.libPath
  incFlag = parsed_folder.getCompiler == "nasm" ? "-i" : "-I"
  if (libPath == "")
    text << "#{compile_flag_name} = #{incFlag} #{parsed_folder.getLibPath}\n"
  else
    text << "#{compile_flag_name} = #{incFlag} #{libPath}\n"
  end

  # Adding the output format flag for asm
  if (parsed_folder.getCompiler == "nasm")
    text << "#{compile_flag_name} += -f elf64\n"
  end

  # Adding the custom flags to the compilation flags
  options.flags.each do |flag|
    text << "#{compile_flag_name} += -#{flag}\n" 
  end

  # Adding the additionnal warning compilation flags
  if (parsed_folder.getCompiler != "nasm")
    text << "#{compile_flag_name} += -Wall -Wextra\n"
  end

  # Adding the werror restrictive compilation flag, transforming warning into errors
  if (parsed_folder.getCompiler != "nasm" && options.restrictive)
    text << "#{compile_flag_name} += -Werror\n"
  end

  # Flag handling for shared library compilation
  if (options.outputType == :lib)
    if (parsed_folder.getCompiler == "nasm")
      text << "\nLDFLAGS += -shared --export-dynamic -m elf_x86_64\n"
    else
      text << "#{compile_flag_name} += -fPIC\n"
      text << "\nLDFLAGS += -shared\n"
    end
  end
  ### END Compilation flags management

  # Writing common Makefile lines to text
  text << "\nall: $(NAME)\n\n"
  text << "$(NAME): $(OBJS)\n"
  if (parsed_folder.getCompiler != "nasm")
    text << "\t $(CC) $(OBJS) -o $(NAME) $(LDFLAGS)\n\n"
  else
    if (options.outputType == :lib)
      text << "\t ld $(LDFLAGS) $(OBJS) -o $@ \n\n"
    else
      text << "\t gcc $(OBJS) -o $@\n\n"
    end
    text << "%.o: %#{parsed_folder.getExtension}\n"
    text << "\t $(CC) $(ASFLAGS) $< -o $@\n\n"
  end
  text << "clean:\n"
  text << "\t$(RM) $(OBJS)\n\n"
  text << "fclean: clean\n"
  text << "\t$(RM) $(NAME)\n\n"
  text << "re: fclean all\n\n"
  text << ".PHONY: all clean fclean re\n"
  
  # Writing the result to Makefile file
  File.open("Makefile", 'w') { |file| file.write(text) }
  
end # function write_makefile

options = ParseArgs.parse(ARGV)
parsed_folder = ParseFolder
parsed_folder.parse
write_makefile(options, parsed_folder)
