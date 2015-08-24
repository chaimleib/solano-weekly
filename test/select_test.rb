require 'pry'
require_relative '../lib/solano_report'

path = "#{File.dirname __FILE__}/data/master.csv"
report = SolanoReport.new.load_csv path
start = Time.parse("2015-08-17T00:00:00-7").to_time
stop = start + 7.days
filtered = report.select{ |b| start <= b.created_at && b.created_at < stop }
binding.pry
