Yamboard::Application.routes.draw do

  #resources :boards
  resources :widgets

  root :to => "widgets#index"

end
