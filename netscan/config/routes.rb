Rails.application.routes.draw do
  resources :hosts
  delete '/hosts/:id' => 'hosts#destroy', :as => 'delete_host'
  get '/compact-hosts' => 'hosts#compact'
  
  get '/issues' => 'issues#index'
  post '/issues-accept' => 'issues#accept'
  
  delete '/ports/:id' => 'ports#destroy', :as => 'delete_port'
  
  get '/dashboard' => 'dashboard#index'
  
  root 'dashboard#index'
end
