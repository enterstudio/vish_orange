Vish::Application.routes.draw do

  #Devise routes
  deviseControllers = {
    :omniauth_callbacks => "omniauth_callbacks",
    :registrations => "registrations",
    :sessions => "sessions",
    :passwords => "passwords"
  }
  deviseSkipControllers = []

  deviseControllers[:invitations] = "devise_invitations" if Vish::Application.config.invitations
  deviseControllers[:sessions] = "devise/cas_sessions" if Vish::Application.config.cas
  deviseSkipControllers = [:registrations].push(:registrations) if Vish::Application.config.register_policy == "INVITATION_ONLY"

  devise_for :users, :controllers => deviseControllers, :skip => deviseSkipControllers

  if Vish::Application.config.register_policy == "INVITATION_ONLY"
    as :user do
      get 'users/edit' => 'devise/registrations#edit', :as => 'edit_user_registration'
      put 'users' => 'devise/registrations#update', :as => 'user_registration'
    end
  end

  match 'users/:id/excursions' => 'users#excursions'
  match 'users/:id/workshops' => 'users#workshops'
  match 'users/:id/resources' => 'users#resources'
  match 'users/:id/events' => 'users#events'
  match 'users/:id/categories' => 'users#categories'
  match 'users/:id/followers' => 'users#followers'
  match 'users/:id/followings' => 'users#followings'
  match 'users/:id/edit_role' => 'users#edit_role'
  match 'users/:id/update_role' => 'users#update_role'
  match 'users/:id/profile' => 'users#show'

  resource :session_locale

  #redirect excursions index to home
  match '/excursions' => 'home#index', :constraints => { :format => 'html' }
  #Allow login for applications (i.e. ViSH Mobile) that uses the home.json.
  match '/home.json' => 'home#index', :format => :json

  match 'overview' => 'static#overview'
  match 'faq' => 'static#overview'
  match 'help' => 'static#overview'
  match 'legal_notice' => 'static#conditions_of_use'
  match 'privacy_policy' => 'static#privacy_policy'
  match 'conditions_of_use' => 'static#conditions_of_use'
  match 'teach' => 'static#teach'
  match 'learn' => 'static#learn'
  match 'train_yourself' => 'static#train_yourself'
  match 'train_students' => 'static#train_students'
  match 'download_perm_request' => 'static#download_perm_request'
  match 'user_manual' => 'static#download_user_manual'

  #APIs
  match '/apis/search' => 'federated_search#search'
  match '/apis/iframe_api' => 'excursions#iframe_api'
  match '/apis/recommender' => 'recommender#api_resource_suggestions'
  match '/apis/wapp_token/:auth_token' => 'wapp_auth_tokens#show'
  match '/apis/wapp_token' => 'wapp_auth_tokens#create'

  #Search
  match '/search/advanced' => 'search#advanced'
  #LRE proxy
  match 'lre/search' => 'lre#search_lre'

  #AO avatars
  match 'activity_objects/avatar/:id' => 'activity_object#show_avatar'

  #Thumbnails
  match '/thumbnails' => 'excursions#excursion_thumbnails'

  match 'excursions/last_slide' => 'excursions#last_slide'
  match 'excursions/preview' => 'excursions#preview'
  match 'excursions/interactions' => 'excursions#interactions'

  match 'excursions/:id/metadata' => 'excursions#metadata'
  match 'excursions/:id/scormMetadata' => 'excursions#scormMetadata'
  match 'excursions/:id/clone' => 'excursions#clone'
  match '/excursions/:id/evaluate' => 'excursions#evaluate'
  match '/excursions/attachments' => 'excursions#upload_attachment'
  match '/excursions/:id/attachment' => 'excursions#show_attachment'
  match '/excursions/:id/allow_publishing' => 'excursions#allow_publishing'

  match '/excursions/:id.mashme' => 'excursions#show', :defaults => { :format => "gateway", :gateway => 'mashme' }
  match '/excursions/:id.embed' => 'excursions#show', :defaults => { :format => "full" }

  #Download JSON
  match '/excursions/tmpJson' => 'excursions#uploadTmpJSON', :via => :post
  match '/excursions/tmpJson' => 'excursions#downloadTmpJSON', :via => :get

  resources :excursions

  #Workshops
  match '/workshops/:id/edit_details' => 'workshops#edit_details'
  match '/workshops/:id/contributions' => 'workshops#contributions'
  resources :workshops

  #Workshops Activities
  resources :wa_assignments, :except => [:index]
  resources :wa_resources, :except => [:index]
  resources :contributions, :except => [:index]
  match '/wa_resources_galleries/:id/add_resource' => 'wa_resources_galleries#add_resource'
  resources :wa_resources_galleries, :except => [:index]
  resources :wa_contributions_galleries, :except => [:index]
  resources :wa_texts, :except => [:index]

  #courses
  resources :courses do
    get 'attachment', :on => :member
    post 'join', :on => :member
    post 'leave', :on => :member
  end

  #Quiz Sessions
  resources :quiz_sessions do
    get "results", :on => :member
  end
  match 'quiz_sessions/:id/close' => 'quiz_sessions#close'
  match 'quiz_sessions/:id/delete' => 'quiz_sessions#delete'
  match 'quiz_sessions/:id/answer' => 'quiz_sessions#updateAnswers'
  match 'qs/:id' => 'quiz_sessions#show'

  #PDF to Excursion
  resources :pdfexes, :only => [:new, :create, :show]

  #Categories
  match '/categories/categorize' => 'categories#categorize', :via => :post
  match '/categories/edit_categories' => 'categories#edit_categories', :via => :post
  match '/categories/settings' => 'categories#settings', :via => :post
  match '/categories/favorites' => 'categories#show_favorites'

  #Catalogue
  match '/catalogue' => 'catalogue#index'

  #ServiceRequets
  resources :service_requests do
    get 'attachment', :on => :member
    get 'accept', :on => :member
  end
  namespace :service_request do
    resources :private_student_groups do
      get 'duplicated', :on => :collection
    end
  end

  #PrivateStudentGroups
  resources :private_student_groups do
    get 'credentials', :on => :member
  end

  match '/private_student_groups/:id/change_teacher_notifications' => 'private_student_groups#change_teacher_notifications', :via => :post
  match '/private_student_groups/notify_teacher' => 'private_student_groups#notify_teacher', :via => :post

  #service_permissions
  match 'service_permissions/update_permissions' => 'service_permissions#update_permissions', :via => :post

  #MaiL lists
  resources :mail_lists, :only => [:show] do
    get 'subscribe', :on => :member
    post 'subscribed', :on => :member
    get 'unsubscribe', :on => :member
    post 'unsubscribed', :on => :member
  end

  match "/contest/educa2" => redirect("/contest/educa2016")

  # Contests
  resources :contests do
    post 'enroll', :on => :member
    post 'disenroll', :on => :member
    get 'new_resource_submission', :on => :member
    post 'submit', :on => :member
    post 'remove_submit', :on => :member
  end
  match 'contest/:name' => 'contests#show'
  match 'contest/:name/page/:page' => 'contests#show'
  match 'contests/:id/page/:page' => 'contests#show'
  match 'contest/:name/educa2016materials' => 'contests#educa2016materials', via: [:post]

  #Administration panel
  match 'admin' => 'admin#index'
  match 'admin/closed_reports' => 'admin#closed_reports'
  match 'admin/users' => 'admin#users'
  match 'admin/requests' => 'admin#requests'

  #Spam reports
  resources :spam_reports
  match 'spam_reports/:id/open' => 'spam_reports#open'
  match 'spam_reports/:id/close' => 'spam_reports#close'

  # Shorten URLs
  # Add this at the end so other URLs take prio
  match '/s/:id' => "shortener/shortened_urls#show"

  #ViSHRS evaluation
  match '/rsevaluation', to: 'rsevaluation#start', via: [:get]
  match '/rsevaluation/step/:step', to: 'rsevaluation#step', via: [:post]

  # for OAI-MPH
  mount OaiRepository::Engine => "/oai_repository"

  #LOEP
  namespace :loep do
    resources :los
    resources :session_token, :only => [:index, :create]
  end

  #Tracking System
  resources :tracking_system_entries

end
