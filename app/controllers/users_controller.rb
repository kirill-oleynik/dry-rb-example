class UsersController < ApiController
  def create
    result = SignUpInteraction.new.call(create_params)
    respond_with(result, status: 201, serializer: UserSerializer)
  end

  private

  def create_params
    params.permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end
end
