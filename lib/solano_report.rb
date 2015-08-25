require 'csv'
require 'active_support/all'

UTC = TZInfo::Timezone.get("UTC")

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
      created_at + duration.seconds
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
    self
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

  def group_by_date(tz=UTC)
    each_with_object({}){ |build, retval|
      utc = build.created_at.utc
      local = utc.in_time_zone(tz)
      key = local.midnight.iso8601
      if !retval.has_key? key
        retval[key] = self.class.new
      end
      retval[key] << build
    }
  end

  def group_by_branch
    each_with_object({}){ |build, retval|
      m = build.branch
      if !retval.has_key? m
        retval[m] = self.class.new
      end
      retval[m] << build
    }
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

  def select_period(start:DateTime.now, duration: 1.day)
    start = start.utc
    stop = start + duration
    select do |build|
      utc = build.created_at.utc
      start <= utc && utc <= stop
    end
  end

  def daily_statistics(tz:UTC, start:nil, duration:nil)
    by_branch = group_by_branch
    by_date_by_branch = group_by_date(tz).each_with_object({}) do |(d, subreport), h|
      h[d] = subreport.group_by_branch
    end
    unfiltered = by_date_by_branch.each_with_object({}) do |(day, day_branches), stats|
      # day_branches: hash of SolanoReports by branch name
      dt = DateTime.parse(day)
      stats[dt] = day_branches.each_with_object({}) do |(branch, subreport), substats|
        failures = subreport.select{|build| build.summary_status == :failed}

        substats[branch] = {
          fail_count: failures.length,
          red_time: subreport.status_duration(
            status: :failed,
            parent: by_branch[branch],
            start: dt,
            duration: 1.day)
        }
      end
    end
    return unfiltered unless start.present?
    filtered = unfiltered.select{|dt, branches| start <= dt}
    return filtered unless duration.present?
    filtered = filtered.select{|dt, branches| dt < start + duration}
    filtered
  end

  def build_index(build)
    return nil unless build.present?
    index{|other_build| other_build.session_id == build.session_id}
  end

  def next_build(build)
    i = build_index(build)
    return nil if i.nil?
    self[i + 1]
  end

  def prev_build(build)
    i = build_index(build)
    return nil if i.nil? || i <= 0
    self[i - 1]
  end

  def status_duration(status: :failed, parent: [], start: nil, duration: nil)
    parent = self unless parent.present?
    focus = select{|build| build.summary_status == status}.sort_by(&:created_at)
    return 0.0.days if focus.empty?

    retval = 0.0.days
    if start.present?
      p = parent.prev_build focus.first
      utc = focus.first.created_at.utc
      start = start.utc
      stop = start + duration
      if p.present? && p.summary_status == status
        interval = (utc - start).days
        retval += interval
      end
    end
    focus.each do |build|
      n = next_build build
      if n.present?
        n_utc = n.created_at.utc
      elsif duration.present?
        n_utc = stop
      else
        break
      end

      utc = build.created_at.utc
      interval = (n_utc - utc).days
      retval += interval
    end
    retval
  end
end
