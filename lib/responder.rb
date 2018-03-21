require_relative 'interaction_matcher'
require_relative 'errors/unprocessable_entity'

module Responder
  def respond_with(result, status: 200, **rest)
    InteractionMatcher.call(result) do |result|
      result.success do |value|
        render(
          { json: value, root: 'data', status: status }.merge(rest)
        )
      end

      result.failure :invalid do |value|
        render status: 422,
               json: Errors::UnprocessableEntity.new(value).to_json
      end
    end
  end
end
