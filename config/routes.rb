Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  root "reports#index"

  resource :first_run, only: %i[ show create ]

  resource :session, only: %i[ new create destroy ] do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
    end
  end

  get "join/:join_code", to: "users#new", as: :join
  post "join/:join_code", to: "users#create"

  resource :account do
    scope module: "accounts" do
      resource :join_code, only: :create
      resource :custom_styles, only: %i[ edit update ]
    end
  end

  resources :reports, except: %i[ index show ] do
    resource :publication, controller: "reports/publications", only: %i[ show edit update ]
    resource :bookmark, controller: "reports/bookmarks", only: :show

    scope module: "reports" do
      namespace :sections do
        resources :moves, only: :create
      end

      resource :search
      resources :sources do
        resources :taggings, controller: "reports/sources/taggings", only: [:create, :destroy]
      end
    end

    resources :text_blocks
    resources :pictures
    resources :pages
    resources :documents
    resources :findings

    # Research references for sections
    resources :sections, only: [] do
      resources :references, only: [:index]
    end
  end

  get "/:id/:slug", to: "reports#show", constraints: { id: /\d+/ }, as: :slugged_report
  get "/:report_id/:report_slug/:id/:slug", to: "sectionables#show", constraints: { report_id: /\d+/, id: /\d+/ }, as: :slugged_sectionable

  direct :report_slug do |report, options|
    route_for :slugged_report, report, report.slug, options
  end

  direct :sectionable_slug do |section, options|
    route_for :slugged_sectionable, section.report, section.report.slug, section, section.slug, options
  end

  resources :pages, only: [] do
    scope module: "pages" do
      resources :edits, only: :show
    end
  end

  resources :suggestions, only: [] do
    member do
      patch :accept
      patch :reject
    end
  end

  resources :qr_code, only: :show
  resources :users do
    scope module: "users" do
      resource :profile
    end
  end

  direct :sectionable do |section, options|
    route_for "report_#{section.sectionable_name}", section.report, section, options
  end

  direct :edit_sectionable do |section, options|
    route_for "edit_report_#{section.sectionable_name}", section.report, section, options
  end

  namespace :action_text, path: nil do
    get "/u/*slug" => "markdown/uploads#show", as: :markdown_upload
    post "/uploads" => "markdown/uploads#create", as: :markdown_uploads
  end

  # AI Assistant Routes
  scope :assistants do
    # Single streaming endpoint for all writing actions
    post "stream" => "assistants#stream", as: :assistants_stream

    # Legacy non-streaming endpoints (kept for backwards compatibility)
    post "writing/improve" => "assistants#writing_improve"
    post "writing/grammar" => "assistants#writing_grammar"
    post "writing/style" => "assistants#writing_style"
    post "writing/summarize" => "assistants#writing_summarize"
    post "writing/expand" => "assistants#writing_expand"
    post "writing/brainstorm" => "assistants#writing_brainstorm"
    post "research" => "assistants#research"
    post "analyze_file" => "assistants#analyze_file"
    post "image/caption" => "assistants#image_caption"
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
