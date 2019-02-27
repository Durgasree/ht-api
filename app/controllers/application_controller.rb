class AccessDeniedError < StandardError
end

class NotAuthenticatedError < StandardError
end

class AuthenticationTimeoutError < StandardError
end

class ApplicationController < ActionController::API

  require 'auth_token'

  attr_reader :current_user

  # When an error occurs, respond with the proper private method below
  rescue_from AuthenticationTimeoutError, with: :authentication_timeout
  rescue_from NotAuthenticatedError, with: :user_not_authenticated
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  rescue_from RuntimeError do |exception|
     internal_server_error(exception)
  end

  rescue_from NoMethodError do |exception|
    internal_server_error(exception)
  end

  rescue_from RangeError, with: :range_error

  rescue_from ActiveRecord::ConnectionTimeoutError do |exception|
    active_record_connection_timeout
  end



  protected


  # This method gets the current user based on the user_id included
  # in the Authorization header (json web token).
  #
  # Call this from child controllers in a before_action or from
  # within the action method itself
 def authenticate_request!
    # raise request.inspect
    #Rails.logger.info "Headers #{request.headers.inspect}"
    #Rails.logger.info "Device Id: #{request.headers["HTTP_AUTH_TOKEN"]}, Hello #{request.headers["HTTP_DEVICE_ID"]}"

     # puts request.headers["HTTP_AUTH_TOKEN"].inspect
     # puts request.headers["HTTP_DEVICE_TOKEN"].inspect


  if request.headers["HTTP_DEVICE_ID"].present?
    client_id = request.headers["HTTP_DEVICE_ID"]
    token = request.headers["HTTP_AUTH_TOKEN"]
    device_type = request.headers["HTTP_DEVICE_TYPE"]
    puts "--------------------------------------------------------------"
    # Rails.logger.info "#{request.headers["HTTP_AUTH_TOKEN"]}"
    refresh_token_hash = $redis.hgetall(token)
    Rails.logger.info"client_id==============#{client_id}"
    Rails.logger.info "token=================#{token}"
    Rails.logger.info "device_type===============#{device_type}"
    Rails.logger.info  "refresh_token_hash ===========#{refresh_token_hash}"

    if refresh_token_hash && client_id && device_type && refresh_token_hash["client_id"] == client_id && refresh_token_hash["device_type"] == device_type
      user = User.find_by_id(refresh_token_hash["user_id"])
      @current_user = user
      # role = user.role.name.downcase
      # user = { id: user.id, email: user.email, avatar: (user.photos.last.present? ? {url: user.photos.last.profile_medium_url,profile_url: user.photos.last.profile_thumb_url} : {url: "",profile_url: ""}),full_name: user.full_name,last_sign_in_at: user.last_sign_in_at }
      response_token = { :user => user, :role=> role }
      session[:response_token] = response_token
      return session[:response_token]
      # Rails.logger.info "mobile request==============#{device_type}====== #{Time.zone.now}===================================="
    else
      render json: { error: "Session expired!" }
    end



    # if request.headers["HTTP_DEVICE_ID"].present?

    #   secret_token = SecretToken.where(token: request.headers["HTTP_AUTH_TOKEN"], client_id: request.headers["HTTP_DEVICE_ID"],device_type: request.headers["HTTP_DEVICE_TYPE"]).first
    #   if secret_token.present?
    #     user = secret_token.user
    #     @current_user = user
    #     response_token = { :success => true, :user => user, :role => user.user_role }
    #     session[:response_token] = response_token
    #   else
    #     render json: { error: "Session expired!" }
    #   end
    else

   Rails.logger.info "web request======================#{request.headers["HTTP_DEVICE_ID"]}======== #{Time.zone.now}=========================="
      begin
        puts request.headers["HTTP_REFRESH_TOKEN"]
      if request.headers["HTTP_REFRESH_TOKEN"].present?

        refresh_token = request.headers["HTTP_REFRESH_TOKEN"]
        client_id = request.headers["REMOTE_ADDR"]
        # puts "-------------------------------------------------#{request.headers["HTTP_REFRESH_TOKEN"]}-------------"
        secret_token = $redis.hgetall(request.headers["HTTP_REFRESH_TOKEN"])
        # secret_token = SecretToken.where(token: refresh_token, client_id: client_id).first
         puts secret_token.inspect


        if secret_token.present?
         # user = secret_token.user

         user = User.find_by_id(secret_token["user_id"])
          refresh_token = Digest::MD5.hexdigest(Time.now.to_s + user.email)
          response_token = authentication_payload(user, refresh_token)
          $redis.del(request.headers["HTTP_REFRESH_TOKEN"])
          $redis.srem(user.id, request.headers["HTTP_REFRESH_TOKEN"])
          $redis.hmset(response_token[:refresh_token], "client_id", request.headers["REMOTE_ADDR"], "user_id", user.id,"device_type",
                        request.headers["HTTP_USER_AGENT"],"is_mobile", false)
          $redis.expire refresh_token, 1800
          $redis.sadd(user.id, refresh_token)
          $redis.hset(response_token[:auth_token].split(".").last, "client_id", request.headers["REMOTE_ADDR"])
          # secret_token.update token: refresh_token, client_id: request.headers["REMOTE_ADDR"], device_type: request.headers["HTTP_USER_AGENT"], is_mobile: false
          session[:response_token] = response_token
          @current_user = user
          session[:response_token]
        else
          render json: { error: "Session expired!" }
        end
      else
       @current_user = User.find(decoded_auth_token[:user_id])
       if @current_user.present? && !@current_user.active?
         render json: { error: "Session expired!" , message: "account is suspended" }
       else
        @current_user
       end

      end

       # fail NotAuthenticatedError unless user_id_included_in_auth_token?

      rescue JWT::ExpiredSignature
        $redis.hdel(request.headers["HTTP_AUTH_TOKEN"].split(".").last, "client_id")
        raise AuthenticationTimeoutError
      rescue JWT::VerificationError, JWT::DecodeError
        raise NotAuthenticatedError
      end
    end
  end

  private


  def internal_server_error(exception)
    puts "------------------------------------------------------------------------------------"
    Rails.logger.error "Exception #{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace
    error_logger = Logger.new('log/exceptions.log')
    error_logger.level = Logger::ERROR
    error_logger.error exception.backtrace
    error_logger.error("============================================================================================================================================================================\n")


    puts "------------------------------------------------------------------------------------"
    render json: {success: false, error: "Internal server error"}
    # return exception
  end

  def record_not_found
    render json: {success: false,error: "no record found"}
  end

  def active_record_connection_timeout
    Rails.logger.info "------------------------------ActiveRecord Time out issue Handler-------------------------"
    Rails.logger.info exception.backtrace
    Rails.logger.info "------------------------------ActiveRecord Time out issue Handler-------------------------"
    ActiveRecord::Base.clear_active_connections!
  end
  # Authentication Related Helper Methods
  # ------------------------------------------------------------
  def user_id_included_in_auth_token?
    http_auth_token && decoded_auth_token && decoded_auth_token[:user_id]
  end

  # Decode the authorization header token and return the payload
  def decoded_auth_token
    @decoded_auth_token ||= AuthToken.decode(http_auth_token)
  end

  # Raw Authorization Header token (json web token format)
  # JWT's are stored in the Authorization header using this format:
  # Bearer somerandomstring.encoded-payload.anotherrandomstring
  def http_auth_token

    @http_auth_token ||= if request.headers.present?
                           request.headers["HTTP_AUTH_TOKEN"]
                         end
  end

  # Helper Methods for responding to errors
  # ------------------------------------------------------------
  def authentication_timeout
    render json: {success: false, error: "Authentication token expired" }
  end

  def range_error
    render json: {success: false,error: "Given value is out of range"}
  end


  def forbidden_resource
    render json: {success: false, error: ['Not Authorized To Access Resource'] }, status: :forbidden
  end

  def user_not_authenticated
    render json: {success: false, error: 'Not Authenticated' }, status: :unauthorized
  end
  def mobile_request?
    request.headers["HTTP_DEVICE_ID"].present?
  end

  def authentication_payload(user, refresh_token)
    response = {auth_token: ::AuthToken.encode({ user_id: user.id }),user: user,refresh_token: refresh_token,success: true}
  end




end
