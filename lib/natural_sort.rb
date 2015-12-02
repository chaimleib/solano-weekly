module NaturalSort
  def self.cmp(a, b)
    return 1 if a > b
    return -1 if a < b
    0
  end

  # Regex group: $1   $2       $3
  Numeralizer = /(_)|([0-9]+)|([^0-9_]+)/
  Infinity = Float::INFINITY

  def self.natural_cmp(a, b)
    ax = []
    bx = []

    a.gsub(Numeralizer) do
      ax << [
        $1 || "z",                                # "z" sorts after "_"
        $2 && !$2.empty? && $2.to_i || Infinity,  # Infinity sorts after all
        $3 || ""                                  # "" sorts before all strings
      ]
    end
    b.gsub(Numeralizer) do
      bx << [
        $1 || "z",
        $2 && !$2.empty? && $2.to_i || Infinity,
        $3 || ""
      ]
    end
    while !ax.empty? && !bx.empty?  do
      an = ax.shift
      bn = bx.shift
      nn = cmp an[0], bn[0]
      nn = an[1] - bn[1] if nn.zero?
      nn = 0 if nn.is_a?(Float) && nn.nan?
      nn = cmp an[2], bn[2] if nn.zero?
      return nn unless nn.zero?
    end
    ax.length - bx.length
  end

  def self.natural_sort(l)
    l.sort{|a, b| natural_cmp(a, b)}
  end

  def self.version_cmp(a, b)
    ax = []
    bx = []

    a.gsub(Numeralizer) do
      ax << [$1 || $3, $2 && $2.to_i]
    end
    b.gsub(Numeralizer) do
      bx << [$1 || $3, $2 && $2.to_i]
    end
    while !ax.empty? && !bx.empty?  do
      an = ax.shift
      bn = bx.shift

      nn = case [an[0].nil?, bn[0].nil?]
      when [true, false]
        1
      when [false, true]
        -1
      when [false, false]
        cmp an[0], bn[0]
      else
        cmp an[1], bn[1]
      end
      return nn unless nn.zero?
    end
    ax.length - bx.length
  end

  def self.version_sort(l)
    l.sort{|a, b| version_cmp(a, b)}
  end
end
