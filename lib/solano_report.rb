require 'csv'
require 'active_support/all'

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

  def group_by_date(tz=TZInfo::Timezone.get("UTC"))
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
end