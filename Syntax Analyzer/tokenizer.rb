# converts a single .jack file into an array of tokens
class Tokenizer 
    # symbol and keyword sets
    SYMBOL = Set["{", "}", "(", ")", "[", "]", ".", ",", ";", "+",
                 "-", "*", "/", "&", "|", "<", ">", "=", "~"]

    KEYWORD =Set["class", "constructor", "function", "method", "field", "static", 
                 "var", "int", "char", "boolean", "void", "true", "false", "null",
                 "this", "let", "do", "if", "else", "while", "return"]

    # tokenizes input file into array of tokens
    def self.tokenize(file) 
      input = file.chars
      output = []
      current = ""
      quote = false 
      
      # if char is doublequotes goto next doublequotes and add string constant 
      # to output
      # if char is not in SYMBOL set or blank space, append to current
      # else append current as appropriate type to output and char to output
      # as Symbol
      input.each do |char|
        if (quote and !(char == "\""))
          current += char
          next
        end
        if (!quote and (char == "\""))
            quote = true
            next
        end
        if (quote and (char == "\""))
            output.append(StringConstant.new(current))
            current = ""
            quote = false
            next
        end
        if (SYMBOL.include?(char))
            output.append(create_token(current))
            output.append(Sym.new(char))
            current = "" 
            next
        end
        if (char == " ")
            output.append(create_token(current))
            current = ""
            next
        end
        current += char
      end      
      output
    end

    # creates new token of appropriate type 
    def self.create_token(string)
        # IntConstant
        if ((string[0].to_i > 0) or (string[0] == "0"))
            return IntConstant.new(string)
        end
        # Keyword
        if (KEYWORD.include?(string))
            return Keyword.new(string)
        end
        # Identifier 
        Identifier.new(string)
    end

    #remove blank identifier tokens
    def self.filter_blank(tokens)
        out = []
        tokens.each do |token|
            if (!(token.is_a? Identifier))
                out.append token
                next
            end
            if (token.val.length > 0)
                out.append token
            end
        end
        out
    end

    #filter deritus from file input
    def self.remove_returns(str)
        str = str.gsub(/\r\n\t?/, "")
        str = str.gsub(/\n?/, "")
        str = str.gsub(/\r?/, "")
        str
    end
end

# Token datatype
class Token
    def initialize(string)
        @val = string
    end

    def val 
        @val
    end
end

# Datatypes for Lexical Elements
class Keyword < Token
    def type
        "keyword"
    end
end

class Sym < Token
    def type
        "symbol"
    end
end

class Identifier < Token
    def type
        "identifier"
    end
end

class IntConstant < Token
    def type
        "integerConstant"
    end
end

class StringConstant < Token
    def type
        "stringConstant"
    end
end





