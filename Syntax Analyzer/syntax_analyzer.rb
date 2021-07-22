require './tokenizer'
require './compilation_engine'

# Top level class for syntax analysis of one or more .jack files
class Analyzer
    # Runs Tokenizer methods to tokenize file
    def self.tokenize(file)
        file = Tokenizer.remove_returns(file)
        file = Tokenizer.tokenize(file)
        file = Tokenizer.filter_blank(file)
        file
    end
    
    # analyze file and return xml tree
    def self.analyze(file)
        file = Analyzer.tokenize(file)
        c = Compilation.new(file)
        out = c.comp_class
        out
    end
end