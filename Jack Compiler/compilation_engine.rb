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
    @xml = ''
    # class name
    @class = ''
    # method array for self method calls
    @method_names = [] 
  end

  # xml getter for debug
  def xml
    @xml
  end

  # write single line of xml code
  def comp_line
    if (@tokens[@i].type == "identifier")
      @xml += $st.lookup(@tokens[@i])
      @i += 1
    else
      @xml += "<#{@tokens[@i].type}> #{@tokens[@i].val} </#{@tokens[@i].type}>  "
      @i += 1
    end
  end

  # logic for compile methods
  # if token is the beginning of a substructure call that substructures method
  # else call comp line
  def comp_class
    # set field count to zero
    @field_count = 0
    @method_names = []
    @xml += '<class>  '
    @xml += "<keyword>  #{@tokens[@i].val} </keyword>  "  # class
    @i += 1
    # instantiate Codewriter object
    # set cw.@class_name to class name
    $cw.set_class_name(@tokens[@i].val)
    @class = @tokens[@i].val
    @xml += "<symbol>  #{@tokens[@i].val} </symbol>  " # class name
    @i += 1
    while @i < @tokens.length
      @constructor = true if (@tokens[@i].val == 'constructor')
      @method = true if (@tokens[@i].val == 'method')
      case @tokens[@i].val
      when 'static', 'field'
        comp_class_var_dec
        next
      when 'constructor', 'function', 'method'
        comp_subroutine
        next
      else
        comp_line
      end
    end
    @xml += '</class>  '
    @xml
    $cw.close_file
  end

  def comp_class_var_dec
    @xml += '<classVarDec>  '
    kind = @tokens[@i].val
    comp_line    # variable kind
    type = @tokens[@i].val
    comp_line    # variable type
    loop do
      case @tokens[@i].val
      when ";"
        comp_line  # ;
        break
      when ","
        comp_line
      else 
        @field_count += 1 if (kind == "field")
        @xml += $st.add_class_variable(@tokens[@i], type, kind)
        @i += 1    # ,
      end
    end
    @xml += '</classVarDec>  '
    nil
  end

  def comp_subroutine
    # reset while, if, and var counters
    @while_count = 0
    @if_count = 0
    @var_count = 0

    @xml += '<subroutineDec>  '
    @xml += "<keyword> #{@tokens[@i].val} </keyword>  "  #subroutine type
    @i += 1
    # is return type void?
    @void = (@tokens[@i].val == "void")
    @i += 1  # return type
    @xml += "<identifier> #{@tokens[@i].val} </identifier>  " #subroutine name
    # write subroutine name
    # if method, pushes name onto method name array
    @method_names.push(@tokens[@i].val)
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
    @xml += '</subroutineDec>  '
    nil
  end
  
  def comp_parameter_list
    # increment argument to account for this if method
    $st.inc_arg if @method
    comp_line # (
    @xml += '<parameterList>  '
    while @i < @tokens.length
      case @tokens[@i].val
      when ')'
        break
      when '('
        comp_line
      when ','
        comp_line
      else
        type = @tokens[@i].val 
        comp_line  # type
        @xml += $st.add_subroutine_variable(@tokens[@i], type, "argument")
        # increment argument count
        $cw.increment_arg_count
        @i += 1
      end
    end
    @xml += '</parameterList>  '
    comp_line
    nil
  end

  def comp_subroutine_body
    @xml += '<subroutineBody>   '
    comp_line
    puts @tokens[@i].val
    while @i < @tokens.length
      case @tokens[@i].val
      when '}'
        comp_line
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
    @xml += '</subroutineBody>  '
    nil
  end

  def comp_var_dec
    # if method, increment arg count to account for object
    @xml += '<varDec>  '
    kind = @tokens[@i].val
    comp_line    # kind
    type = @tokens[@i].val
    comp_line    # type
    loop do
      case @tokens[@i].val
      when ','
        comp_line
      when ';'
        comp_line # ;
        break
      else
        @var_count += 1
        @xml += $st.add_subroutine_variable(@tokens[@i], type, kind)
        @i += 1
      end
    end
    @xml += '</varDec>  '
    nil
  end

  # statement*
  def comp_statements
    puts "comp_statements"
    puts "#{@tokens[@i].val}"
    @xml += '<statements>  '
    loop do
      case @tokens[@i].val
      when 'let'
        puts "let"
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
    @xml += '</statements>  '
    nil
  end

  # 'let' varName ('[' expression ']')? '=' expression ';'
  def comp_let_statements
    # array boolean
    arr = false
    puts "let expression"
    @xml += '<letStatement>  '
    comp_line       # let
    # variable name for popping value to at end of statement
    var_token = @tokens[@i]
    comp_line       # var_name
    if @tokens[@i].val == '['
      arr_base = @tokens[@i-1]
      arr = true
      comp_line # [
      comp_expression
      comp_line # ]
      # add adresss of array to evaluated expression
      $cw.push_variable(arr_base)
      $cw.push_operator("+")
      $cw.write_operator
    end
    comp_line       # =
    comp_expression
    comp_line       # ;
    if arr
      $cw.pop_array
    else
      $cw.pop_variable(var_token)
    end
    @xml += '</letStatement>  '
    nil
  end

  # 'do' subroutineCall ';'
  def comp_do
    @xml += '<doStatement>  '
    comp_line  # do
    comp_subroutine_call
    comp_line  # ;
    # pop return value off stack
    $cw.pop_temp_0
    @xml += '</doStatement>  '
    nil
  end

  # 'while' '(' expression ')' '{' statements '}'
  def comp_while(count)
    # increment while_count
    @while_count += 1
    # while label
    $cw.write_while_label(count)
    @xml += '<whileStatement>  '
    comp_line   # while
    comp_line   # (
    comp_expression
    comp_line   # )
    # while ifgoto
    $cw.write_while_ifgoto(count)
    comp_line   # {
    comp_statements
    comp_line   # }
    $cw.write_while_end(count)
    @xml += '</whileStatement>  '
    nil
  end

  # 'return' expression? ';'
  def comp_return
    @xml += '<returnStatement>  '
    comp_line   # return
    comp_expression unless @tokens[@i].val == ';'
    comp_line   # ;
    @xml += '</returnStatement>  '
    $cw.write_return(@void, @constructor)
    nil
  end

  # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')?
  def comp_if(count)
    # increment if count
    @if_count += 1

    @xml += '<ifStatement>  '
    comp_line    # if
    comp_line    # (
    comp_expression
    comp_line    # )
    $cw.write_ifgoto(count)
    comp_line    # {
    comp_statements
    comp_line    # }
    $cw.write_if_false(count)
    if @tokens[@i].val == 'else'
      comp_line # else
      comp_line   # {
      comp_statements
      comp_line   # }
    end
    $cw.write_if_end(count)
    @xml += '</ifStatement>  '
  end

  # term (op term)*
  def comp_expression
    @xml += '<expression>  '
    comp_term
    loop do
      case @tokens[@i].val
      when ')', ';', ']', ','
        break
      else
        comp_term
      end
    end
    @xml += '</expression>  '
    nil
  end

  def comp_term
    @xml += '<term>  '
    if @tokens[@i].val == '(' # if term is expression
      comp_line # (
      comp_expression
      comp_line # )
      @xml += '</term>  '
      return
    end
    case @tokens[@i].type
    when 'integerConstant'
      # push constant to stack 
      $cw.push_constant(@tokens[@i].val)
      comp_line
    when 'stringConstant'
      $cw.push_string(@tokens[@i].val)
      @i += 1
    when 'keyword'
      # push true or false to stack
      $cw.push_keyword(@tokens[@i])
      comp_line
    when 'identifier'
      comp_identifier_term
    when 'symbol'
      # set operator for writing after operands have been pushed to stack
      if (@tokens[@i-1].val == "(" && (@tokens[@i].val == "-"))
        $cw.push_operator("neg")
      else
        $cw.push_operator(@tokens[@i].val)
      end
      puts "operator: #{@tokens[@i].val}"
      comp_line
      comp_term
      # write operator to vm code
      $cw.write_operator
    end
    @xml += '</term>  '
  end

  def comp_identifier_term
    case @tokens[@i + 1].val
    when '['
      arr_base = @tokens[@i]
      comp_line   # varName
      comp_line   # '['
      puts "!!!comp expression in array index"
      comp_expression
      comp_line   # ']'
      # add address of array to evaluated expression 
      puts "push array variable to stack"
      $cw.push_variable(arr_base)
      $cw.push_operator("+")
      $cw.write_operator
      $cw.push_array_index
    when '(', '.'
      comp_subroutine_call
    else
      # push VM memory location to stack
      $cw.push_variable(@tokens[@i])
      comp_line # varName
    end
    nil
  end

  def comp_expression_list
    puts "comp expression list"
    @xml += '<expressionList>  '
    loop do
      case @tokens[@i].val
      when ')' # end of expression list
        break
      when ','
        comp_line            # ,
        next
      else
        # increment arg count
        $cw.increment_arg_count
        comp_expression      # expression
      end
    end
    @xml += '</expressionList>  '
  end

  def comp_subroutine_call
    if (@tokens[@i+1].val == "." && $st.in_table?(@tokens[@i].val))
      comp_method_call(true)
      return
    elsif (@tokens[@i+1].val == ".")
      comp_compound_subroutine_name
    else (@method_names.include?(@tokens[@i].val))
      comp_method_call(false)
      return
    #else
    #  comp_subroutine_name
    end
    # set arg count to zero
    $cw.reset_arg_count
    comp_line  # (
    comp_expression_list
    comp_line  # )
    $cw.write_subroutine_call
  end
  
  # compiles method call
  def comp_method_call(compound)
    # set method class and name
    if compound 
      $cw.set_subroutine_name("#{$st.get_class(@tokens[@i])}.#{@tokens[@i+2].val} ")
    else
      $cw.set_subroutine_name("#{@class}.#{@tokens[@i].val} ")
    end
    # push object onto stack
    $cw.push_variable(@tokens[@i]) if compound
    $cw.push_pointer_0 if !compound
    @i +=1
    @i +=1 if compound
    @i +=1 if compound
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
    #set method class and name
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
    if ($st.in_table?(@tokens[@i].val))
      @xml += $st.lookup(@tokens[@i])
      # className of object assigned to variable 
      subroutine_name += "#{$st.get_class(@tokens[@i])}."
    else
      subroutine_name += "#{@tokens[@i].val}."
      @xml += "<identifer> #{@tokens[@i].val} </identifier>  "
    end
    @i += 1
    comp_line  # .
    subroutine_name += "#{@tokens[@i].val} "
    @xml += "<identifer> #{@tokens[@i].val} </identifier>  "
    @i += 1
    $cw.set_subroutine_name(subroutine_name)
    return nil
  end

  def comp_subroutine_name
    subroutine_name = "#{@class}.#{@tokens[@i].val} "
    @xml += "<identifer> #{@tokens[@i].val} </identifier>  "
    @i += 1  # {
    $cw.set_subroutine_name(subroutine_name)
  end


end
