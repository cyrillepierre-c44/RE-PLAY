class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]
  def home
  end

 def onboarding
  render plain: "test"
  end
end
