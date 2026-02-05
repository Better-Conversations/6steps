Rails.application.routes.draw do
  # Devise authentication with custom controllers
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  # GDPR data export route
  get "users/export_data", to: "users/registrations#export_data", as: :export_user_data

  # Root and static pages
  root "pages#home"
  get "about", to: "pages#about"
  get "approach", to: "pages#approach"
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Authenticated user routes
  authenticate :user do
    get "dashboard", to: "dashboard#show"

    # Consent management
    resources :consents, only: [ :index, :create ] do
      collection do
        post :withdraw
      end
    end

    # Journey sessions
    resources :journey_sessions, only: [ :new, :create, :show, :update ] do
      member do
        post :respond
        post :pause
        post :resume
        post :complete
        get :export_pdf
      end
    end

    # Session history
    resources :session_history, only: [ :index, :show, :destroy ]

    # Crisis resources (accessible anytime)
    get "crisis_resources", to: "crisis_resources#show"
  end

  # Admin/Session reviewer routes
  namespace :admin do
    get "dashboard", to: "dashboard#show"
    resources :session_reviews, only: [ :index, :show ]
    resources :safety_metrics, only: [ :index ]

    # Legacy route redirects for bookmarked URLs
    get "clinical_reviews", to: redirect("/admin/session_reviews")
    get "clinical_reviews/:id", to: redirect("/admin/session_reviews/%{id}")

    # Invite management
    resources :invites, only: [ :index, :show, :new, :create, :destroy ] do
      member do
        post :revoke
      end
    end
  end
end
