require 'pry'
require_relative '../lib/solano_report'

MyTZ = TZInfo::Timezone.get('America/Los_Angeles')

def load_report(files=Dir.glob("#{File.dirname __FILE__}/data/*.csv"))
  report = SolanoReport.new
  files.each{ |path| report.load_csv path }
  report.sort_by(&:created_at)
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
def make_statistics(week, report, tz)  # report is full, ungrouped SolanoReport
  week.each do |day, branches|
    branches = branches.each_with_object({}) do |(branch, subreport), new_branches|
      failures = subreport.select{ |build| build.summary_status == :failed }
      fail_count = failures.length

      new_branches[branch] = {
        fail_count: fail_count,
        time_red: time_red(failures, report, tz),
      }
    end
    week[day] = branches
  end
end

def time_red(failures, report, tz)  # report is full, ungrouped SolanoReport
  return 0.0.seconds if failures.empty?

  failures = failures.sort_by(&:created_at)
  branches = report.group_by_branch.each_with_object({}) {|(branch, subreport), by_date|
    by_date[branch] = subreport.sort_by(&:created_at)
  }
  index_of = lambda do |build|
    branches[build.branch].index{|other_build|
      build.session_id == other_build.session_id
    }
  end
  next_build = lambda do |build|
    next_index = index_of.call(build) + 1
    branches[build.branch][next_index]
  end
  prev_build = lambda do |build|
    prev_index = index_of.call(build) - 1
    return nil if prev_index < 0
    branches[build.branch][prev_index]
  end

  retval = 0.0.seconds
  p = prev_build.call failures.first
  local_time = failures.first.created_at.in_time_zone(tz)
  day_start = local_time.midnight
  day_end = (local_time + 1.day).midnight
  if p.present? && p.summary_status == :failed
    retval += (local_time - day_start).seconds
  end
  failures.each do |fail|
    n = next_build.call fail
    n_local_time = n.created_at.in_time_zone(tz)
    local_time = fail.created_at.in_time_zone(tz)
    interval = (n_local_time - local_time).seconds
    # binding.pry
    retval += interval
  end
  retval
end

report = load_report
grouped = group_builds report
week = select_week grouped
stats = make_statistics week, report, MyTZ
# month_time_red = time_red(report.group_by_branch['master'].select{|build| build.summary_status == :failed}, report, MyTZ)
binding.pry
