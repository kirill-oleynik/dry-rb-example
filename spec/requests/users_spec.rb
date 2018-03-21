require 'rails_helper'

RSpec.describe 'Users requests' do
  let(:user) { create(:user) }

  describe '#create' do
    let(:params) { attributes_for(:user) }

    context 'with valid params' do
      it 'creates user', :with_db_cleaner do
        expect(users_count).to eq(0)

        post users_path, params: params

        expect(response).to have_http_status(201)
        expect(response.body).to match_response_schema('user')
        expect(users_count).to eq(1)
      end
    end

    context 'when params invalid' do
      let(:params) { attributes_for(:user).merge(email: nil) }

      it 'returns validation errors', :with_db_cleaner do
        post users_path, params: params

        expect(response).to have_http_status(422)
        expect(response.body).to match_response_schema('errors/validation')
        expect(users_count).to eq(0)
      end
    end

    context 'when email already taken' do
      it 'returns validation errors', :with_db_cleaner do
        expect(users_count).to eq(0)

        2.times { post users_path, params: params }

        expect(response).to have_http_status(422)
        expect(response.body).to match_response_schema('errors/validation')
        expect(users_count).to eq(1)
      end
    end
  end

  def users_count
    User.count
  end
end
