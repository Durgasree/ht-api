class HomeController < ApplicationController
	before_action :authenticate_request!
 	before_action :response_token

  def response_token
    response_token = session[:response_token] || {}
  end

  def index
  	if @current_user.present?
  		render json: {success: true,message: "User",user: @current_user}.merge!(response_token)
  	else
  		render json: {success: false,message: "No user present"}
  	end
  end

end
