Yamboard::Application.routes.draw do

  resources :widgets

  root :to => "widget#index"
  get "widget/index"

end
