module JsonapiCompliable
  class SingleResourceProxy < ResourceProxy
    def data
      record = to_a[0]
      raise JsonapiCompliable::Errors::RecordNotFound unless record
      record
    end

    def record
      data
    end
  end
end
