Aristotle::Engine.routes.draw do

	resources :reports, only: [:show] do
		get :readme, on: :member
	end

end
