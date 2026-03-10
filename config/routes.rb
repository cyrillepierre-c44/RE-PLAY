Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  resources :boxes, only: [:index, :show, :new, :create, :edit, :update] do
    resources :toys, only: [:index, :show, :new, :create, :edit, :update]
  end

  resources :boxes, only: [:destroy]
  resources :toys, only: [:destroy]
  get "about_us", to: "pages#about_us"
  get "onboarding", to: "pages#onboarding"
end
