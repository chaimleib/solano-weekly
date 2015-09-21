module NaturalSort
  def self.cmp(a, b)
    return 1 if a > b
    return -1 if a < b
    0
  end

  Numeralizer = /(_+)|([0-9]+)|([^0-9_]+)/
  Infinity = Float::INFINITY

  def self.natural_cmp(a, b)
    ax = []
    bx = []

    a.gsub(Numeralizer) do
      ax << [$1 || '', $2 && !$2.empty? && $2.to_i || Infinity, $3 || '']
    end
    b.gsub(Numeralizer) do
      bx << [$1 || '', $2 && !$2.empty? && $2.to_i || Infinity, $3 || '']
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
  
  # def self.version_cmp(a, b)
  #   ax = []
  #   bx = []

  #   a.gsub(Numeralizer) do
  #     ax << [$1 || '', $3 || '', $2 && !$2.empty? && $2.to_i || Infinity]
  #   end
  #   b.gsub(Numeralizer) do
  #     bx << [$1 || '', $3 || '', $2 && !$2.empty? && $2.to_i || Infinity]
  #   end
  #   while !ax.empty? && !bx.empty?  do
  #     an = ax.shift
  #     bn = bx.shift
  #     puts an.inspect
  #     puts bn.inspect
  #     nn = cmp an[0], bn[0]
  #     nn = cmp an[1], bn[1] if nn.zero?
  #     nn = an[2] - bn[2] if nn.zero?
  #     nn = 0 if nn.is_a?(Float) && nn.nan?
  #     puts nn
  #     return nn unless nn.zero?
  #   end
  #   ax.length - bx.length
  # end

  # def self.version_sort(l)
  #   l.sort{|a, b| version_cmp(a, b)}
  # end
end
