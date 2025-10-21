Rails.application.routes.draw do
  # Devise authentication routes
  devise_for :users

  # Sidekiq Web UI (admin only)
  require 'sidekiq/web'
  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Main application route (serves React app)
  root "dashboard#react_index"
  
  # Dashboard routes
  get 'dashboard', to: 'dashboard#index'
  get 'react', to: 'dashboard#react_index'
  get 'test_notifications/:type', to: 'dashboard#test_notifications', as: 'test_notifications'
  
  # Main application resources
  resources :resumes do
    member do
      post :process_resume
      post :reprocess
      get :download
      patch :update_content
      # AI Processing routes
      post :process_ai
      get :ai_status
    end
  end

  resources :job_descriptions
  resources :resume_processings, only: [:index, :show]

  # Admin routes
    # Admin interface accessible via all.airesumeparser.com subdomain
  namespace :admin do
    get "dashboard/index"
    resources :tenants do
      member do
        patch :activate
        patch :pause
        get :stats
      end
    end
    resources :users, only: [:index, :show, :edit, :update]
    
    # Admin dashboard
    get 'dashboard', to: 'dashboard#index'
    root 'dashboard#index'
  end
  
  # Catch-all route for React Router (SPA routing) - exclude admin paths
  get '*path', to: 'dashboard#index', constraints: lambda { |req|
    !req.xhr? && req.format.html? && !req.path.start_with?('/admin')
  }
end
