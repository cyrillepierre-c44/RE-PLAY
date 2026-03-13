Rails.application.routes.draw do
  devise_for :users
  root to: "pages#home"
  resources :boxes, only: [:index, :show, :new, :create, :edit, :update] do
    resources :toys, only: [:new, :create]
  end

  resources :boxes, only: [:destroy]
  resources :toys, only: [:index, :show, :destroy, :edit, :update] do
    member do
      get :verify
      patch :confirm_verify
    end
  end

  get "about_us", to: "pages#about_us"
  get "onboarding", to: "pages#onboarding"
  get "enjoue", to: "pages#enjoue"
  get "equipe/membre1", to: "pages#membre1"
  get "equipe/membre2", to: "pages#membre2"
  get "equipe/membre3", to: "pages#membre3"

end
