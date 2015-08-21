require 'pry'
require_relative '../lib/solano_report'

path = "#{File.dirname __FILE__}/data/master.csv"
report = SolanoReport.new path
start = DateTime.parse("2015-08-17T00:00:00-7")
stop = start + 7
filtered = report.select{ |b| start <= b.created_at && b.created_at < stop }
binding.pry
