# frozen_string_literal: true

Airview::Engine.routes.draw do
  root to: "resources#index"

  get "/setup", to: "setup#index", as: :setup
  get "/setup/resources/new", to: "setup#new", as: :new_setup_resource
  post "/setup/resources", to: "setup#create", as: :setup_resources
  get "/setup/resources/:id/edit", to: "setup#edit", as: :edit_setup_resource
  patch "/setup/resources/:id", to: "setup#update", as: :setup_resource
  delete "/setup/resources/:id", to: "setup#destroy"

  get "/resources", to: "resources#index", as: :resources
  get "/resources/:key", to: "resources#show", as: :resource
  post "/resources/:key/records", to: "resources#create", as: :resource_records
  patch "/resources/:key/records/:id", to: "resources#update", as: :resource_record
  delete "/resources/:key/records/:id", to: "resources#destroy"
  get "/resources/:key/references/:field", to: "resources#references", as: :resource_references
  post "/resources/:key/views", to: "views#create", as: :resource_views
  delete "/resources/:key/views/:id", to: "views#destroy", as: :resource_view
end
