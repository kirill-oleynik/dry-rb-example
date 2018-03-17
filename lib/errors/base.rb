module Errors
  class Base
    def error
      @error ||= {
        title: title,
        message: message
      }
    end

    def to_json
      { error: error }.to_json
    end
  end
end
