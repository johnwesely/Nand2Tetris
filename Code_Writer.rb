# frozen_string_literal: true

class CodeWriter
  def initialize
    @class_name = ''
    @subroutine_name = ''
    @arg_count = 0
    @operator = []
    @file = File.new("#{$filename}.vm", 'w+')
  end

  # operator hash
  OPS = { '+' => 'add',
          '*' => 'call Math.multiply 2',
          '/' => 'call Math.divide 2',
          '-' => 'sub',
          'neg' => 'neg',
          '>' => 'gt',
          '<' => 'lt',
          '=' => 'eq',
          '&' => 'and',
          '~' => 'not',
          '|' => 'or' }.freeze

  def get_ops(key)
    OPS[key]
  end

  # set current class name
  def set_class_name(name)
    @class_name = name
  end

  # write subroutine name
  def write_subroutine_name(var_count)
    @file.puts "function #{@class_name}.#{@subroutine_name} #{var_count}"
  end

  # write object memory allocation commands
  def write_object_alloc(field_count)
    @file.puts "push constant #{field_count}"
    @file.puts 'call Memory.alloc 1'
    @file.puts 'pop pointer 0'
  end

  # write vm code for setting object to this
  def write_set_object_to_this
    @file.puts 'push argument 0'
    @file.puts 'pop pointer 0'
  end

  # write method name
  def write_method_name(class_token, method_name_token); end

  # increment argument counter
  def increment_arg_count
    @arg_count += 1
  end

  # reset arg count
  def reset_arg_count
    @arg_count = 0
  end

  # write argument count of current subroutine and resets arg count to zero
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
    when 'true'
      @file.puts 'push constant 0'
      @file.puts 'not'
    when 'false', 'null'
      @file.puts 'push constant 0'
    when 'this'
      @file.puts 'push pointer 0'
    end
  end

  # push constant
  def push_constant(const)
    @file.puts "push constant #{const}"
  end

  # push string to stack
  def push_string(string)
    @file.puts "push constant #{string.length}"
    @file.puts 'call String.new 1'
    string = string.chars
    string.each do |char|
      @file.puts "push constant #{char.ord}"
      @file.puts 'call String.appendChar 2'
    end
  end

  # push variable
  def push_variable(token)
    @file.puts "push #{$st.lookup(token)}"
  end

  # pop variable
  def pop_variable(token)
    @file.puts "pop #{$st.lookup(token)}"
  end

  def pop_array
    @file.puts 'pop temp 0'
    @file.puts 'pop pointer 1'
    @file.puts 'push temp 0'
    @file.puts 'pop that 0'
  end

  # push value found at memory index at top of stack to stack
  def push_array_index
    @file.puts 'pop pointer 1'
    @file.puts 'push that 0'
  end

  # write operator
  def write_operator
    @file.puts (OPS[@operator.pop]).to_s
  end

  # push temp 0 for void functions
  def pop_temp_0
    @file.puts 'pop temp 0'
  end

  # write push pointer 0
  def push_pointer_0
    @file.puts 'push pointer 0'
  end

  # write return statement
  def write_return(void, _constructor)
    @file.puts 'push constant 0' if void
    @file.puts 'return'
  end

  # writes while label
  def write_while_label(count)
    @file.puts "label WHILE_EXP#{count}"
  end

  # writes while ifgoto
  def write_while_ifgoto(count)
    @file.puts 'not'
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
