require './tokenizer'
require './compilation_engine'
require './Symbol_Table'
# require './Code_Writer'

# Top level class for syntax analysis of one or more .jack files
class Analyzer
  # Runs Tokenizer methods to tokenize file
  def self.tokenize(file)
    file = Tokenizer.remove_returns(file)
    file = Tokenizer.tokenize(file)
    Tokenizer.filter_blank(file)
  end

  # analyze file and return xml tree
  def self.analyze(file)
    file = Analyzer.remove_comments(file)
    file = Analyzer.tokenize(file)
    c = Compilation.new(file)
    c.comp_class
  end

  # select .jack files from directory, create new xml file for each
  # output analyzed syntax to file
  def self.filter_dir(dir)
    dir.each do |file|
      name = File.basename(file).split('.')[0]
      ext = File.basename(file).split('.')[1]
      next unless ext == 'jack'

      file = File.read(file)
      out = File.new("#{name}jj.xml", 'w')
      out.syswrite(Analyzer.analyze(file))
    end
  end

  # parses files and removes comments
  def self.remove_comments(file)
    i = 0
    chars = file.chars
    line_comment = false
    multiline_comment = false
    out = ''
    chars.each do |char|
      # start of line comment
      line_comment = true if (char == '/') && (chars[i + 1] == '/')
      # end of line comment
      line_comment = false if (char == "\n") && line_comment
      # start of multiline comment
      multiline_comment = true if (char == '/') && (chars[i + 1] == '*')
      # end of multiline comment
      if (chars[i - 1] == '/') && (chars[i - 2] == '*')
        multiline_comment = false
        out += ' '
      end
      # if not in comment, add char to file
      out += char if !line_comment && !multiline_comment
      i += 1
    end
    out
  end
end

class CodeWriter
  def initialize 
      @class_name = ''
      @subroutine_name = ''
      @arg_count = 0
      @operator = []
      @file = File.new("Main.vm", 'w+')
  end

  # operator hash
  OPS = { "+" => "add",
          "*" => "call Math.multiply 2",
          "/" => "call Math.divide 2",
          "-" => "sub",
          "neg" => "neg", 
          ">" => "gt",
          "<" => "lt",
          "=" => "eq",
          "&" => "and",
          "~" => "not",
          "|" => "or"
        }
        
  def get_ops(key)
    OPS[key]
  end

  # set current class name
  def set_class_name(name)
      @class_name = name
  end
  
  #write subroutine name
  def write_subroutine_name(var_count)
    @file.puts "function #{@class_name}.#{@subroutine_name} #{var_count}"
  end

  # write object memory allocation commands
  def write_object_alloc(field_count)
    @file.puts "push constant #{field_count}"
    @file.puts "call Memory.alloc 1"
    @file.puts "pop pointer 0"
  end

  # write vm code for setting object to this
  def write_set_object_to_this
    @file.puts "push argument 0"
    @file.puts "pop pointer 0"
  end

  # write method name 
  def write_method_name(class_token, method_name_token)
  end

  # increment argument counter 
  def increment_arg_count
      @arg_count += 1
  end
  
  # reset arg count
  def reset_arg_count
      @arg_count = 0
  end

  #write argument count of current subroutine and resets arg count to zero
  def write_local_count(var_count)
      @file.puts "#{var_count} "
  end

  # write subroutine call
  def write_subroutine_call
      @file.puts "call #{@subroutine_name}#{@arg_count}"
      @arg_count = 0
  end
  
  # push keyword
  def push_keyword(token)
    case token.val
    when "true"
      @file.puts "push constant 0"
      @file.puts "not"
    when "false", "null"
      @file.puts "push constant 0"
    when "this"
      @file.puts "push pointer 0"
    end
  end

  # push constant
  def push_constant(const)
    @file.puts "push constant #{const}"
  end

  # push string to stack
  def push_string(string)
    @file.puts "push constant #{string.length}"
    @file.puts "call String.new 1"
    string = string.chars
    string.each do |char|
      @file.puts "push constant #{char.ord}"
      @file.puts "call String.appendChar 2"
    end
  end

  # push variable 
  def push_variable(token)
    @file.puts "push #{$st.lookup(token)}"
  end
  
  #pop variable 
  def pop_variable(token)
    @file.puts "pop #{$st.lookup(token)}"
  end
  
  def pop_array
    @file.puts "pop temp 0"
    @file.puts "pop pointer 1"
    @file.puts "push temp 0"
    @file.puts "pop that 0"
  end

  # push value found at memory index at top of stack to stack
  def push_array_index
    @file.puts "pop pointer 1"
    @file.puts "push that 0"
  end

  # write operator 
  def write_operator
    @file.puts "#{OPS[@operator.pop]}"
  end

  # push temp 0 for void functions
  def pop_temp_0
    @file.puts "pop temp 0"
  end

  # write push pointer 0
  def push_pointer_0
    @file.puts "push pointer 0" 
  end

  # write return statement 
  def write_return(void, constructor)
    @file.puts "push constant 0" if void
    @file.puts "return"
  end

  # writes while label
  def write_while_label(count)
    @file.puts "label WHILE_EXP#{count}"
  end

  # writes while ifgoto
  def write_while_ifgoto(count)
    @file.puts "not"
    @file.puts "if-goto WHILE_END#{count}"
  end
  
  # writes while end
  def write_while_end(count)
    @file.puts "goto WHILE_EXP#{count}"
    @file.puts "label WHILE_END#{count}"
  end

  # writes ifgoto 
  def write_ifgoto(count)
    @file.puts "if-goto IF_TRUE#{count}"
    @file.puts "goto IF_FALSE#{count}"
    @file.puts "label IF_TRUE#{count}"
  end

  def write_if_false(count) 
    @file.puts "goto IF_END#{count}"
    @file.puts "label IF_FALSE#{count}"
  end

  def write_if_end(count)
    @file.puts "label IF_END#{count}"
  end

  # push operator onto @operator stack
  def push_operator(sym) 
    @operator.push(sym) 
  end
  
  # get vm
  def get_vm
      @file
  end

  # close file
  def close_file
    @file.close 
  end

  def set_subroutine_name(name)
    @subroutine_name = name
  end
end

$st = ST.new
$cw = CodeWriter.new