class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_pundit_authorization

  def not_found
    render status: :not_found
  end

  def internal_server_error
    render status: :internal_server_error
  end
end
