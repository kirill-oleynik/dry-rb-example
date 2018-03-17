module CustomPredicates
  include Dry::Logic::Predicates

  predicate(:email?) do |value|
    email_regexp = /\A[^@]+@([^@\.]+\.)+[^@\.]+\z/

    value.match? email_regexp
  end
end
