Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }
  resources :users, only: [:index] do
    member do
      patch :disable
      patch :enable
    end
  end
  root to: "pages#home"
  resources :boxes, only: [:index, :show, :new, :create, :edit, :update] do
    resources :toys, only: [:new, :create]
    member do
      patch :toggle_empty
    end
  end

  resources :boxes, only: [:destroy]
  resources :toys, only: [:index, :show, :destroy, :edit, :update] do
    member do
      get :verify
      patch :confirm_verify
      patch :restore
    end
  end

  get "about_us", to: "pages#about_us"
  get "onboarding", to: "pages#onboarding"
  get "enjoue", to: "pages#enjoue"

  get "equipe/cyrille-pierre", to: "pages#cyrille_pierre", as: :cyrille_pierre
  get "equipe/marc-thomas", to: "pages#marc_thomas", as: :marc_thomas
  get "equipe/loic-laplagne", to: "pages#loic_laplagne", as: :loic_laplagne

  get "dashboard/export_csv", to: "pages#export_csv", as: :dashboard_export_csv
  get "dashboard", to: "pages#dashboard"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
