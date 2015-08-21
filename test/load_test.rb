require 'pry'
require_relative '../lib/solano_report'

files = Dir.glob "data/*.csv"

reports = files.each_with_object({}){ |path, result|
  key = File.basename path, '.csv'
  result[key] = SolanoReport.new path
}

binding.pry
