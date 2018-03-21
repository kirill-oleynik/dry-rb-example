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

    context 'when value is missing' do
      let(:params) { valid_params.merge(first_name: nil) }

      it 'is invalid' do
        expect(subject.success?).to be_falsey
      end
    end

    context 'when value is not a string' do
      let(:params) { valid_params.merge(first_name: 1234) }

      it 'is invalid' do
        expect(subject.success?).to be_falsey
      end
    end

    context 'when value is an empty string' do
      let(:params) { valid_params.merge(first_name: '') }

      it 'is invalid' do
        expect(subject.success?).to be_falsey
      end
    end
  end

  # ... expectations for last_name, password, password_confirmation, email
end
