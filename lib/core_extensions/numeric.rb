module CoreExtensions
  module Numeric
    def clamp(low, high)
      [low, [self, high].min].max
    end
  end
end

Numeric.include CoreExtensions::Numeric
