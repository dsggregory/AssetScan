Rails.application.routes.draw do
  resources :hosts
  get '/compact-hosts' => 'hosts#compact'
  
  get '/issues' => 'issues#index'
  post '/issues-accept' => 'issues#accept'
  
  get '/dashboard' => 'dashboard#index'
  
  root 'dashboard#index'
end
