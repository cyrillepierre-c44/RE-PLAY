Rails.application.routes.draw do
  get "toys/index"
  get "toys/show"
  get "toys/new"
  get "toys/create"
  get "toys/edit"
  get "toys/update"
  get "toys/destroy"
  get "boxes/index"
  get "boxes/show"
  get "boxes/new"
  get "boxes/create"
  get "boxes/edit"
  get "boxes/update"
  get "boxes/destroy"
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
