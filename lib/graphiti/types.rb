module Graphiti
  class Types
    def self.create(primitive, &blk)
      definition = Dry::Types::Definition.new(primitive)
      definition.constructor(&blk)
    end

    WriteDateTime = create(::DateTime) do |input|
      if input.is_a?(::Date) || input.is_a?(::Time)
        input = if input.respond_to?(:to_datetime)
                  input.to_datetime
                else
                  ::DateTime.parse(input.to_s)
                end
      end
      input = Dry::Types['json.date_time'][input]
      Dry::Types['strict.date_time'][input] if input
    end

    ReadDateTime = create(::DateTime) do |input|
      if input.is_a?(::Date) || input.is_a?(::Time)
        input = if input.respond_to?(:to_datetime)
                  input.to_datetime
                else
                  ::DateTime.parse(input.to_s)
                end
      end
      input = Dry::Types['json.date_time'][input]
      Dry::Types['strict.date_time'][input].iso8601 if input
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
      Dry::Types['strict.bool'][input] unless input.nil?
    end

    PresentBool = create(nil) do |input|
      input = Dry::Types['params.bool'][input]
      Dry::Types['strict.bool'][input]
    end

    Integer = create(::Integer) do |input|
      Dry::Types['coercible.integer'][input] unless input.blank?
    end

    # The Float() check here is to ensure we have a number
    # Otherwise BigDecimal('foo') *will return a decimal*
    ParamDecimal = create(::BigDecimal) do |input|
      unless input.blank?
        Float(input)
        input = Dry::Types['coercible.decimal'][input]
        Dry::Types['strict.decimal'][input]
      end
    end

    PresentInteger = create(::Integer) do |input|
      Dry::Types['coercible.integer'][input] unless input.blank?
    end

    Float = create(::Float) do |input|
      Dry::Types['coercible.float'][input] unless input.blank?
    end

    PresentParamsHash = create(::Hash) do |input|
      input = JSON.parse(input) if input.is_a?(String)
      Dry::Types['params.hash'][input]
    end

    REQUIRED_KEYS = [:params, :read, :write, :kind, :description]

    def self.map
      @map ||= begin
        hash = {
          integer_id: {
            canonical_name: :integer,
            params: Dry::Types['coercible.integer'],
            read: Dry::Types['coercible.string'],
            write: Dry::Types['coercible.integer'],
            kind: 'scalar',
            description: 'Base Type. Query/persist as integer, render as string.'
          },
          uuid: {
            params: Dry::Types['coercible.string'],
            read: Dry::Types['coercible.string'],
            write: Dry::Types['coercible.string'],
            kind: 'scalar',
            description: 'Base Type. Like a normal string, but by default only eq/!eq and case-sensitive.'
          },
          string: {
            params: Dry::Types['coercible.string'],
            read: Dry::Types['coercible.string'],
            write: Dry::Types['coercible.string'],
            kind: 'scalar',
            description: 'Base Type.'
          },
          integer: {
            params: PresentInteger,
            read: Integer,
            write: Integer,
            kind: 'scalar',
            description: 'Base Type.'
          },
          big_decimal: {
            params: ParamDecimal,
            read: Dry::Types['json.decimal'],
            write: Dry::Types['json.decimal'],
            kind: 'scalar',
            description: 'Base Type.'
          },
          float: {
            params: Dry::Types['coercible.float'],
            read: Float,
            write: Float,
            kind: 'scalar',
            description: 'Base Type.'
          },
          boolean: {
            params: PresentBool,
            read: Bool,
            write: Bool,
            kind: 'scalar',
            description: 'Base Type.'
          },
          date: {
            params: PresentDate,
            read: Date,
            write: Date,
            kind: 'scalar',
            description: 'Base Type.'
          },
          datetime: {
            params: PresentParamsDateTime,
            read: ReadDateTime,
            write: WriteDateTime,
            kind: 'scalar',
            description: 'Base Type.'
          },
          hash: {
            params: PresentParamsHash,
            read: Dry::Types['strict.hash'],
            write: Dry::Types['strict.hash'],
            kind: 'record',
            description: 'Base Type.'
          },
          array: {
            params: Dry::Types['strict.array'],
            read: Dry::Types['strict.array'],
            write: Dry::Types['strict.array'],
            kind: 'array',
            description: 'Base Type.'
          }
        }

        hash.each_pair do |k, v|
          hash[k][:canonical_name] ||= k
        end

        arrays = {}
        hash.each_pair do |name, map|
          next if [:boolean, :hash, :array].include?(name)

          arrays[:"array_of_#{name.to_s.pluralize}"] = {
            canonical_name: name,
            params: Dry::Types['strict.array'].of(map[:params]),
            read: Dry::Types['strict.array'].of(map[:read]),
            test: Dry::Types['strict.array'].of(map[:test]),
            write: Dry::Types['strict.array'].of(map[:write]),
            kind: 'array',
            description: 'Base Type.'
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
      unless value.is_a?(Hash) && (REQUIRED_KEYS - value.keys).length.zero?
        raise Errors::InvalidType.new(key, value)
      end
      map[key.to_sym] = value
    end

    def self.name_for(key)
      key = key.to_sym
      type = map[key]
      type[:canonical_name]
    end
  end
end
