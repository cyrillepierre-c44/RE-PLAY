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

  def cyrille_pierre
  end

  def marc_thomas
  end

  def loic_laplagne
  end
end
