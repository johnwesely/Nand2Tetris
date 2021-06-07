# frozen_string_literal: true

# methods for parsing one line of assembly code into symbols
class Parser
  def initialize(line)
    @current = line
  end

  # returns command type symbol
  def command_type
    case @current[0]
    when '@'
      :A_COMMAND
    when '('
      :L_COMMAND
    else
      :C_COMMAND
    end
  end

  # returns symbol for destination mnemonic
  def dest
    if @current.include?(';')
      :null
    else
      @current.split('=')[0].to_sym
    end
  end

  # returns Ruby symbol for comp mnemonic
  def comp
    if @current.include?(';')
      @current.split(';')[0].to_sym
    else
      @current.split('=')[1].to_sym
    end
  end

  # returns Ruby symbol for jump mnemonic
  def jump
    if @current.include?(';')
      @current.split(';')[1].to_sym
    else
      :null
    end
  end

  # handles process for translating assembly code
  def process
    if command_type == :C_COMMAND
      @c = Code.new([comp, dest, jump])
      "#{@c.translate_c}\n"
    else
      @c = Code.new(@current[1..-1])
      "#{@c.translate_a}\n"
    end
  end
end

# reads and filters input line by line
class Reader
  def initialize(file)
    @file = file.read.split("\n")
  end

  # filters comments and deritus from input file
  def filter
    read = []
    @file.each do |line|
      line = line.strip
      if !line[0].nil? && (line[0] != '/') # if line is not comment or blank append to output
        line = line.split(' ')[0] # removes inline comments
        read.append(line)
      end
    end
    read
  end
end

# methods for translating parsed assembly into Hack 16 bit instructions
class Code
  def initialize(syms)
    @syms = syms # symbols for A and C instructions
  end

  # hash tables for translation
  DT = { null: '000', M: '001', D: '010', MD: '011', A: '100', AM: '101',
         AD: '110', AMD: '111' }.freeze

  JT = { null: '000', JGT: '001', JEQ: '010', JGE: '011', JLT: '100',
         JNE: '101', JLE: '110', JMP: '111' }.freeze

  CT = { "0": '0101010', "1": '0111111', "-1": '0111010', D: '0001100',
         A: '0110000',
         "!D": '0001101', "!A": '0110001', "-D": '0001111', "-A": '0110011',
         "D+1": '0011111', "A+1": '0110111', "D-1": '0001110', "A-1": '0110010',
         "D+A": '0000010', "D-A": '0010011', "A-D": '0010011', "D&A": '0000000',
         "D|A": '0010101', "D|M": '1010101', "D&M": '1000000', "M-D": '1000111',
         "D-M": '1010011', "D+M": '1000010', "M-1": '1110010', "M+1": '1110111',
         "-M": '1110011', "!M": '1110001', M: '1110000' }.freeze

  attr_reader :ct

  # translate a instructions
  def translate_a
    a_string = @syms.to_i.to_s(2)
    a_string = "0#{a_string}" while a_string.length < 16 # adds MSB to binary string until value is 16-bit
    a_string
  end

  # translate c instructions
  def translate_c
    "111#{CT[@syms[0]]}#{DT[@syms[1]]}#{JT[@syms[2]]}"
  end
end

# top level class for translating assembly to hack machine code
class Processor
  def initialize(file)
    @file = file
    @filtered = Reader.new(file).filter # trimmed and filtered input
  end

  # top level symbol free translator
  def process
    out = ''
    @filtered.each do |line|
      p = Parser.new(line)
      out += p.process
    end
    out
  end

  # resolves all symbols to decimal values
  def resolve_symbols
    s = Symbols.new(@filtered)
    pro = s.process_labels
    @filtered = s.translate_symbols(pro)
    process
  end
end

# methods for processing out symbols in assemly code
class Symbols
  def initialize(file)
    @file = file
    @sym_address = 16 # decimal address counter for variable assingment
    # hash table for symbols
    @st = {
      SP: 0, LCL: 1, ARG: 2, THIS: 3, THAT: 4, R0: 0, R1: 1,
      R2: 2, R3: 3,  R4: 4, R5: 5, R6: 6, R7: 7, R8: 8,
      R9: 9, R10: 10, R11: 11, R12: 12, R13: 13, R14: 14, R15: 15,
      SCREEN: 16_384, KBD: 24_576
    }
  end

  attr_reader :st

  # first pass of file to assign psudeocommands to rom addresses
  def process_labels
    line_add = 0
    out = []
    @file.each do |line| # if line is psudeocommand, add label to hashtable
      if line[0] == '('
        @st[line[1..-2].to_sym] = line_add
      else
        out.push(line) # only retain true commands
        line_add += 1
      end
    end
    out # file with all psuedocommands removed
  end

  # symbol lookup and symbol table management.
  def sym_lookup(line)
    out = ''
    if @st.key?(line[1..-1].to_sym) # if varible is already in table, replace with value
      out = "@#{@st[line[1..-1].to_sym]}"
    else
      @st[line[1..-1].to_sym] = @sym_address # add variable to table with current free address
      out = "@#{@sym_address}" # replace with value
      @sym_address += 1 # increment address
    end
    out
  end

  # translates symbols to decimal in assembly file
  def translate_symbols(file)
    out = []
    file.each do |line|
      if (line[0] == '@') && line[1] !~ /\d/ # if A instruction contains a variable
        out.push sym_lookup(line) # evaluate to decimal value
      else
        out.push line                            # keep decimal value as is
      end
    end
    out                                          # file with all var translated to decimal
  end
end

file = File.open(ARGV[0])
file_name = ARGV[0].split('.')[0]

out = File.new("#{file_name}.hack", 'w')

p = Processor.new(file)

out.syswrite(p.resolve_symbols)
