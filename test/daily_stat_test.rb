require 'pry'
require_relative '../lib/solano_report'

MyTZ = TZInfo::Timezone.get('America/Los_Angeles')

def load_report(files=Dir.glob("#{File.dirname __FILE__}/data/*.csv"))
  report = SolanoReport.new
  files.each{ |path| report.load_csv path }
  report.sort_by(&:created_at)
end

report = load_report
stats = report.daily_statistics(
  tz: MyTZ,
  start: "2015-08-17".in_time_zone(MyTZ),
  duration: 7.days
)
binding.pry
