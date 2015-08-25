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
  start: DateTime.parse("2015-08-17T00:00:00-7"),
  duration: 7.days
)
binding.pry
