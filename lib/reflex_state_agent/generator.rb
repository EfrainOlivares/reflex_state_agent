
require 'csv'
require 'tco' # temp for debugging purposes
require 'pry' # for debugging

class AutoGen
  attr_accessor :path, :name, :states
  def initialize(_path)
    @path = _path
    @name = File.basename(_path)
    @states = Dir.entries(_path).select! {|e| File.extname(e) == '.csv' }
    @states.map! {|e| e.gsub('.csv', '') }
  end

  def camelize(underscore)
   underscore.split("_").map { |word| word.capitalize }.join
  end

  def class_heading(class_name)
    str_class_header = <<-CLASSHEADING.gsub(/^\s{6}/,"")
      \n
     # #{class_name} state
      class #{class_name} < BaseReflexAutomaton
        def self.reflex(automaton, percept)
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
          test.stage = stage
        end

        def self.action(test, action)
          puts "ACTION: #\{self\} stage, calling test.#\{action\}".fg 'green'
          test.send(action)
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
        case trigger
        when /action/
          action = "      automaton.#{line[idx]}"
        when "transition"
          transition = (line[idx] == "-") ? "" : "      automaton.transition(#{line[idx]})"
        else
          casehits += ", #{trigger}: \"#{line[idx]}\"" unless line[idx] == "-"
        end
      end

      file.puts "    when subset(percept#{casehits})"
      file.puts action     unless action == ""
      file.puts transition unless transition == ""
    end
    file.puts "    end"
    file.puts "  end"
    file.puts "end"
  end
end
