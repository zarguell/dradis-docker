Dradis::CE::API::Engine::routes.draw do
  scope path: :api do
    defaults format: 'json' do
      scope module: :v1, constraints: Dradis::CE::API::RoutingConstraints.new(version: 1) do
        resources :issues
        resources :nodes do
          resources :evidence
          resources :notes
          constraints(filename: /.*/) do
            resources :attachments, param: :filename
          end
        end
      end

      scope module: :v3, constraints: Dradis::CE::API::RoutingConstraints.new(version: 3, default: true) do
        resources :boards do
          resources :lists do
            resources :cards do
            end
          end
        end
        resources :issues
        resources :nodes do
          resources :evidence
          resources :notes
          constraints(filename: /.*/) do
            resources :attachments, param: :filename do
              get :download, on: :member
            end
          end
        end

        resources :uploads, only: [:show, :create], path: :upload
      end
    end
  end
end
