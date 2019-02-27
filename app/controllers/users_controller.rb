class UsersController < ApplicationController

	before_action :response_token

	def response_token
    response_token = session[:response_token] || {}
  end

	def sign_in
		if params[:email].present? && params[:password].present?
			@user = User.find_by_email(params[:email].downcase)
			if @user.present? && @user.valid_password?(params[:password])
				if @user.confirmed_at.present?
					response = create_tokens
					render json: response
				else
					render json: { success: false, error: 'Please confirm your account' }
				end
			else
				render json: { success: false, error: 'Invalid username or password' }
			end
		else
			render json: {success: false, error: "Required parameters are email and password"}
		end
	end


	def sign_up
		@user = User.new(email: params[:email],password: params[:password],first_name: params[:first_name],last_name: params[:last_name],phone: params[:phone])
		if @user.save
			response = create_tokens
			render :json => {:success => true, :user => @user}.merge!(response)
		else
			render json: {success: false,error: @user.errors.full_messages.first}
		end
	end

	def sign_out
    if request.headers["HTTP_AUTH_TOKEN"].present? || params[:refresh_token].present?
      device_token = request.headers["HTTP_DEVICE_TOKEN"]
      if request.headers["HTTP_AUTH_TOKEN"].present?
        token=request.headers["HTTP_AUTH_TOKEN"]
      else
        token = params[:refresh_token]
      end
      refresh_token = $redis.hgetall(token)
      user = User.find_by_id(refresh_token["user_id"]) if refresh_token.present?
      if user.nil?
        render :json=> {:success => false, :error => "Authentication failed!! "}
      else
        $redis.srem(user.id,token)
        $redis.hdel(token)
        render :json=> {:success=>true, :message => "Signed out successfully" }
      end
    else
      render json: {success: false,error: "auth token or refresh token must be present"}
    end
	end


	private

  def create_tokens
    headers = request.headers
    refresh_token = Digest::MD5.hexdigest(Time.now.to_s + @user.email)
    if headers["HTTP_DEVICE_ID"].present?
      client_id = headers["HTTP_DEVICE_ID"]
      $redis.sadd(@user.id, refresh_token)
      token = headers["HTTP_DEVICE_TOKEN"]
      $redis.hmset(refresh_token,"user_id", @user.id , "client_id", client_id, "device_type", headers["HTTP_DEVICE_TYPE"], "device_token", headers["HTTP_DEVICE_TOKEN"], "is_mobile", true)
      avatar = @user.photos.last.present? ? {url: @user.photos.last.profile_medium_url, profile_url: @user.photos.last.profile_thumb_url} : {url: "", profile_url: ""}
      response = { success: true, auth_token: refresh_token, user: {first_name: @user.first_name, last_name: @user.last_name, role_id: @user.role_id, avatar: avatar }}
    else
      client_id = request.headers["REMOTE_ADDR"]
      $redis.sadd(@user.id, refresh_token)
      $redis.hmset(refresh_token, "user_id", @user.id , "client_id", client_id,"is_mobile", false)
      $redis.expire refresh_token, 1800
      payload = authentication_payload(@user, refresh_token)
      $redis.hset(payload[:auth_token].split(".").last, "client_id", client_id)
      response = {success: true}.merge!(payload)
    end
  end





end
