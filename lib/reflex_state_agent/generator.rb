
require 'csv'
require 'tco' # temp for debugging purposes
require 'pry' # for debugging

class AutoGen
  attr_accessor :path, :name, :states
  attr_accessor :selectors, :actor
  def initialize(_path, actor="automaton")
    @path = _path
    @name = File.basename(_path)
    @states = Dir.entries(_path).select! {|e| File.extname(e) == '.csv' }
    @states.map! {|e| e.gsub('.csv', '') }
    @selectors = ["any", "sub"]
    @actor = actor
  end

  def camelize(underscore)
   underscore.split("_").map { |word| word.capitalize }.join
  end

  def class_heading(class_name)
    str_class_header = <<-CLASSHEADING.gsub(/^\s{6}/,"")
      \n
      class #{class_name} < BaseStage
        def self.process(#{@actor}, percept)
          case
    CLASSHEADING
  end

  def generate_base
    base_class = <<-BASECLASS.gsub(/^\s{6}/,"")
      # Base class auto generated
      class BaseStage
        def self.subset(_opts, sub)
          subset = _opts.select { |k,v| sub.keys.include? k }
          subset == sub
        end
      
        def self.any(_opts, matches)
          matches.each do |key, _|
            return true if _opts[key] == matches[key]
          end
          false
        end
      
        def self.process(test, percepts)
          raise "Base processing default should never be called"
        end
      
        def self.transition(test, stage)
          puts "TRANSITION: #\{self\} => #\{stage\}".fg 'green'
          #{@actor}.stage = stage
        end
      
        def self.action(test, action)
          puts "ACTION: #\{self\} stage, calling test.#\{action\}".fg 'green'
          #{@actor}.send(action)
        end
      end
    BASECLASS
  end

  def generate
    File.open("gen_#{@name}.rb", 'w') do |file|
      file.puts generate_base
      @states.each do |state|
        print_state(file, state)
      end
    end
  end

  def print_state(file, state)
    state_csv = CSV.read("#{@path}/#{state}.csv")
    header = state_csv.shift
    file.puts class_heading(camelize(state))

    state_csv.each do |line|
      casehits = ""
      action = ""
      transition = ""

      header.each_with_index do |trigger, idx|
        row_item = line[idx].strip
        trigger.strip!
        case trigger
        when /action/
          action = (row_item == "-") ? "" : "      #{@actor}.#{row_item}"
        when "transition"
          transition = (row_item == "-") ? "" : "      transition(#{@actor}, #{row_item})"
        else
          unless @selectors.include? row_item 
            casehits += ", #{trigger}: \"#{row_item}\"" unless row_item == "-"
          end
        end
      end

      case line[0]
      when "sub"
        file.puts "    when subset(percepts#{casehits})"
      when "any"
        file.puts "    when any(percepts#{casehits})"
      end
      file.puts action     unless action == ""
      file.puts transition unless transition == ""
    end
    file.puts "    end"
    file.puts "  end"
    file.puts "end"
  end
end
