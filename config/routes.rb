require 'sidekiq/web'

class TeamConstraint
  def initialize
    @teams = Team::ALL + [nil]
  end

  def matches?(request)
    @teams.include? request.params[:team]
  end
end

Rails.application.routes.draw do
  namespace :external do
    get 'welcome/index'

    namespace :api, defaults: { format: :json } do
      namespace :v1 do
        resources :investors, only: [:index] do
          collection do
            get 'search'
          end
        end
      end
    end
  end

  root 'external/welcome#index'

  namespace :external do
    root 'welcome#index'
    get 'vcfinder', to: 'vc_finder#index'
  end

  namespace :internal do
    root 'welcome#index'

    devise_for :users, controllers: {omniauth_callbacks: "internal/users/omniauth_callbacks" }

    get 'team', to: 'welcome#select_team'
    get 'feedback', to: 'welcome#send_slack_feedback'
    get 'stats/show'

    scope "(:team)", constraints: TeamConstraint.new do
      resources :knowledges, only: [:index]
      resources :stats, only: [:index]
      get 'all', to: 'companies#all'
      get 'voting', to: 'companies#voting'
      resources :companies, only: [:index, :show] do
        resources :votes, only: [:show, :create, :new]
      end
    end

    namespace :api, defaults: { format: :json } do
      namespace :v1 do
        resources :events, only: [:show, :update] do
          member do
            post 'invalidate'
          end
        end

        scope "(:team)", constraints: TeamConstraint.new do
          resources :votes, only: [:index, :show]
          resources :companies, only: [:index, :show] do
            member do
              get 'voting_status'
              post 'allocate'
              post 'reject'
              post 'invalidate_crunchbase'
            end
            collection do
              get 'search'
            end
          end
        end
        resource :user, only: :show do
          get 'token'
          post 'toggle_active'
          post 'set_team'
        end
      end
    end
  end

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: '/emails'
  end

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web, at: '/sidekiq'
  end
end
