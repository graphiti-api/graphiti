module JsonapiCompliable
  class Types
    def self.create(primitive, &blk)
      definition = Dry::Types::Definition.new(primitive)
      definition.constructor(&blk)
    end

    DateTime = create(::DateTime) do |input|
      if input.is_a?(::Date) || input.is_a?(::Time)
        input = ::DateTime.parse(input.to_s)
      end
      input = Dry::Types['json.date_time'][input]
      Dry::Types['strict.date_time'][input] if input
    end

    PresentParamsDateTime = create(::DateTime) do |input|
      input = Dry::Types['params.date_time'][input]
      Dry::Types['strict.date_time'][input]
    end

    Date = create(::Date) do |input|
      input = ::Date.parse(input.to_s) if input.is_a?(::Time)
      input = Dry::Types['json.date'][input]
      Dry::Types['strict.date'][input] if input
    end

    PresentDate = create(::Date) do |input|
      input = ::Date.parse(input.to_s) if input.is_a?(::Time)
      input = Dry::Types['json.date'][input]
      Dry::Types['strict.date'][input]
    end

    Bool = create(nil) do |input|
      input = Dry::Types['params.bool'][input]
      Dry::Types['strict.bool'][input] if input
    end

    PresentBool = create(nil) do |input|
      input = Dry::Types['params.bool'][input]
      Dry::Types['strict.bool'][input]
    end

    Integer = create(::Integer) do |input|
      Dry::Types['coercible.integer'][input] if input
    end

    # The Float() check here is to ensure we have a number
    # Otherwise BigDecimal('foo') *will return a decima;*
    ParamDecimal = create(::BigDecimal) do |input|
      Float(input)
      input = Dry::Types['coercible.decimal'][input]
      Dry::Types['strict.decimal'][input]
    end

    PresentInteger = create(::Integer) do |input|
      Dry::Types['coercible.integer'][input]
    end

    Float = create(::Float) do |input|
      Dry::Types['coercible.float'][input] if input
    end

    PresentParamsHash = create(::Hash) do |input|
      Dry::Types['params.hash'][input].deep_symbolize_keys
    end

    def self.map
      @map ||= begin
        hash = {
          string: {
            params: Dry::Types['coercible.string'],
            read: Dry::Types['coercible.string'],
            test: Dry::Types['strict.string'],
            write: Dry::Types['coercible.string']
          },
          integer: {
            params: PresentInteger,
            read: Integer,
            test: Dry::Types['strict.integer'],
            write: Integer
          },
          decimal: {
            params: ParamDecimal,
            read: Dry::Types['json.decimal'],
            test: Dry::Types['strict.string'],
            write: Dry::Types['json.decimal']
          },
          float: {
            params: Dry::Types['coercible.float'],
            read: Float,
            test: Dry::Types['strict.float'],
            write: Float
          },
          boolean: {
            params: PresentBool,
            read: Bool,
            test: Dry::Types['strict.bool'],
            write: Bool
          },
          date: {
            params: PresentDate,
            read: Date,
            test: Dry::Types['strict.string'],
            write: Date
          },
          datetime: {
            params: PresentParamsDateTime,
            read: DateTime,
            test: Dry::Types['strict.string'],
            write: DateTime
          },
          hash: {
            params: PresentParamsHash,
            read: Dry::Types['strict.hash'],
            test: Dry::Types['strict.hash'],
            write: Dry::Types['strict.hash']
          },
          array: {
            params: Dry::Types['strict.array'],
            read: Dry::Types['strict.array'],
            test: Dry::Types['strict.array'],
            write: Dry::Types['strict.array']
          }
        }

        arrays = {}
        hash.each_pair do |name, map|
          arrays[:"array_of_#{name.to_s.pluralize}"] = {
            params: Dry::Types['strict.array'].of(map[:params]),
            read: Dry::Types['strict.array'].of(map[:read]),
            test: Dry::Types['strict.array'].of(map[:test]),
            write: Dry::Types['strict.array'].of(map[:write])
          }
        end
        hash.merge!(arrays)

        hash
      end
    end

    def self.[](key)
      map[key.to_sym]
    end

    def self.[]=(key, value)
      unless value.is_a?(Hash)
        value = {
          read: value,
          params: value,
          test: value
        }
      end
      map[key.to_sym] = value
    end
  end
end
