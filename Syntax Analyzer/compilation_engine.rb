# compilation engine
class Compilation
  def initialize(tokens)
    @tokens = tokens
    @i = 0
    @xml = ''
  end

  # write single line of xml code
  def comp_line
    @xml += "<#{@tokens[@i].type}> #{@tokens[@i].val} </#{@tokens[@i].type}>  "
    @i += 1
  end

  # logic for compile methods
  # if token is the beginning of a substructure call that substructures method
  # else call comp line
  def comp_class
    @xml += '<class>  '
    while @i < @tokens.length
      puts "identifier: #{@tokens[@i].val}"
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
  end

  def comp_class_var_dec
    @xml += '<classVarDec>  '
    while @i < @tokens.length
      comp_line
      case @tokens[@i].val
      when ';'
        break
      end
    end
    @xml += '</classVarDec>  '
    nil
  end

  def comp_subroutine
    @xml += '<subroutineDec>  '
    while @i < @tokens.length
      comp_line
      case @tokens[@i].val
      when '('
        comp_parameter_list
        comp_subroutine_body
        break
      end
    end
    @xml += '</subroutineDec>  '
    nil
  end

  def comp_parameter_list
    @xml += '<parameterList>  '
    while @i < @tokens.length
      case @tokens[@i].val
      when ')'
        break
      else
        comp_line
      end
    end
    @xml += '</parameterList>  '
    comp_line
    nil
  end

  def comp_subroutine_body
    @xml += '<subroutineBody>  '
    comp_line
    while @i < @tokens.length
      case @tokens[@i].val
      when '}'
        comp_line
        break
      when 'var'
        comp_var_dec
      else
        comp_statements
      end
    end
    @xml += '</subroutineBody>  '
    nil
  end

  def comp_var_dec
    @xml += '<varDec>  '
    while @i < @tokens.length
      comp_line
      case @tokens[@i].val
      when ';'
        break
      end
    end
    @xml += '</varDec>  '
    nil
  end

  # statement*
  def comp_statements
    @xml += '<statements>  '
    loop do
      puts "statement type: #{@tokens[@i].val}"
      sleep(0.1)
      case @tokens[@i].val
      when 'let'
        comp_let_statements
      when 'if'
        comp_if
      when 'while'
        comp_while
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
    @xml += '<letStatement>  '
    comp_line       # let
    comp_line       # varName
    if @tokens[@i].val == '['
      comp_line # [
      comp_expression
      comp_line # ]
    end
    comp_line       # =
    comp_expression
    comp_line       # ;
    @xml += '</letStatement>  '
    nil
  end

  # 'do' subroutineCall ';'
  def comp_do
    @xml += '<doStatement>  '
    comp_line  # do
    comp_subroutine_call
    comp_line  # ;
    @xml += '</doStatement>  '
    nil
  end

  # 'while' '(' expression ')' '{' statements '}'
  def comp_while
    @xml += '<whileStatement>  '
    comp_line   # while
    comp_line   # (
    comp_expression
    comp_line   # )
    comp_line   # {
    comp_statements
    comp_line   # }
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
    nil
  end

  # 'if' '(' expression ')' '{' statements '}' ('else' '{' statements '}')?
  def comp_if
    @xml += '<ifStatement>  '
    comp_line    # if
    comp_line    # (
    comp_expression
    comp_line    # )
    comp_line    # {
    comp_statements
    comp_line    # }
    if @tokens[@i].val == 'else'
      comp_line # else
      comp_line   # {
      comp_statements
      comp_line   # }
    end
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
        comp_line # symbol
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
    when 'integerConstant', 'stringConstant'
      comp_line
    when 'keyword'
      comp_line
    when 'identifier'
      comp_identifier_term
    when 'symbol'
      comp_line
      comp_term
    end
    @xml += '</term>  '
  end

  def comp_identifier_term
    case @tokens[@i + 1].val
    when '['
      comp_line   # varName
      comp_line   # '['
      comp_expression
      comp_line   # ']'
    when '(', '.'
      comp_subroutine_call
    else
      comp_line # varName
    end
    nil
  end

  def comp_expression_list
    @xml += '<expressionList>  '
    loop do
      case @tokens[@i].val
      when ')' # end of expression list
        break
      when ','
        comp_line            # ,
        next
      else
        comp_expression      # expression
      end
    end
    @xml += '</expressionList>  '
  end

  def comp_subroutine_call
    comp_line # subroutineName | className | varName
    if @tokens[@i].val == '.'
      comp_line # .
      comp_line # subroutineName
    end
    comp_line      # (
    comp_expression_list
    comp_line      # )
  end
end
