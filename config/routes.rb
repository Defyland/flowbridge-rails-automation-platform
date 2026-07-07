Rails.application.routes.draw do
  root "dashboard#index"

  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  get "up" => "platform#health"
  get "ready" => "platform#readiness"
  get "metrics" => "platform#metrics"

  namespace :operator do
    resources :workflows, only: %i[index show]
    resources :executions, only: %i[index show] do
      post :retry, on: :member
    end
    resources :dead_letters, only: %i[index show] do
      post :retry, on: :member
      post :resolve, on: :member
    end
  end

  namespace :api do
    namespace :v1 do
      resources :organizations, only: %i[create show]
      resources :credentials, only: %i[index show create]

      resources :workflows, only: %i[index show create] do
        resources :versions, controller: "workflow_versions", only: %i[index show create]
      end

      resources :executions, only: %i[index show] do
        post :retry, on: :member
      end

      resources :dead_letters, only: %i[index show] do
        post :retry, on: :member
        post :resolve, on: :member
      end

      post "serverless/webhooks/:trigger_key", to: "serverless_webhooks#create", as: :serverless_webhook
      post "webhooks/:trigger_key", to: "webhook_events#create", as: :webhook_event
    end
  end
end
