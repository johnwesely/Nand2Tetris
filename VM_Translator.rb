# frozen_string_literal: true

# Global for comparison arithmetic return address
$i = 0
# Global for function return address
$n = -1
# Global for current class name
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
    p = Parser.new('call Sys.init 0')
    out =
      "@256
       D=A
       @SP
       M=D
       #{p.command_type}
       ".delete(' ')
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

# Parses each line into symbols for translation
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
    when 'label', 'if-goto', 'goto'
      c = Code.new([@current[0].to_sym, @current[1]])
      c.translate_flow.to_s
    when 'function'
      c = Code.new([@current[0].to_sym, @current[1].to_sym, @current[2]])
      c.translate_function.to_s
    when 'return'
      c = Code.new([@current[0].to_sym])
      c.translate_return.to_s
    when 'call'
      c = Code.new([@current[0].to_sym, @current[1].to_sym, @current[2]])
      c.translate_call.to_s
    else
      c = Code.new([@current[0].to_sym])
      c.translate_a.to_s
    end
  end
end

# Translate symbols from one line of VM code into assembly
class Code
  def initialize(syms)
    @syms = syms

    # assembly code for two operand stack arithmetic
    @a2 =
      "//two_operand_stack_arithmetic
      @SP
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
      "//one_operand_stack_arithmetic
      @SP
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
      "//comparison
     @SP
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
     #{AC[@syms[0]]}
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
      "//pop
      @#{@syms[2]}
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
      "//push
      @#{@syms[2]}
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
      "//push_constant
      @#{@syms[2]}
      D=A
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for push temp commands
    @push_temp =
      "//push_temp
      @#{@syms[2].to_i + 5}
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for pop temp commands
    @pop_temp =
      "//pop_temp
      @SP
      M=M-1
      @SP
      A=M
      D=M
      @#{@syms[2].to_i + 5}
      M=D\n".delete(' ')

    # asm code for pushing this and that base addresses to the stack
    @push_pointer =
      "//push_pointer
      #{MC[@syms[2].to_s.to_sym]}
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for assinging base address of this or that in the heap
    @pop_pointer =
      "//pop_pointer
      @SP
      M=M-1
      @SP
      A=M
      D=M
      #{MC[@syms[2].to_s.to_sym]}
      M=D\n".delete(' ')

    # asm code for pushing variables to stack
    @push_static =
      "//push_static
      @#{$current_name}.#{@syms[2]}
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1\n".delete(' ')

    # asm code for popping stack to variable
    @pop_static =
      "//pop_static
      @SP
      M=M-1
      @SP
      A=M
      D=M
      @#{$current_name}.#{@syms[2]}
      M=D\n".delete(' ')

    # asm code for translating lable commands
    @label =
      "//label
      (#{@syms[1]})\n".delete(' ')

    # asm code for translating Goto commands
    @goto =
      "//Goto
      @#{@syms[1]}
      0;JMP\n".delete(' ')

    @if =
      "//if-goto
      @SP
      M=M-1
      @SP
      A=M
      D=M
      @#{@syms[1]}
      D;JNE\n".delete(' ')
  end

  # Arithmatic Commands Hash
  AC = { add: 'D=D+M',
         sub: 'D=D-M',
         neg: 'D=-D',
         eq: 'D;JEQ',
         gt: 'D;JGT',
         lt: 'D;JLT',
         "and": 'D=D&M',
         "or": 'D=D|M',
         "not": 'D=!D' }.freeze

  # Memory access commands
  MC = { argument: '@ARG',
         local: '@LCL',
         this: '@THIS',
         that: '@THAT',
         "temp": '@R5',
         "0": '@THIS',
         "1": '@THAT' }.freeze

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

  # translate flow vm commands into hack assembly
  def translate_flow
    case @syms[0]
    when :label
      @label
    when :goto
      @goto
    when :"if-goto"
      @if
    end
  end

  # translate function call command into hack assembly
  def translate_call
    $n += 1
    "//function call
    @#{@syms[1]}.return.#{$n}
    D=A
    @SP
    A=M
    M=D
    @SP
    M=M+1

    @LCL
    D=M
    @SP
    A=M
    M=D
    @SP
    M=M+1

    @ARG
    D=M
    @SP
    A=M
    M=D
    @SP
    M=M+1

    @THIS
    D=M
    @SP
    A=M
    M=D
    @SP
    M=M+1

    @THAT
    D=M
    @SP
    A=M
    M=D
    @SP
    M=M+1

    @#{@syms[2]}
    D=A
    @5
    D=D+A
    @SP
    D=M-D
    @ARG
    M=D

    @SP
    D=M
    @LCL
    M=D

    @#{@syms[1]}
    0;JMP

    (#{@syms[1]}.return.#{$n})
    ".delete(' ')
  end

  # translate function command into hack assembly
  def translate_function
    i = @syms[2].to_i
    out = "//function\n(#{@syms[1]})\n"
    # push constant zero to stack i times
    while i.positive?
      t = Code.new([:push, :constant, 0])
      out += t.translate_push
      i -= 1
    end
    out
  end

  # translate return function into hack assembly
  def translate_return
    "//return
    @LCL
    D=M
    @FRAME
    M=D

    @5
    D=A
    @FRAME
    A=M-D
    D=M
    @RET
    M=D

    @SP
    M=M-1
    @SP
    A=M
    D=M
    @ARG
    A=M
    M=D

    @ARG
    D=M+1
    @SP
    M=D

    @1
    D=A
    @FRAME
    A=M-D
    D=M
    @THAT
    M=D

    @2
    D=A
    @FRAME
    A=M-D
    D=M
    @THIS
    M=D

    @3
    D=A
    @FRAME
    A=M-D
    D=M
    @ARG
    M=D

    @4
    D=A
    @FRAME
    A=M-D
    D=M
    @LCL
    M=D

    @RET
    A=M
    0;JMP
    ".delete(' ')
  end
end

Dir.chdir(ARGV[0])
dir = Dir.open(ARGV[0])

out = File.new("#{ARGV[1]}.asm", 'w')

d = Directory.new(dir)
d.filter

out.syswrite(d.translate_dir)
