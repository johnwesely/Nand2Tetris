# frozen_string_literal: true

# compilation engine
class Compilation
  def initialize(tokens)
    @tokens = tokens
    @i = 0
    # counters for nested while and if statements
    @while_count = 0
    @if_count = 0
    # counter for number of fields in an object
    @field_count = 0
    # booleans for whether function is void or a constructor
    @void = true
    @constructor = false
    @method = false
    # class name
    @class = ''
  end

  # logic for compile methods
  # if token is the beginning of a substructure call that substructures method
  # else increment @i to access next symbol
  def comp_class
    # set field count to zero
    @field_count = 0
    @i += 1
    # instantiate new Codewrite instance
    $cw = CodeWriter.new
    $st = ST.new
    # set cw.@class_name to class name
    $cw.set_class_name(@tokens[@i].val)
    @class = @tokens[@i].val
    @i += 1
    while @i < @tokens.length
      @constructor = true if @tokens[@i].val == 'constructor'
      @method = true if @tokens[@i].val == 'method'
      case @tokens[@i].val
      # add class variables to symbol table
      when 'static', 'field'
        comp_class_var_dec
        next
      when 'constructor', 'function', 'method'
        comp_subroutine
        next
      else
        @i += 1
      end
    end
    $cw.close_file
  end

  def comp_class_var_dec
    kind = @tokens[@i].val
    @i += 1    # variable kind
    type = @tokens[@i].val
    @i += 1    # variable type
    loop do
      case @tokens[@i].val
      when ';'
        @i += 1  # ;
        break
      when ','
        @i += 1  # ,
      else
        @field_count += 1 if kind == 'field'
        $st.add_class_variable(@tokens[@i], type, kind)
        @i += 1 # ,
      end
    end
    nil
  end

  def comp_subroutine
    # reset while, if, and var counters
    @while_count = 0
    @if_count = 0
    @var_count = 0
    @i += 1
    # is return type void?
    @void = (@tokens[@i].val == 'void')
    @i += 1 # return type
    # write subroutine name
    $cw.set_subroutine_name(@tokens[@i].val)
    @i += 1
    while @i < @tokens.length
      case @tokens[@i].val
      when '('
        comp_parameter_list
        comp_subroutine_body
        break
      end
    end
    # reset subroutine scope hash table
    $st.reset_subroutine
    @constructor = false
    @method = false
    nil
  end

  def comp_parameter_list
    # increment argument to account for this if method
    $st.inc_arg if @method
    @i += 1 # (
    while @i < @tokens.length
      case @tokens[@i].val
      when ')'
        break
      when '('
        @i += 1
      when ','
        @i += 1
      else
        type = @tokens[@i].val
        @i += 1 # type
        $st.add_subroutine_variable(@tokens[@i], type, 'argument')
        # increment argument count
        $cw.increment_arg_count
        @i += 1
      end
    end
    @i += 1
    nil
  end

  def comp_subroutine_body
    @i += 1
    puts @tokens[@i].val
    while @i < @tokens.length
      case @tokens[@i].val
      when '}'
        @i += 1
        break
      when 'var'
        comp_var_dec
      else
        # write subroutine name and number of local variables
        $cw.write_subroutine_name(@var_count)
        $cw.write_object_alloc(@field_count) if @constructor
        $cw.write_set_object_to_this if @method
        comp_statements
      end
    end
    nil
  end

  def comp_var_dec
    # if method, increment arg count to account for object
    kind = @tokens[@i].val
    @i += 1    # kind
    type = @tokens[@i].val
    @i += 1    # type
    loop do
      case @tokens[@i].val
      when ','
        @i += 1
      when ';'
        @i += 1 # ;
        break
      else
        @var_count += 1
        $st.add_subroutine_variable(@tokens[@i], type, kind)
        @i += 1
      end
    end
    nil
  end

  # statement*
  def comp_statements
    loop do
      case @tokens[@i].val
      when 'let'
        comp_let_statements
      when 'if'
        comp_if(@if_count)
      when 'while'
        comp_while(@while_count)
      when 'do'
        comp_do
      when 'return'
        comp_return
        break
      when '}'
        break
      end
    end
    nil
  end

  # 'let' varName ('[' expression ']')? '=' expression ';'
  def comp_let_statements
    # array boolean
    arr = false
    @i += 1 # let
    # variable name for popping value to at end of statement
    var_token = @tokens[@i]
    @i += 1 # var_name
    if @tokens[@i].val == '['
      arr_base = @tokens[@i - 1]
      arr = true
      @i += 1 # [
      comp_expression
      @i += 1 # ]
      # add adresss of array to evaluated expression
      $cw.push_variable(arr_base)
      $cw.push_operator('+')
      $cw.write_operator
    end
    @i += 1       # =
    comp_expression
    @i += 1       # ;
    if arr
      $cw.pop_array
    else
      $cw.pop_variable(var_token)
    end
    nil
  end

  # 'do' subroutineCall ';'
  def comp_do
    @i += 1  # do
    comp_subroutine_call
    @i += 1  # ;
    # pop return value off stack
    $cw.pop_temp_0
    nil
  end

  # 'while' '(' expression ')' '{' statements '}'
  def comp_while(count)
    # increment while_count
    @while_count += 1
    # while label
    $cw.write_while_label(count)
    @i += 1   # while
    @i += 1   # (
    comp_expression
    @i += 1   # )
    # while ifgoto
    $cw.write_while_ifgoto(count)
    @i += 1   # {
    comp_statements
    @i += 1   # }
    $cw.write_while_end(count)
    nil
  end

  # 'return' expression? ';'
  def comp_return
    @i += 1   # return
    comp_expression unless @tokens[@i].val == ';'
    @i += 1   # ;
    $cw.write_return(@void, @constructor)
    nil
  end

  # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')?
  def comp_if(count)
    # increment if count
    @if_count += 1
    @i += 1    # if
    @i += 1    # (
    comp_expression
    @i += 1    # )
    $cw.write_ifgoto(count)
    @i += 1    # {
    comp_statements
    @i += 1    # }
    $cw.write_if_false(count)
    if @tokens[@i].val == 'else'
      @i += 1 # else
      @i += 1   # {
      comp_statements
      @i += 1   # }
    end
    $cw.write_if_end(count)
  end

  # term (op term)*
  def comp_expression
    comp_term
    loop do
      case @tokens[@i].val
      when ')', ';', ']', ','
        break
      else
        comp_term
      end
    end
    nil
  end

  def comp_term
    if @tokens[@i].val == '(' # if term is expression
      @i += 1 # (
      comp_expression
      @i += 1 # )
      return
    end
    case @tokens[@i].type
    when 'integerConstant'
      # push constant to stack
      $cw.push_constant(@tokens[@i].val)
      @i += 1
    when 'stringConstant'
      $cw.push_string(@tokens[@i].val)
      @i += 1
    when 'keyword'
      # push true or false to stack
      $cw.push_keyword(@tokens[@i])
      @i += 1
    when 'identifier'
      comp_identifier_term
    when 'symbol'
      # set operator for writing after operands have been pushed to stack
      if @tokens[@i - 1].val == '(' && (@tokens[@i].val == '-')
        $cw.push_operator('neg')
      else
        $cw.push_operator(@tokens[@i].val)
      end
      @i += 1
      comp_term
      # write operator to vm code
      $cw.write_operator
    end
  end

  def comp_identifier_term
    case @tokens[@i + 1].val
    when '['
      arr_base = @tokens[@i]
      @i += 1   # varName
      @i += 1   # '['
      comp_expression
      @i += 1   # ']'
      # add address of array to evaluated expression
      $cw.push_variable(arr_base)
      $cw.push_operator('+')
      $cw.write_operator
      $cw.push_array_index
    when '(', '.'
      comp_subroutine_call
    else
      # push VM memory location to stack
      $cw.push_variable(@tokens[@i])
      @i += 1 # varName
    end
    nil
  end

  def comp_expression_list
    loop do
      case @tokens[@i].val
      when ')' # end of expression list
        break
      when ','
        @i += 1 # ,
        next
      else
        # increment arg count
        $cw.increment_arg_count
        comp_expression # expression
      end
    end
  end

  def comp_subroutine_call
    if @tokens[@i + 1].val == '.' && $st.in_table?(@tokens[@i].val)
      comp_method_call(true)
      return
    elsif @tokens[@i + 1].val == '.'
      comp_compound_subroutine_name
    else
      comp_method_call(false)
      return
    end
    # set arg count to zero
    $cw.reset_arg_count
    @i += 1  # (
    comp_expression_list
    @i += 1  # )
    $cw.write_subroutine_call
  end

  # compiles method call
  def comp_method_call(compound)
    # set method class and name
    if compound
      $cw.set_subroutine_name("#{$st.get_class(@tokens[@i])}.#{@tokens[@i + 2].val} ")
    else
      $cw.set_subroutine_name("#{@class}.#{@tokens[@i].val} ")
    end
    # push object onto stack
    $cw.push_variable(@tokens[@i]) if compound
    $cw.push_pointer_0 unless compound
    @i += 1
    @i += 1 if compound
    @i += 1 if compound
    # set arg count to 1
    $cw.reset_arg_count
    $cw.increment_arg_count
    @i += 1 # (
    comp_expression_list
    @i += 1 # )
    $cw.write_subroutine_call
  end

  # compiles self method
  def comp_self_method_call
    # set method class and name
    $cw.set_subroutine_name("#{@class}.#{@tokens[@i].val} ")
    # push self onto stack
    $cw.push_pointer_0
    @i += 1 # method name
    # reset arg count to 1
    $cw.reset_arg_count
    $cw.increment_arg_count
    @i += 1 # (
    comp_expression_list
    @i += 1 # )
    $cw.write_subroutine_call
  end

  # updates current subroutine name in codewriter for
  # subroutine names with a "."
  def comp_compound_subroutine_name
    subroutine_name = ''
    # className | varName |
    # if varName lookup up virtual vm memory address
    subroutine_name += if $st.in_table?(@tokens[@i].val)
                         # className of object assigned to variable
                         "#{$st.get_class(@tokens[@i])}."
                       else
                         "#{@tokens[@i].val}."
                       end
    @i += 1
    @i += 1  # .
    subroutine_name += "#{@tokens[@i].val} "
    @i += 1
    $cw.set_subroutine_name(subroutine_name)
    nil
  end

  def comp_subroutine_name
    subroutine_name = "#{@class}.#{@tokens[@i].val} "
    @i += 1  # {
    $cw.set_subroutine_name(subroutine_name)
  end
end
