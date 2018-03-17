class Container
  extend Dry::Container::Mixin

  namespace 'repositories' do
    register('user') { User }
  end

  namespace 'schemes' do
    register('sign_up') { SignUpScheme }
  end

  namespace 'adapters' do
    register('bcrypt') { BcryptAdapter.new }
  end
end
