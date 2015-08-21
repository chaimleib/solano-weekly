require 'csv'

class SolanoReport < Array
  class Converter
    def self._date_time(v)
      DateTime.parse v
    end

    def self._int(v)
      v.to_i
    end

    def self._float(v)
      v.to_f
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
      duration: :_float,
      worker_time: :_float,
      bundle_time: :_float,
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

  def initialize(path)
    init_from_csv(path)
  end

  def init_from_csv(path)
    builds = CSV.read(path)
    keys = builds.shift.map &:to_sym  # first line is column labels

    @raw_build_t = Struct.new("RawSolanoBuild", *keys)  # raw string values
    keys.unshift :_raw
    @build_t = Struct.new("SolanoBuild", *keys)         # rich values
    
    builds.each{ |b| _add_build(b) }
  end

  def _add_build(b)
    # convert b into rich values, and push onto end of self
    keys = @build_t.members
    kv_pairs = keys.zip [b, *b]  # [raw data, data to be converted]
    converted = kv_pairs.map{|k, v| 
      if k == :_raw
        @raw_build_t.new(*v)
      else
        Converter.convert(k, v)
      end
    }
    self << @build_t.new(*converted)
  end
end