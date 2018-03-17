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

  describe 'when validation failed' do
    let(:scheme_result) do
      double('scheme_result', success?: false, errors: 'Ooops!')
    end

    it 'is returns failure result with validation error tuple' do
      result = subject.call(params)

      expect(result).to be_left
      expect(result.value[0]).to eq(:invalid)
      expect(result.value[1]).to eq('Ooops!')
    end
  end

  describe 'when email already taken' do
    let(:repository) do
      mock = double('repository')

      expect(mock).to receive(:create!).and_raise(
        ActiveRecord::RecordNotUnique
      ).once

      mock
    end

    it 'is returns failure result with validation error tuple' do
      result = subject.call(params)

      expect(result).to be_left
      expect(result.value[0]).to eq(:invalid)
      expect(result.value[1][:email]).to eq([I18n.t('errors.not_unique')])
    end
  end
end
