success_case = Dry::Matcher::Case.new(
  match: -> (result) { result.success? },
  resolve: -> (result) { result.value }
)

failure_case = Dry::Matcher::Case.new(
  match: -> (result, *patterns) {
    result.failure? && patterns.any? 
      ? patterns.include?(result.value.first)
      : true
  },
  resolve: -> (result) { result.value.last }
)

InteractionMatcher = Dry::Matcher.new(
  success: success_case,
  failure: failure_case
)
