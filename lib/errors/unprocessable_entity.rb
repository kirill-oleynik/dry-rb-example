require_relative 'base'

module Errors
  class UnprocessableEntity < Base
    def initialize(schema_errors)
      add_violations(schema_errors)
    end

    private

    def title
      I18n.t('errors.titles.unprocessable_entity')
    end

    def message
      I18n.t('errors.messages.unprocessable_entity')
    end

    def add_violations(schema_errors)
      violations = schema_errors.each_with_object({}) do |(key, msgs), accum|
        accum[key] = msgs.map do |msg|
          "#{key.to_s.humanize.titleize} #{msg}"
        end
      end

      error[:violations] = violations
    end
  end
end
