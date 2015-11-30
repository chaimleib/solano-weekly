#!/usr/bin/env ruby

require_relative '../lib/solano_statistics_writer'


def load_report(files)
  report = SolanoReport.new
  files.each{|path| report.load_csv path}
  report
end

def write_xlsx(start=nil)
  tz = TZInfo::Timezone.get('America/Los_Angeles')
  root_dir = File.expand_path "#{File.dirname __FILE__}/.."
  in_files = Dir.glob "#{root_dir}/data/*.csv"
  out_dir = "#{root_dir}/output"
  start = "2015-11-23" if start.blank?
  start = start.in_time_zone(tz)
  duration = 7.days

  report = load_report in_files
  options = {
    tz: tz,
    start: start,
    duration: duration
  }
  stats = report.summary options
  stats.merge! report.fail_times options

  stats[:meta].merge!({
    in_files: in_files.sort,
  })

  FileUtils.mkdir_p out_dir
  SolanoStatisticsWriter.write_weekly_report(
    data: stats,
    ofile: "#{out_dir}/solano_week_#{start.strftime '%Y-%m-%d'}.xlsx"
  )
end

write_xlsx
