require 'pry'
require_relative '../lib/solano_report'

MyTZ = TZInfo::Timezone.get('America/Los_Angeles')

def load_report(files=Dir.glob("#{File.dirname __FILE__}/data/*.csv"))
  report = SolanoReport.new
  files.each{ |path| report.load_csv path }
  report
end
def group_builds(report, tz=MyTZ)
  by_date = report.group_by_date(tz)
  by_branch = by_date.each_with_object({}) do |(date, subreport), by_branch|
    by_branch[date] = subreport.group_by_branch
  end
end
def select_week(reports, week_start=DateTime.parse("2015-08-17T00:00:00-7"), tz=MyTZ)
  reports.select do |date, branches|
    utc = DateTime.parse(date).utc
    local = utc.in_time_zone(tz)
    week_start <= local && local <= week_start + 7.days
  end
end

report = load_report
grouped = group_builds report
week = select_week grouped

binding.pry
