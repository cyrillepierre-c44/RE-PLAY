class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  def home
  end

  def about_us
    authorize :page, :about_us?
  end

  def onboarding
    authorize :page, :onboarding?
  end

  def enjoue
  end

  def membre1
  end

  def membre2
  end

  def membre3
  end
end
