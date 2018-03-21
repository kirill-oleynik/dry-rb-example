class SignUpInteraction
  include Dry::Transaction
  include Inject[
    scheme: 'schemes.sign_up',
    bcrypt: 'adapters.bcrypt',
    repository: 'repositories.user'
  ]

  step :validate
  step :hash_password
  step :persist

  def validate(params)
    result = scheme.call(params)

    if result.success?
      Success params
    else
      Failure [:invalid, result.errors]
    end
  end

  def hash_password(params)
    password_hash = bcrypt.encode(params[:password])

    Success params.merge(password_hash: password_hash)
  end

  def persist(params)
    user = repository.create!(params)

    Success user
  rescue ActiveRecord::RecordNotUnique
    Failure [:invalid, email: [I18n.t('errors.not_unique')]]
  end
end
