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

    # Admin routes for user management
    route('admin') do |routing|
      routing.on 'users' do
        routing.on 'new' do
          routing.get do
            require_login!(routing)
            handle_admin_new_user_form(routing)
          end
        end

        routing.on String do |user_id|
          routing.on 'edit' do
            routing.get do
              require_login!(routing)
              handle_admin_edit_user_get(routing, user_id)
            end

            routing.post do
              require_login!(routing)
              handle_admin_edit_user_post(routing, user_id)
            end
          end

          routing.on 'delete' do
            routing.post do
              require_login!(routing)
              handle_admin_delete_user(routing, user_id)
            end
          end

          routing.on 'roles' do
            routing.get do
              require_login!(routing)
              handle_admin_user_roles_get(routing, user_id)
            end

            routing.post do
              require_login!(routing)
              handle_admin_user_roles_post(routing, user_id)
            end
          end

          routing.get do
            require_login!(routing)
            handle_admin_view_user(routing, user_id)
          end
        end

        routing.is do
          routing.get do
            require_login!(routing)
            handle_admin_users_list(routing)
          end

          routing.post do
            require_login!(routing)
            handle_admin_create_user(routing)
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

      routing.on 'my' do
        routing.get do
          require_login!(routing)
          handle_my_projects(routing)
        end
      end

      routing.on String do |project_id|
        routing.on 'bids' do
          routing.post do
            handle_bid_submission(routing, project_id)
          end
        end

        routing.on 'memberships' do
          routing.post do
            require_login!(routing)
            handle_add_membership_post(routing, project_id)
          end

          routing.on 'accept' do
            routing.post do
              require_login!(routing)
              handle_accept_membership_post(routing, project_id)
            end
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
      return false unless current_account

      # Check system_role field (singular) - the main role assigned to the account
      current_account['system_role'] == 'admin' ||
        # Also check system_roles array for backward compatibility
        system_roles_of(current_account).include?('admin')
    end

    # Check API-provided policy summaries to determine whether an action is allowed on a resource.
    # If the API did not return a policy for the resource, fall back to the existing server-side checks in views.
    def allowed?(resource, action)
      return true unless resource.is_a?(Hash) && resource['policy'].is_a?(Hash)

      policy = resource['policy']
      key = action.to_s
      variants = [key, key.gsub('-', '_'), key.gsub(' ', '_'), "#{key}_allowed"]
      variants.any? { |k| !!policy[k] }
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

    def get_auth_token
      @current_session.auth_token
    end

    def handle_add_membership_post(routing, project_id)
      account_id = routing.params['account_id'].to_s.strip
      if account_id.empty?
        flash.now[:error] = 'Account ID is required'
        response.status = 400
        project = FetchProjectDetail.new(App.config).call(project_id)
        return view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
      end

      result = CreateProjectMembership.new(App.config).call(
        project_id: project_id,
        account_id: account_id,
        auth_token: get_auth_token
      )

      if result.is_a?(Hash) && result['status'] == 'pending'
        flash[:notice] = 'Invitation sent — user must accept to become project owner'
      else
        flash[:notice] = 'User added as project owner'
      end

      routing.redirect "/projects/#{project_id}"
    rescue CreateProjectMembership::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to add co-owner')
      response.status = e.status.to_i
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    end

    def handle_accept_membership_post(routing, project_id)
      AcceptProjectMembership.new(App.config).call(project_id: project_id, auth_token: get_auth_token)
      flash[:notice] = 'You are now a project owner'
      routing.redirect "/projects/#{project_id}"
    rescue AcceptProjectMembership::PermissionError => e
      flash.now[:error] = e.message
      response.status = 403
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to accept invitation')
      response.status = e.status.to_i
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail, locals: { project: project, current_account: @current_account, is_owner: false }
    end

    def handle_my_projects(routing)
      unless @current_account
        flash[:error] = 'You must log in to view your projects'
        return routing.redirect '/auth/login'
      end

      projects = FetchProjects.new(App.config).call
      view :my_projects, locals: { current_account: @current_account, projects: projects }
    rescue FetchProjects::ServiceError => e
      flash.now[:error] = "Failed to fetch your projects: #{e.message}"
      response.status = 500
      view :my_projects, locals: { current_account: @current_account, projects: [] }
    end

    def handle_project_detail(_routing, project_id)
      project = FetchProjectDetail.new(App.config).call(project_id)
      is_owner = false # API doesn't return owner info, will be enforced on bid submission
      view :project_detail,
           locals: { project: project, current_account: @current_account, is_owner: is_owner }
    rescue FetchProjectDetail::NotFoundError
      response.status = 404
      flash.now[:error] = 'Project not found'
      view :project_detail,
           locals: { project: nil, current_account: @current_account, is_owner: false }
    rescue FetchProjectDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :project_detail,
           locals: { project: nil, current_account: @current_account, is_owner: false }
    end

    def handle_create_project(routing)
      require_login!(routing)

      if admin?(@current_account)
        flash.now[:error] = 'Admins cannot create projects'
        response.status = 403
        return view :project_new
      end

      # Validate
      validation = Forms::ProjectNew.new.call(
        title: routing.params['title'].to_s.strip,
        budget_cents: routing.params['budget_cents'].to_s.strip.empty? ? nil : routing.params['budget_cents'].to_s.strip.to_i,
        state: routing.params['state'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        return view :project_new
      end

      validated = validation.to_h

      result = CreateProject.new(App.config).call(
        title: validated[:title],
        budget_cents: validated[:budget_cents].to_s,
        state: validated[:state],
        auth_token: get_auth_token
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
        flash.now[:error] =
          'You must be verified to submit bids. Please complete the registration verification.'
        response.status = 403
        return view :project_detail, locals: {
          project: FetchProjectDetail.new(App.config).call(project_id),
          current_account: @current_account,
          is_owner: false
        }
      end

      # Validate
      validation = Forms::BidSubmission.new.call(
        contractor_alias: routing.params['contractor_alias'].to_s.strip,
        plaintext_bid: routing.params['plaintext_bid'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        project = FetchProjectDetail.new(App.config).call(project_id)
        return view :project_detail,
             locals: { project: project, current_account: @current_account, is_owner: false }
      end

      validated = validation.to_h

      result = SubmitBid.new(App.config).call(
        project_id: project_id,
        bidder_account_id: @current_account['id'],
        contractor_alias: validated[:contractor_alias],
        plaintext_bid: validated[:plaintext_bid],
        auth_token: @current_account['token']
      )

      flash[:notice] = "Bid submitted successfully (ID: #{result['id']})"
      routing.redirect "/projects/#{project_id}"
    rescue SubmitBid::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail,
           locals: { project: project, current_account: @current_account, is_owner: false }
    rescue SubmitBid::AuthorizationError => e
      flash.now[:error] = e.message
      response.status = 403
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail,
           locals: { project: project, current_account: @current_account, is_owner: false }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to submit bid')
      response.status = e.status.to_i
      project = FetchProjectDetail.new(App.config).call(project_id)
      view :project_detail,
           locals: { project: project, current_account: @current_account, is_owner: false }
    end

    def handle_registration_post(routing)
      validation = Forms::Register.new.call(
        username: routing.params['username'].to_s.strip,
        email: routing.params['email'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        return view :register
      end

      validated = validation.to_h

      InitiateRegistration.new(App.config).call(username: validated[:username], email: validated[:email])
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
      validation = Forms::Verify.new.call(
        password: routing.params['password'].to_s,
        password_confirm: routing.params['password_confirm'].to_s
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        @verification_token = token
        registration = RegistrationToken.new.decode(token)
        @registration_email = registration['email']
        @registration_username = registration['username']
        return view :register_verify
      end

      validated = validation.to_h

      result = VerifyRegistration.new(App.config).call(
        registration_token: token,
        password: validated[:password]
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

    def handle_admin_edit_project_get(_routing, project_id)
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

      # Validate
      validation = Forms::ProjectNew.new.call(
        title: routing.params['title'].to_s.strip,
        budget_cents: routing.params['budget_cents'].to_s.strip.empty? ? nil : routing.params['budget_cents'].to_s.strip.to_i,
        state: routing.params['state'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        project = FetchProjectDetail.new(App.config).call(project_id)
        return view :project_edit, locals: { project: project, current_account: @current_account }
      end

      validated = validation.to_h

      UpdateProject.new(App.config).call(
        project_id: project_id,
        title: validated[:title],
        budget_cents: validated[:budget_cents].to_s,
        state: validated[:state],
        auth_token: get_auth_token
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

      DeleteProject.new(App.config).call(project_id: project_id, auth_token: get_auth_token)

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

    def handle_admin_users_list(routing)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can view users'
        return routing.redirect '/'
      end

      users = FetchUsers.new(App.config).call
      view :admin_users_list, locals: { users: users, current_account: @current_account }
    rescue FetchUsers::ServiceError => e
      flash.now[:error] = e.message
      response.status = 500
      view :admin_users_list, locals: { users: [], current_account: @current_account }
    end

    def handle_admin_view_user(routing, user_id)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can view users'
        return routing.redirect '/'
      end

      user = FetchUserDetail.new(App.config).call(user_id)
      view :admin_user_detail, locals: { user: user, current_account: @current_account }
    rescue FetchUserDetail::NotFoundError
      response.status = 404
      flash.now[:error] = 'User not found'
      view :admin_user_detail, locals: { user: nil, current_account: @current_account }
    rescue FetchUserDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :admin_user_detail, locals: { user: nil, current_account: @current_account }
    end

    def handle_admin_new_user_form(routing)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can create users'
        return routing.redirect '/'
      end

      view :admin_user_form,
           locals: { user: nil, current_account: @current_account, is_edit: false }
    end

    def handle_admin_create_user(routing)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can create users'
        return routing.redirect '/'
      end

      validation = Forms::AdminUser.new.call(
        username: routing.params['username'].to_s.strip,
        email: routing.params['email'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        return view :admin_user_form,
             locals: { user: nil, current_account: @current_account, is_edit: false }
      end

      validated = validation.to_h

      result = CreateAccount.new(App.config).call(
        username: validated[:username],
        email: validated[:email],
        password: validated[:password]
      )

      flash[:notice] = "User #{validated[:username]} created successfully (ID: #{result['id']})"
      routing.redirect "/admin/users/#{result['id']}"
    rescue CreateAccount::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      view :admin_user_form,
           locals: { user: nil, current_account: @current_account, is_edit: false }
    rescue CreateAccount::UnavailableError => e
      flash.now[:error] = e.message
      response.status = 422
      view :admin_user_form,
           locals: { user: nil, current_account: @current_account, is_edit: false }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to create user')
      response.status = e.status.to_i
      view :admin_user_form,
           locals: { user: nil, current_account: @current_account, is_edit: false }
    end

    def handle_admin_edit_user_get(routing, user_id)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can edit users'
        return routing.redirect '/'
      end

      user = FetchUserDetail.new(App.config).call(user_id)
      view :admin_user_form,
           locals: { user: user, current_account: @current_account, is_edit: true }
    rescue FetchUserDetail::NotFoundError
      response.status = 404
      flash.now[:error] = 'User not found'
      view :admin_user_form, locals: { user: nil, current_account: @current_account, is_edit: true }
    rescue FetchUserDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :admin_user_form, locals: { user: nil, current_account: @current_account, is_edit: true }
    end

    def handle_admin_edit_user_post(routing, user_id)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can edit users'
        return routing.redirect '/'
      end

      validation = Forms::AdminUserEdit.new.call(
        email: routing.params['email'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        user = FetchUserDetail.new(App.config).call(user_id)
        return view :admin_user_form,
             locals: { user: user, current_account: @current_account, is_edit: true }
      end

      validated = validation.to_h

      UpdateAccount.new(App.config).call(
        user_id: user_id,
        email: validated[:email],
        auth_token: get_auth_token
      )

      flash[:notice] = "User #{user_id} updated successfully"
      routing.redirect "/admin/users/#{user_id}"
    rescue UpdateAccount::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      user = FetchUserDetail.new(App.config).call(user_id)
      view :admin_user_form,
           locals: { user: user, current_account: @current_account, is_edit: true }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to update user')
      response.status = e.status.to_i
      user = FetchUserDetail.new(App.config).call(user_id)
      view :admin_user_form,
           locals: { user: user, current_account: @current_account, is_edit: true }
    end

    def handle_admin_delete_user(routing, user_id)
      unless admin?(@current_account)
        response.status = 403
        flash[:error] = 'Only admins can delete users'
        return routing.redirect '/'
      end

      DeleteAccount.new(App.config).call(user_id: user_id, auth_token: get_auth_token)

      flash[:notice] = "User #{user_id} deleted successfully"
      routing.redirect '/admin/users'
    rescue DeleteAccount::NotFoundError
      response.status = 404
      flash[:error] = 'User not found'
      routing.redirect '/admin/users'
    rescue ApiClient::ApiError => e
      flash[:error] = api_error_message(e, 'Failed to delete user')
      routing.redirect "/admin/users/#{user_id}"
    end

    def handle_admin_user_roles_get(routing, user_id)
      unless admin?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can manage roles'
        return routing.redirect '/'
      end

      user = FetchUserDetail.new(App.config).call(user_id)
      roles = AssignSystemRole::VALID_ROLES
      current_roles = system_roles_of(user)
      view :admin_user_roles,
           locals: { user: user, roles: roles, current_roles: current_roles,
                     current_account: @current_account }
    rescue FetchUserDetail::NotFoundError
      response.status = 404
      flash.now[:error] = 'User not found'
      view :admin_user_roles,
           locals: { user: nil, roles: [], current_roles: [], current_account: @current_account }
    rescue FetchUserDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :admin_user_roles,
           locals: { user: nil, roles: [], current_roles: [], current_account: @current_account }
    end

    def handle_admin_user_roles_post(routing, user_id)
      unless admin?(@current_account)
        response.status = 403
        flash[:error] = 'Only admins can manage roles'
        return routing.redirect '/'
      end

      system_role = routing.params['system_role'].to_s.strip

      AssignSystemRole.new(App.config).call(
        account_id: user_id,
        system_role: system_role,
        auth_token: get_auth_token
      )

      flash[:notice] = "User #{user_id} role updated to #{system_role}"
      routing.redirect "/admin/users/#{user_id}/roles"
    rescue AssignSystemRole::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      user = FetchUserDetail.new(App.config).call(user_id)
      roles = AssignSystemRole::VALID_ROLES
      current_roles = system_roles_of(user)
      view :admin_user_roles,
           locals: { user: user, roles: roles, current_roles: current_roles,
                     current_account: @current_account }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to assign role')
      response.status = e.status.to_i
      user = FetchUserDetail.new(App.config).call(user_id)
      roles = AssignSystemRole::VALID_ROLES
      current_roles = system_roles_of(user)
      view :admin_user_roles,
           locals: { user: user, roles: roles, current_roles: current_roles,
                     current_account: @current_account }
    end
  end
end
