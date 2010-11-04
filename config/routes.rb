Yamboard::Application.routes.draw do

  resources :panels

  resources :widgets

  root :to => "widget#index"
  get "widget/index"

end
