Rails.application.routes.draw do
  resources :hosts
  get '/compact-hosts' => 'hosts#compact'
  
  get '/issues' => 'issues#index'
  post '/issues-accept' => 'issues#accept'
  
  delete '/ports/:id' => 'ports#destroy', :as => 'port'
  
  get '/dashboard' => 'dashboard#index'
  
  root 'dashboard#index'
end
