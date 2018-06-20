module JsonapiCompliable
  class Types
    MAP = {
      string: String,
      integer: Integer,
      float: Float,
      decimal: BigDecimal,
      date: Date,
      time: Time,
      boolean: [TrueClass, FalseClass],
      object: Hash, # todo: object structure
      array: Array, # todo: array of X
    }
  end
end
