require 'pry'

require_relative '../lib/solano_statistics_writer'

tz = TZInfo::Timezone.get('America/Los_Angeles')
in_files = Dir.glob "#{File.dirname __FILE__}/data/*.csv"
out_dir = "#{File.dirname __FILE__}/output"
start = DateTime.parse("2015-08-17T00:00:00-7")
duration = 7.days

ssw = SolanoStatisticsWriter

def load_report(files)
  report = SolanoReport.new
  files.each{ |path| report.load_csv path }
  report.sort_by(&:created_at)
end

report = load_report in_files
stats = report.daily_statistics(
  tz: tz,
  start: start,
  duration: duration
)
data = {
  stats: stats,
  report: report,
  start: start,
  duration: duration,
  tz: tz,
  in_files: in_files,
}

FileUtils.mkdir_p out_dir
ssw.write_daily_statistics(
  format: :xlsx,
  data: data,
  ofile:"#{out_dir}/weekly.xlsx")

