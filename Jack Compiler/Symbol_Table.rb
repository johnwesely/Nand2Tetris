# frozen_string_literal: true

# Symbol Table Module
class ST
  def initialize
    @class = {}
    @subroutine = {}
    @static_count = 0
    @field_count = 0
    @arg_count = 0
    @var_count = 0
  end

  # adds variable to subroutine hashtable and returns VM memory address
  def add_subroutine_variable(token, type, kind)
    @subroutine[token.val] = Table_Entry.new(token.val, type, kind, index_of(kind))
  end

  # adds class variable to class hashtble and returns VM memory address
  def add_class_variable(token, type, kind)
    @class[token.val] = Table_Entry.new(token.val, type, kind, index_of(kind))
  end

  # lookup variable name in subroutine then class level hashes
  # return VM memory assoociated with variable name
  def lookup(token)
    if @subroutine.key?(token.val)
      @subroutine[token.val].vm_address
    elsif @class.key?(token.val)
      @class[token.val].vm_address
    else
      puts "#{token.val} cannot be found in symbol tables"
    end
  end

  # returns class of identifier
  def get_class(token)
    if @subroutine.key?(token.val)
      @subroutine[token.val].get_class
    else
      @class[token.val].get_class
    end
  end

  # returns true is key is in class or subroutine symbol tables
  def in_table?(key)
    (@subroutine.key?(key) || @class.key?(key))
  end

  # reset subroutine hash
  def reset_subroutine
    @sub_routine = {}
    @arg_count = 0
    @var_count = 0
    @in_subroutine = false
  end

  # returns index number for variable and increments appropriate counter
  def index_of(kind)
    case kind
    when 'static'
      inc_static
      (@static_count - 1).to_s
    when 'field'
      inc_field
      (@field_count - 1).to_s
    when 'argument'
      inc_arg
      (@arg_count - 1).to_s
    when 'var'
      inc_var
      (@var_count - 1).to_s
    end
  end

  # incrementers for variable counters
  def inc_static
    @static_count += 1
  end

  def inc_field
    @field_count += 1
  end

  def inc_arg
    @arg_count += 1
  end

  def inc_var
    @var_count += 1
  end
end

# idenifier datatype
class Table_Entry
  attr_reader :name, :type, :kind, :index

  def initialize(name, type, kind, index)
    @name = name
    @type = type
    @kind = kind_of(kind)
    @index = index
  end

  # convert .jack kind to VM memory segment name
  def kind_of(kind)
    case kind
    when 'var'
      'local'
    when 'field'
      'this'
    else
      kind
    end
  end

  def vm_address
    "#{@kind} #{@index}"
  end

  # class getter
  def get_class
    @type
  end
end
