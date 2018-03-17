# Dry-rb usage example

* [Problem description](#problem-description)
* [The Example](#the-example)
* [Requests handling](#requests-handling)
* [Interactions](#interactions)
* [Validations](#validations)
* [Dependency Management](#dependency-management)
* [Building the response](#building-the-response)
* [Testing](#testing)

## Problem description
The frequent problem is to define the composition of objects each with it’s own single responsibility and keep it as a pattern for each request-response iteration.

As application grows it may lead to a problem that you are forced to figure out all the steps that current iteration does.
And you often have a question “what the hell is the responsibility of this object?”.

So let’s take a look at example of such template build with [dry-rb](0) gems.
___

## The Example
As an example we’ll develop a feature that exists at most of applications - sign up.

There are 5 steps to be implemented:
1. Receive the request and decide what object should take care about data processing.
2. Validate received parameters
3. Prepare all necessary data for new user
4. Create user
5. Respond with new user's attributes or possible error
___

## Requests handling
We want our controllers to be skinny and have as little responsibility as possible.
So that each one of them will know:

* what object should be called to process the request
* what attributes should be used for successful response

We'll call all objects, that know how to handle the request `Interactions`.
They will be responsible for interaction algorithms.
And they will always return the same type of result.
It can be successful with requested data or failure with error description.

So our `UsersController` will look like:

```ruby
# app/controllers/users_controller.rb

class UsersController < ApiController
  def create
    result = SignUpInteraction.new.call(create_params)
    # ... response construction
  end

  private

  def create_params
    params.permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
```

Each interaction will be a `Dry::Transaction` object which describes series of operations where any can fail and stop the processing.
It will return the result as a `Dry::Monads::Result` object which can be either successful or failure.

---

## Interactions

In order to use them we'll need to install two gems: [dry-monads](1) and [dry-transaction](2).

```ruby
# Gemfile

gem 'dry-transaction'
gem 'dry-monads'
```

The only interface of an transaction is `call`.
It will call all steps one by one in their declaration order.
The first step will receive params that were passed to `call`.
The output of each step is a `Result` object (either a `Success` or `Failure`).
And the input for each next step is the output of previous.

To handle steps mentioned above our `SignUpInteraction` will look like:

```ruby
# app/interactions/sign_up_interaction.rb

class SignUpInteraction
  include Dry::Transaction

  step :validate
  step :hash_password
  step :persist

  def validate(params)
    # validate params
  end

  def hash_password(params)
    # create hash password
  end

  def persist(params)
    # create user
  end
end
```

And now we'll go through each step and fill this object.

---

## Validations

Unlike other, well known, validation solutions in Ruby, [dry-validation](3) takes a different approach and focuses a lot on explicitness, clarity and precision of validation logic.
It is based on the idea that each validation is encapsulated by a simple, stateless predicate that receives some input and returns either `true` or `false`.

```ruby
# Gemfile

gem 'dry-validation'
# ... other gems
```

Our `SignUpScheme` will take all arguments that were passed to `SignUpInteraction`, validate them and return boolean result.

As you could see at `UsersController` we expects client to send 'first_name', 'last_name', 'email', 'password' and 'password_confirmation'.
And we have next requirements for them:
* all attributes must be present
* all attributes must be not empty strings
* email must have the appropriate format
* password must have at least 6 symbols

And here is object that describes and validates all these rules:

```ruby
# app/schemes/sign_up_sheme.rb

SignUpScheme = Dry::Validation.Schema do
  required(:first_name).filled(:str?)
  required(:last_name).filled(:str?)
  required(:email).filled(:str?, :email?)
  required(:password).filled(:str?, min_size?: 6).confirmation
end
```

The DSL is pretty declarative, so that you can understand what's going on here.
There are a lot of built in predicates and they will cover most of your needs.

Out of the box you don't have a predicate that validates email template.
So let's create the custom one.

```ruby
# lib/custom_predicates.rb

module CustomPredicates
  include Dry::Logic::Predicates

  predicate(:email?) do |value|
    email_regexp = /\A[^@]+@([^@\.]+\.)+[^@\.]+\z/

    value.match? email_regexp
  end
end
```

Predicate declaration can be done barely inside the scheme.
But we'll place it into `CustomPredicates` module so that it can be reused in other schemes.

To include all this module with predicates into all schemes we'll configure schemes initializer:

```ruby
# config/initializers/schemes.rb

Dry::Validation::Schema.config.predicates = CustomPredicates
```

One more thing that we may want to do is to configure error messages.
[dry-validation](3) comes with a set of pre-defined error messages for every built-in predicate.
So we can define only one message for our custom predicate and redefine one just for example.

```ruby
# config/initializers/schemes.rb

Dry::Validation::Schema.config.messages = :i18n
Dry::Validation::Schema.config.predicates = CustomPredicates
```

```yml
# config/locales/en.yml

en:
  errors:
    password_confirmation: must be equal to password
    email?: has wrong format
```

---

## Dependency Management

Once we're done with validation `SignUpScheme` we want to use it inside `SignUpInteraction`.
And the question is how to manage this dependency in most efficient way.

We'll use [dry-auto_inject](4) gem which works in tandem with [dry-container](5) for this purpose.
This combination allows you to make use of the dependency inversion principle.

```ruby
# Gemfile

gem 'dry-container'
gem 'dry-auto_inject'
# ... other gems
```

We'll define our single container in appropriate initializer...

```ruby
# config/initializers/container.rb

class Container
  extend Dry::Container::Mixin

  namespace 'schemes' do
    register('sign_up') { SignUpScheme }
  end
end
```

...and setup auto-injection mixin:

```ruby
# config/initializers/inject.rb

Inject = Dry::AutoInject(Container)
```

And that is the point when we are ready to inject necessary dependencies to `SignUpInteraction` object and implement the first step.

```ruby
# app/interactions/sign_up_interaction.rb

class SignUpInteraction
  include Dry::Transaction
  include Inject[
    scheme: 'schemes.sign_up'
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

  # ... other steps
end
```

The result object of validation scheme responds to `success?` message.
So we can easily decide what kind of result this step should return (`Success` || `Failure`).
To retrieve errors in case of invalid params we can simply send `errors` to results object.

The remaining two steps are designed to generate password_hash and create user.
So we also need to include two dependencies for that: **bcrypt adapter** and **users repository**.
It doesn't matter how how they do their job in the context of our topic.
So there is no need for their examples.

Here is our final `Container`:

```ruby
# config/initializers/container.rb

class Container
  extend Dry::Container::Mixin

  namespace 'repositories' do
    register('user') { UserRepository }
  end

  namespace 'schemes' do
    register('sign_up') { SignUpScheme }
  end

  namespace 'adapters' do
    register('bcrypt') { BcryptAdapter }
  end
end
```

All this dependencies can be injected and used in many different objects.
And once we'll want to swap out one of them it can be done by simply registering a different object within the container.

```ruby
# nd here comes the completed version of `SignUpInteraction` object

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
```

You can inject and use other transactions inside each step in cases when you want to reuse some code or just to encapsulate some algorithm.
It will be convenient to call them `Commands` (or some other name, but not `Interactions`).
So that you can semantically separate them and let all `Commands` always trust the input data.

---

## Building the response

We've said above that we want each controller to be as skinny as possible.
And the response construction is the point where we can do it.

The attributes of successful response is a specific thing that must be described in controller.
But we don't want to repeat the same declarations of similar failure responses in all actions of all controllers.

So let's design a `Responder` module which will provide a `respond_with` method.
So that in every action we can just pass the result of request processing and the attributes for successful response as an arguments to it.

The basic usage might look like:

```ruby
# app/controllers/api_controller.rb

class ApiController < ActionController::API
  include Responder
end
```

```ruby
# app/controllers/users_controller.rb

class UsersController < ApiController
  def create
    result = SignUpInteraction.new.call(create_params)
    respond_with(result, status: 201, serializer: UserSerializer)
  end

  # other stuff
end
```

And the `Responder` itself might look like:

```ruby
# lib/responder.rb

module Responder
  def respond_with(result, status: 200, **rest)
    # response construction
  end
end
```

Since each our **result** object is an instance of `Dry::Monads::Result`
we can use pattern matching here to decide what type of response should be constructed.

[dry-matcher](6) gem offers flexible, expressive pattern matching and provides out-of-the-box support for matching on [dry-monads](1) `Result` values.

```ruby
# Gemfile

gem 'dry-matcher'
# ... other gems
```

To build `InteractionMatcher` we need to create a series of **case** objects with their own matching and resolving logic.

The first one will be `success_case`.
It will match in case when given **result** is **successful**.
And the resolve logic is pretty simple: it will take the `value` of the result.

To understand the `failure_case` we need to remember how the `Failure` monad looks like:
```ruby
Failure [:invalid, email: [I18n.t('errors.not_unique')]]
```
We have an array where the first item is an error type.
And the second one is a hash with errors as keys and error messages as values.

So the `failure_case` matcher will take two arguments: the results object and the array of matching patterns.
It will verify that the result is failed and that given error type (`:invalid` in our case) matches to provided patterns.
If it matched it will resolve the hash of errors.

```ruby
# lib/interaction_matcher.rb

success_case = Dry::Matcher::Case.new(
  match: -> (result) { result.success? },
  resolve: -> (result) { result.value }
)

failure_case = Dry::Matcher::Case.new(
  match: -> (result, *patterns) {
    result.failure? && patterns.any? ? patterns.include?(result.value.first) : true
  },
  resolve: -> (result) { result.value.last }
)

InteractionMatcher = Dry::Matcher.new(
  success: success_case,
  failure: failure_case
)
```

To use `InteractionMatcher` we'll require it and call in our `Responder` object with given result:

```ruby
# lib/responder.rb

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
```

`Errors::UnprocessableEntity` object just adapts given errors to appropriate format. You can explore it at 'lib/errors/unprocessable_entity.rb'.
___

## Testing

Actually there is nothing special or unusual about testing any of described objects.

When testing scheme use just need to send it a `call` message with appropriate arguments. After that you can verify the result with `success?` message.

```ruby
# spec/schemes/sign_up_scheme_spec.rb

require 'rails_helper'

RSpec.describe 'SignUpScheme' do
  subject { SignUpScheme.call(params) }

  let(:valid_params) { attributes_for(:user) }

  describe 'first_name validation' do
    context 'when value is not given' do
      let(:params) { valid_params.except(:first_name) }

      it 'is invalid' do
        expect(subject.success?).to be_falsey
      end
    end
  end

  # ... other expectations
end
```

To test transaction object with injected dependencies you just need create new instance and give it a hash with all required mocks as a single argument. After that you can `call` it with test params.

```ruby
# spec/interactions/sign_up_interaction_spec.rb

require 'rails_helper'

RSpec.describe SignUpInteraction do
  subject do
    SignUpInteraction.new(
      scheme: scheme,
      bcrypt: bcrypt,
      repository: repository
    )
  end

  let(:params) { attributes_for(:user) }
  let(:scheme_result) { double('scheme_result', success?: true) }
  let(:scheme) { -> (_) { scheme_result } }
  let(:bcrypt) { double('bcrypt', encode: 'hashed_password') }

  let(:repository) do
    mock = double('repository')

    def mock.create!(attributes)
      User.new(attributes)
    end

    mock
  end

  describe 'when transaction was successful' do
    it 'is returns success result with created user' do
      result = subject.call(params)

      expect(result).to be_right
      expect(result.value.first_name).to eq(params[:first_name])
      expect(result.value.last_name).to eq(params[:last_name])
      expect(result.value.email).to eq(params[:email])
      expect(result.value.password_hash).to eq('hashed_password')
    end
  end

  # ... other expectations
end
```

The End.

<!-- Links -->
[0]: http://dry-rb.org/
[1]: http://dry-rb.org/gems/dry-monads/
[2]: http://dry-rb.org/gems/dry-transaction/
[3]: http://dry-rb.org/gems/dry-validation/
[4]: http://dry-rb.org/gems/dry-auto_inject/
[5]: http://dry-rb.org/gems/dry-container/
[6]: http://dry-rb.org/gems/dry-matcher/
