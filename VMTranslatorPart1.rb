$i = 0
$current_name = ''

# processes directory
class Directory
  def initialize(dir)
    @dir = dir
    @dir_filter = []
  end

  # returns array of pairs of vm code and filenames for static variables
  def filter
    @dir.each do |file|
      name = File.basename(file).split('.')[0]
      ext = File.basename(file).split('.')[1]
      @dir_filter.push([File.read(file), name]) if ext === 'vm'
    end
  end

  # translates directory of vm files into single .asm file
  def translate_dir
    out =
      "@256
       D=A
       @SP
       M=D\n".delete(' ')
    @dir_filter.each do |file|
      r = Reader.new(file[0], file[1])
      r.filter
      out += r.translate_file
    end
    out
  end
end

# processes individual vm file
class Reader
  def initialize(file, name)
    @file = file.split("\n")
    @current_name = name
    $current_name = name
  end

  # filters comments and whitespace from input
  def filter
    read = []
    @file.each do |line|
      line = line.strip
      read.append(line) if !line[0].nil? && (line[0] != '/') # if line is not comment or blank, append to read
    end
    read
  end

  # translates file to asm code
  def translate_file
    read = filter
    out = ''
    read.each do |line|
      p = Parser.new(line)
      out += p.command_type
    end
    out
  end
end

class Parser
  def initialize(line)
    # divide current line into array for parsing
    @current = line.split(' ')
  end

  attr_reader :current

  # determines command type of current command and passes to code to be translated
  def command_type
    case @current[0]
    when 'pop', 'push'
      c = Code.new([@current[0].to_sym, @current[1].to_sym, @current[2]])
      c.translate_m.to_s
    when 'label'
      :c_label
    when 'goto'
      :c_goto
    when 'if'
      :c_if
    when 'function'
      :c_function
    when 'return'
      :c_return
    when 'call'
      :c_return
    else
      c = Code.new([@current[0].to_sym])
      c.translate_a.to_s
    end
  end
end

class Code
  def initialize(syms)
    @syms = syms
    # assembly code for two operand stack arithmetic
    @a2 =
      "@SP//two_operand_stack_arithmetic
      M=M-1
      @SP
      A=M
      D=M
      @R13
      M=D
      @SP
      M=M-1
      @SP
      A=M
      D=M
      @R13
      #{AC[@syms[0]]}
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')
    # assembly code for one operand stack arithmetic
    @a1 =
      "@SP//one_operand_stack_arithmetic
      M=M-1
      @SP
      A=M
      D=M
      #{AC[@syms[0]]}
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')
    # assembly code for comparison stack arithmetic
    @ac =
      "@SP//Comparison
       M=M-1
       @SP
       A=M
       D=M
       @R13
       M=D
       @SP
       M=M-1
       @SP
       A=M
       D=M
       @R13
       D=D-M
       @TRUE#{$i}
       D;#{AC[@syms[0]]}
       @SP
       A=M
       M=0
       @RET#{$i}
       0;JMP
       (TRUE#{$i})
       @SP
       A=M
       M=-1
       (RET#{$i})
       @SP
       M=M+1\n".delete(' ')

    # asm code for pop commands in virtual memory segments
    @pop =
      "@#{@syms[2]}//popcommand
      D=A
      #{MC[@syms[1]]}
      D=D+M
      @R13
      M=D
      @SP
      M=M-1
      @SP
      A=M
      D=M
      @R13
      A=M
      M=D\n".delete(' ')

    # asm code for push commands in virtual memory segments
    @push =
      "@#{@syms[2]}//pushcommand
      D=A
      #{MC[@syms[1]]}
      D=D+M
      A=D
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for push constant commands
    @push_constant =
      "@#{@syms[2]}//pushconstant
      D=A
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for push temp commands
    @push_temp =
      "@#{@syms[2].to_i + 5}//pushtemp
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for pop temp commands
    @pop_temp =
      "@SP//poptemp
      M=M-1
      @SP
      A=M
      D=M
      @#{@syms[2].to_i + 5}
      M=D\n".delete(' ')

    # asm code for pushing this and that base addresses to the stack
    @push_pointer =
      "#{MC[@syms[2].to_s.to_sym]}//push_pointer
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for assinging base address of this or that in the heap
    @pop_pointer =
      "@SP//poppointer
      M=M-1
      @SP
      A=M
      D=M
      #{MC[@syms[2].to_s.to_sym]}
      M=D\n".delete(' ')

    # asm code for pushing variables to stack
    @push_static =
      "@#{$current_name}.#{@syms[2]}//pushstatic
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for popping stack to variable
    @pop_static =
      "@SP//pop static
      M=M-1
      @SP
      A=M
      D=M
      @#{$current_name}.#{@syms[2]}
      M=D\n".delete(' ')
  end

  # Arithmatic Commands Hash
  AC = { add: 'D=D+M',
         sub: 'D=D-M',
         neg: 'D=-D',
         eq: 'D;JEQ',
         gt: 'D:JGT',
         lt: 'D:JLT',
         "and": 'D=D&M',
         "or": 'D=D|M',
         "not": 'D=!D' }

  # Memory access commands
  MC = { argument: '@ARG',
         local: '@LCL',
         this: '@THIS',
         that: '@THAT',
         "temp": '@R5',
         "0": '@THIS',
         "1": '@THAT' }

  # translate pop commands
  def translate_pop
    case @syms[1]
    when :local, :argument, :this, :that
      @pop
    when :temp
      @pop_temp
    when :pointer
      @pop_pointer
    when :static
      @pop_static
    else
      'invalid pop command'
    end
  end

  # translate push commands
  def translate_push
    case @syms[1]
    when :local, :argument, :this, :that
      @push
    when :constant
      @push_constant
    when :temp
      @push_temp
    when :pointer
      @push_pointer
    when :static
      @push_static
    else
      'invalid push command'
    end
  end

  # translate memory vm commands into hack assembly
  def translate_m
    case @syms[0]
    when :pop
      translate_pop
    when :push
      translate_push
    end
  end

  # translate arithmetic vm commands into hack assembly
  def translate_a
    case @syms[0]
    when :add, :sub, :and, :or
      @a2
    when :neg, :not
      @a1
    when :eq, :gt, :lt
      $i += 1
      @ac
    else
      'invalid arithmetic command'
    end
  end
end

Dir.chdir(ARGV[0])
dir = Dir.open(ARGV[0])

out = File.new("#{ARGV[1]}.asm", 'w')

d = Directory.new(dir)
d.filter

out.syswrite(d.translate_dir)
