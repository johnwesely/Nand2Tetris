require './tokenizer'
require './compilation_engine'
require './Symbol_Table'
require './Code_Writer'

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

  # select .jack files from directory, compile each into .vm file for each
  # 
  def self.compile_directory(dir)
    dir.each do |file|
      name = File.basename(file).split('.')[0]
      ext = File.basename(file).split('.')[1]
      next unless ext == 'jack'

      $filename = name
      current = File.open(file).read
      analyze(current)
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



Dir.chdir(ARGV[0])
dir = Dir.open(ARGV[0])

Analyzer.compile_directory(dir)