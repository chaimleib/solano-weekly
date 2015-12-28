require 'csv'
require 'active_support/all'
require_relative './core_extensions/numeric'
require_relative './utils/time'
include Utils::Time

class SolanoReport < Array
  class Converter
    def self._date_time(v)
      DateTime.parse(v)
    end

    def self._time(v)
      Time.parse(v)
    end

    def self._int(v)
      v.to_i
    end

    def self._float(v)
      v.to_f
    end

    def self._seconds(v)
      v.to_f.seconds
    end

    def self._bool(v)
      !!v
    end

    def self._sym(v)
      v.to_sym
    end

    @@static_keys = {
      created_at: :_date_time,
      summary_status: :_sym,
      duration: :_seconds,
      worker_time: :_seconds,
      bundle_time: :_seconds,
      num_workers: :_int,
    }

    @@dynamic_keys = {
      /_count\z/ => :_int,
    }

    def self.convert(key, val)
      key = key.to_sym
      caster = @@static_keys[key]
      return send(caster, val) unless caster.nil?
      @@dynamic_keys.each{ |rgx, caster|
        return send(caster, val) if key =~ rgx
      }
      return val
    end
  end

  def self.members
    [
      :session_id,
      :qualified_session_name,
      :plan_step_index,
      :profile_name,
      :started_by,
      :created_at,
      :summary_status,
      :duration,
      :worker_time,
      :bundle_time,
      :num_workers,
      :branch,
      :commit_id,
      :started_tests_count,
      :passed_tests_count,
      :failed_tests_count,
      :pending_tests_count,
      :skipped_tests_count,
      :error_tests_count
    ]
  end
  
  RawSolanoBuild = Struct.new("RawSolanoBuild", *members)  # raw string values
  SolanoBuild = Struct.new("SolanoBuild", :_raw, *members) do # rich values
    def finished_at
      created_at + duration
    end

    def days(tz)
      utc = created_at.in_time_zone(UTC)
      midnight = utc.in_time_zone(tz).midnight
      rv = [midnight.iso8601]
      while (midnight += 1.day) < finished_at do
        rv << midnight.iso8601
      end
      rv
    end

    def include_time?(t)
      created_at <= t && t < finished_at
    end

    def overlaps_time_range?(start, stop)
      include_time?(start) ||
        include_time?(stop) ||
        (start <= created_at && created_at < stop)
    end
  end

  def load_csv(path)
    builds = CSV.read(path)
    keys = builds.shift.map &:to_sym  # first line is column labels
    if keys != self.class.members
      puts "Expected: #{self.class.members}"
      puts "Given: #{keys}"
      raise "Given CSV headings do not match expected!"
    end
    builds.each{ |b| _add_build(b) }
    self[0..-1] = self.sort_by(&:created_at)
  end

  def _add_build(b)
    # convert b into rich values, and push onto end of self
    kv_pairs = SolanoBuild.members.zip [b, *b]  # [raw data, data to be converted]
    converted = kv_pairs.map{|k, v| 
      if k == :_raw
        RawSolanoBuild.new(*v)
      else
        Converter.convert(k, v)
      end
    }
    self << SolanoBuild.new(*converted)
  end

  def summary(tz: UTC, start: nil, duration: nil)
    start = start.in_time_zone(tz)
    meta = {
      tz: tz,
      start: start,
      duration: duration,
    }

    by_branch = group_by_branch
    stats = by_branch.each_with_object({}) do |(branch, subreport), stats|
      stats[branch] = subreport._branch_daily_statistics(meta)
    end

    meta[:branches] = by_branch.keys.sort
    {
      summary: stats,
      meta: meta,
    }
  end

  def _branch_daily_statistics(tz: UTC, start: nil, duration: nil)
    # gives stats for one branch
    return {} if empty?
    unless self.branches.length == 1
      puts "Branches found: #{self.branches}"
      raise "_branch_daily_statistics only works on SolanoReports with one branch"
    end

    by_date = group_by_date(tz)
    all_days = by_date.each_with_object({}) do |(day, day_builds), stats|
      dt = day.in_time_zone(tz)
      stats[dt] = {
        fail_count: day_builds.failures.length,
        red_time: status_duration(status: :failed, start: dt, duration: 1.day)
      }
    end

    ## Date filtering
    return all_days unless start.present?
    filtered = all_days.select{|dt, branches| start <= dt}
    return filtered unless duration.present?
    filtered = filtered.select{|dt, branches| dt < start + duration}
    filtered
  end

  def fail_times(tz: UTC, start: nil, duration: nil)
    start = start.in_time_zone(tz)
    meta = {
      tz: tz,
      start: start,
      duration: duration,
    }

    by_branch = group_by_branch
    stats = by_branch.each_with_object({}) do |(branch, subreport), stats|
      stats[branch] = subreport._branch_fail_times(meta)
    end

    meta[:branches] = by_branch.keys.sort
    {
      fail_times: stats,
      meta: meta,
    }
  end

  def _branch_fail_times(tz: UTC, start: nil, duration: nil)
    start = start.in_time_zone(UTC)

    failures = with_status_during(start: start, duration: duration)
    return [] if failures.empty?

    retval = failures.map do |fail|
      duration = nil
      n = next_build fail

      if n.present?
        fail_start = fail.created_at.in_time_zone(UTC)
        fail_stop = n.created_at.in_time_zone(UTC)
        duration = (fail_stop - fail_start).seconds
      end

      {
        id: fail.session_id,
        start: fail.created_at.in_time_zone(tz),
        duration: duration
      }
    end
    retval
  end

  def build_index(build)
    # returns the position of the given build, or nil
    return nil unless build.present?
    index{|other_build| other_build.session_id == build.session_id}
  end

  def next_build(build)
    # returns the build after the one given, or nil
    i = build_index(build)
    return nil if i.nil?
    self[i + 1]
  end

  def prev_build(build)
    # returns the build previous to the one given, or nil
    i = build_index(build)
    return nil if i.nil? || i <= 0
    self[i - 1]
  end

  def first_build_after(dt)
    bsearch{|build|
      build.created_at.in_time_zone(UTC) >= dt.in_time_zone(UTC)
    }
  end

  def last_build_before(dt)
    reverse.bsearch{|build|
      build.created_at.in_time_zone(UTC) < dt.in_time_zone(UTC)
    }
  end


  def branches
    map(&:branch).uniq.sort
  end

  def group_by_date(tz=UTC)
    each_with_object({}) do |build, retval|
      build.days(tz).each do |day|
        retval[day] ||= self.class.new
        retval[day] << build
      end
    end
  end

  def group_by_branch
    each_with_object({}) do |build, retval|
      m = build.branch
      retval[m] ||= self.class.new
      retval[m] << build
    end
  end

  def sort(*args, **kwargs)
    self.class.new super
  end

  def sort_by(*args, **kwargs)
    self.class.new super(*args, *kwargs)
  end

  def select(*args, **kwargs, &block)
    self.class.new super(*args, *kwargs, &block)
  end

  def failures
    select{|build| build.summary_status == :failed}
  end

  def select_period(start:DateTime.now, duration: 1.day)
    start = start.in_time_zone(UTC)
    stop = start + duration
    select{ |build| build.overlaps_time_range?(start, stop) }
  end

  def status_duration(status: :failed, parent: [], start: nil, duration: nil)
    # how long the build was in the given state (in days)
    parent = self unless parent.present?
    focus = self.
      select{|build| build.summary_status == status}.
      select_period(start: start, duration: duration)
    return 0.0.days if focus.empty?

    retval = 0.0.seconds

    # if present, add the failure overlapping the start of the report period
    if start.present?
      p = parent.prev_build focus.first  # the build right before focus.first
      utc = focus.first.created_at.in_time_zone(UTC)
      start = start.in_time_zone(UTC)
      stop = start + duration
      if p.present? && p.summary_status == status
        interval = (utc - start).seconds
        retval += interval
      end
    end

    # add other failures that were created in the report period
    focus.each do |build|
      n = parent.next_build build  # the next build
      if n.present?
        n_utc = n.created_at.in_time_zone(UTC)
        n_utc = stop if duration.present? && stop <= n_utc
      elsif duration.present?
        n_utc = stop
      else
        break
      end

      utc = build.created_at.in_time_zone(UTC)
      interval = (n_utc - utc).seconds
      retval += interval
    end

    retval = (retval/86400.0.seconds).days
  end

  def with_status_during(status: :failed, parent: [], start: nil, duration: nil)
    # return all builds that had the given status in the specified interval
    start = start.in_time_zone(UTC)
    parent = self unless parent.present?

    focus = self.class.new
    pre = last_build_before start if start.present?
    focus << pre if pre.present? and pre.summary_status == status

    focus += self.
      select{|build| build.summary_status == status}.
      select_period(start: start, duration: duration)

    return focus
  end

end
