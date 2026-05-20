# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'

module SecureBiddingApp
  module RoutingHelpers
    def redirect_http_to_https
      return unless scheme == 'http'

      redirect url.sub(/^http:/, 'https:')
    end
  end

  # Base class for the Secure Bidding Web App
  class App < Roda
    use Rack::MethodOverride

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      routing.extend(RoutingHelpers)
      routing.redirect_http_to_https if App.environment == :production

      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_session = CurrentSession.new(session)
      @current_account = @current_session.current_account
      @api_url = App.config.API_URL.to_s.chomp('/')

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        projects = fetch_published_projects
        view 'home', locals: { current_account: @current_account, projects: projects }
      end
    end

    route('register') do |routing|
      routing.on 'verify' do
        routing.on String do |token|
          routing.get { handle_registration_verify_get(routing, token) }
          routing.post { handle_registration_verify_post(routing, token) }
        end
      end

      routing.is do
        routing.get { view :register }
        routing.post { handle_registration_post(routing) }
      end
    end

    # Routes for account management
    route('account') do |routing|
      routing.on String do |username|
        routing.get do
          require_login!(routing)

          # Only allow users to view their own account
          if @current_account['username'] == username
            view :account, locals: { current_account: @current_account }
          else
            response.status = 403
            flash.now[:error] = 'You do not have permission to view this account'
            view :login
          end
        end
      end
    end


    # Routes for projects
    route('projects') do |routing|
      routing.on 'new' do
        routing.get do
          require_login!(routing)
          view :project_new
        end
      end

      routing.on String do |project_id|
        routing.on 'bids' do
          routing.post do
            handle_bid_submission(routing, project_id)
          end
        end

        routing.on 'edit' do
          routing.get do
            require_login!(routing)
            handle_admin_edit_project_get(routing, project_id)
          end

          routing.post do
            require_login!(routing)
            handle_admin_edit_project_post(routing, project_id)
          end
        end

        routing.on 'delete' do
          routing.post do
            require_login!(routing)
            handle_admin_delete_project(routing, project_id)
          end
        end

        routing.get do
          handle_project_detail(routing, project_id)
        end
      end

      routing.is do
        routing.post do
          handle_create_project(routing)
        end
      end
    end

    private

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end

    def system_roles_of(current_account)
      current_account&.dig('include', 'system_roles') || current_account&.dig('system_roles') || []
    end

    def admin?(current_account)
      system_roles_of(current_account).include?('admin')
    end

    def number_to_currency(amount)
      format('$%.2f', amount)
    end

    def fetch_published_projects
      FetchProjects.new(App.config).call
    rescue FetchProjects::ServiceError => e
      App.logger.warn "Failed to fetch projects: #{e.message}"
      []
    end


    def handle_project_detail(routing, project_id)
      project = FetchProjectDetail.new(App.config).call(project_id)
      is_owner = false # API doesn't return owner info, will be enforced on bid submission
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: is_owner }
    rescue FetchProjectDetail::NotFoundError
      response.status = 404
      flash.now[:error] = 'Project not found'
      view :project_detail, locals: { project: nil, current_account: @current_account, is_owner: false }
    rescue FetchProjectDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :project_detail, locals: { project: nil, current_account: @current_account, is_owner: false }
    end

    def handle_create_project(routing)
      require_login!(routing)

      if admin?(@current_account)
        flash.now[:error] = 'Admins cannot create projects'
        response.status = 403
        return view :project_new
      end

      title = routing.params['title'].to_s.strip
      budget_cents = routing.params['budget_cents'].to_s.strip
      state = routing.params['state'].to_s.strip

      result = CreateProject.new(App.config).call(
        title: title,
        budget_cents: budget_cents,
        state: state
      )

      flash[:notice] = "Project created successfully (ID: #{result['id']})"
      routing.redirect '/'
    rescue CreateProject::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      view :project_new
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to create project')
      response.status = e.status.to_i
      view :project_new
    end

    def handle_bid_submission(routing, project_id)
      require_login!(routing)

      unless @current_account['token']
        flash.now[:error] = 'You must be verified to submit bids. Please complete the registration verification.'
        response.status = 403
        return view :project_detail, locals: {
          project: FetchProjectDetail.new(App.config).call(project_id),
          current_account: @current_account,
          is_owner: false
        }
      end

      contractor_alias = routing.params['contractor_alias'].to_s.strip
      plaintext_bid = routing.params['plaintext_bid'].to_s.strip

      result = SubmitBid.new(App.config).call(
        project_id: project_id,
        bidder_account_id: @current_account['id'],
        contractor_alias: contractor_alias,
        plaintext_bid: plaintext_bid,
        auth_token: @current_account['token']
      )

      flash[:notice] = "Bid submitted successfully (ID: #{result['id']})"
      routing.redirect "/projects/#{project_id}"
    rescue SubmitBid::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    rescue SubmitBid::AuthorizationError => e
      flash.now[:error] = e.message
      response.status = 403
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to submit bid')
      response.status = e.status.to_i
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    end

    def handle_registration_post(routing)
      username = routing.params['username'].to_s.strip
      email = routing.params['email'].to_s.strip

      InitiateRegistration.new(App.config).call(username: username, email: email)
      flash[:notice] = 'Check your email to verify your account'
      routing.redirect '/register'
    rescue InitiateRegistration::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      view :register
    rescue InitiateRegistration::UnavailableError => e
      flash.now[:error] = e.message
      response.status = 422
      view :register
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Registration failed')
      response.status = e.status.to_i
      view :register
    end

    def handle_registration_verify_get(routing, token)
      registration = RegistrationToken.new.decode(token)
      @verification_token = token
      @registration_email = registration['email']
      @registration_username = registration['username']
      view :register_verify
    rescue RegistrationToken::InvalidTokenError
      flash[:error] = 'Verification link is invalid'
      routing.redirect '/register'
    rescue StandardError => e
      App.logger.warn "VERIFY PAGE FAILED: #{e.inspect}"
      flash.now[:error] = 'Unable to load verification form'
      response.status = 400
      view :register_verify
    end

    def handle_registration_verify_post(routing, token)
      password = routing.params['password'].to_s
      password_confirm = routing.params['password_confirm'].to_s

      if password.empty? || password != password_confirm
        flash.now[:error] = 'Passwords did not match'
        response.status = 400
        @verification_token = token
        registration = RegistrationToken.new.decode(token)
        @registration_email = registration['email']
        @registration_username = registration['username']
        return view :register_verify
      end

      result = VerifyRegistration.new(App.config).call(
        registration_token: token,
        password: password
      )

      verified_account = result.fetch('account', {}).merge('token' => result['token'])
      @current_session.store_current_account(verified_account)
      @current_session.delete_pending_registration
      flash[:notice] = 'Your account has been verified'
      routing.redirect '/'
    rescue VerifyRegistration::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      @verification_token = token
      @pending_registration = @current_session.pending_registration
      view :register_verify
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Verification failed')
      response.status = e.status.to_i
      @verification_token = token
      registration = RegistrationToken.new.decode(token)
      @registration_email = registration['email']
      @registration_username = registration['username']
      view :register_verify
    end

    def api_error_message(error, fallback)
      return error.body['error'].to_s if error.body.is_a?(Hash) && error.body['error']
      return error.body['message'].to_s if error.body.is_a?(Hash) && error.body['message']

      fallback
    end

    def handle_admin_edit_project_get(routing, project_id)
     unless admin?(@current_account)
       response.status = 403
       flash.now[:error] = 'Only admins can edit projects'
       return view :project_detail, locals: {
         project: FetchProjectDetail.new(App.config).call(project_id),
         current_account: @current_account,
         is_owner: false
       }
     end

     project = FetchProjectDetail.new(App.config).call(project_id)
     view :project_edit, locals: { project: project, current_account: @current_account }
    rescue FetchProjectDetail::NotFoundError
     response.status = 404
     flash.now[:error] = 'Project not found'
     view :project_edit, locals: { project: nil, current_account: @current_account }
    rescue FetchProjectDetail::ServiceError => e
     response.status = 500
     flash.now[:error] = e.message
     view :project_edit, locals: { project: nil, current_account: @current_account }
    end

    def handle_admin_edit_project_post(routing, project_id)
     unless admin?(@current_account)
       response.status = 403
       flash.now[:error] = 'Only admins can edit projects'
       project = FetchProjectDetail.new(App.config).call(project_id)
       return view :project_detail, locals: {
         project: project,
         current_account: @current_account,
         is_owner: false
       }
     end

     title = routing.params['title'].to_s.strip
     budget_cents = routing.params['budget_cents'].to_s.strip
     state = routing.params['state'].to_s.strip

     UpdateProject.new(App.config).call(
       project_id: project_id,
       title: title,
       budget_cents: budget_cents,
       state: state
     )

     flash[:notice] = "Project #{project_id} updated successfully"
     routing.redirect "/projects/#{project_id}"
    rescue UpdateProject::ValidationError => e
     flash.now[:error] = e.message
     response.status = 400
     project = FetchProjectDetail.new(App.config).call(project_id)
     view :project_edit, locals: { project: project, current_account: @current_account }
    rescue ApiClient::ApiError => e
     flash.now[:error] = api_error_message(e, 'Failed to update project')
     response.status = e.status.to_i
     project = FetchProjectDetail.new(App.config).call(project_id)
     view :project_edit, locals: { project: project, current_account: @current_account }
    end

    def handle_admin_delete_project(routing, project_id)
     unless admin?(@current_account)
       response.status = 403
       flash[:error] = 'Only admins can delete projects'
       return routing.redirect "/projects/#{project_id}"
     end

     DeleteProject.new(App.config).call(project_id: project_id)

     flash[:notice] = "Project #{project_id} deleted successfully"
     routing.redirect '/'
    rescue DeleteProject::NotFoundError
     response.status = 404
     flash[:error] = 'Project not found'
     routing.redirect '/'
    rescue ApiClient::ApiError => e
     flash[:error] = api_error_message(e, 'Failed to delete project')
     routing.redirect "/projects/#{project_id}"
    end
  end
end
