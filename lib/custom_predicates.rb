module CustomPredicates
  include Dry::Logic::Predicates

  predicate(:email?) { |value| value.match? URI::MailTo::EMAIL_REGEXP }
end
