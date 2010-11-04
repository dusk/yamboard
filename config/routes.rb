Yamboard::Application.routes.draw do

  resources :panels
  resources :widgets

  root :to => "widgets#index"

end
