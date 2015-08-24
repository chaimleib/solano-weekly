require 'pry'
require_relative '../lib/solano_report'

files = Dir.glob "#{File.dirname __FILE__}/data/*.csv"

reports = files.each_with_object({}){ |path, result|
  key = File.basename path, '.csv'
  result[key] = SolanoReport.new.load_csv path
}

binding.pry
