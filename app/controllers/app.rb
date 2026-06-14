# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'
require 'time'
require 'uri'

module SecureBiddingApp
  module RoutingHelpers
    def redirect_http_to_https
      return unless scheme == 'http'

      redirect url.sub(/^http:/, 'https:')
    end

    # Google OAuth redirect_uri uses APP_URL (www). Session cookies are host-scoped,
    # so bare-domain visits must redirect before SSO stores sso_state in session.
    def redirect_to_canonical_host
      return unless production_host_redirect?

      canonical_host = canonical_app_host
      return if canonical_host.nil? || host == canonical_host

      target = "https://#{canonical_host}#{path}"
      target += "?#{query_string}" unless query_string.to_s.empty?
      redirect target
    end

    def production_host_redirect?
      App.environment == :production
    end

    def canonical_app_host
      app_url = App.config.APP_URL.to_s.strip
      return nil if app_url.empty?

      URI.parse(app_url).host
    rescue URI::InvalidURIError
      nil
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
      if App.environment == :production
        routing.redirect_http_to_https
        routing.redirect_to_canonical_host
      end

      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_session = CurrentSession.new(session)
      @current_account = @current_session.current_account
      @api_url = App.config.API_URL.to_s.chomp('/')

      routing.public
      routing.assets

      @current_account = sync_current_account_from_api(@current_account) unless skip_session_sync?(request)

      routing.multi_route

      # GET /
      routing.root do
        projects = fetch_published_projects
        view 'home', locals: { current_account: @current_account, projects: projects }
      end
    end

    route('verify-email') do |routing|
      routing.get { handle_verification_get(routing) }
      routing.post { handle_verification_post(routing) }
    end

    route('register') do |routing|
      routing.on 'verify' do
        routing.on String do |token|
          routing.get { routing.redirect "/verify-email?token=#{URI.encode_www_form_component(token)}" }
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
        routing.on 'edit' do
          routing.get do
            require_login!(routing)
            account = load_profile_account
            return routing.redirect("/account/#{account['username']}") if account['username'] != username

            view :account_edit, locals: { account: account, current_account: @current_account }
          rescue ApiClient::ApiError => e
            response.status = e.status.to_i
            flash.now[:error] = api_error_message(e, 'Unable to load your account')
            view :account_edit, locals: { account: @current_account, current_account: @current_account }
          end

          routing.patch do
            require_login!(routing)
            handle_account_update(routing, username)
          end

          routing.post do
            require_login!(routing)
            handle_account_update(routing, username)
          end
        end

        routing.on 'resend_verification' do
          routing.post do
            require_login!(routing)
            handle_resend_account_verification(routing, username)
          end
        end

        routing.get do
          require_login!(routing)
          return routing.redirect("/account/#{@current_account['username']}") if @current_account['username'] != username

          api_key_scope = routing.params['scope'].to_s.strip
          api_key_scope = '*:read' if api_key_scope.empty?

          profile = FetchAccountByUsername.new(App.config).call(
            username: username,
            auth_token: get_auth_token,
            scope: api_key_scope
          )
          api_key = profile['api_key']
          view :account, locals: {
            account: profile,
            current_account: @current_account,
            api_key: api_key,
            api_key_scope: profile['api_key_scope'] || api_key_scope
          }
        rescue ApiClient::ApiError => e
          response.status = e.status.to_i
          flash.now[:error] = api_error_message(e, 'Unable to load your account')
          view :account, locals: { account: @current_account, current_account: @current_account }
        end
      end
    end

    # Admin routes for user management
    route('admin') do |routing|
      routing.on 'users' do
        routing.on 'new' do
          routing.get { admin_user_route_not_found!(routing) }
          routing.post { admin_user_route_not_found!(routing) }
        end

        routing.on String do |user_id|
          admin_user_route_not_found!(routing) if user_id == 'new'

          routing.on 'edit' do
            routing.get { admin_user_route_not_found!(routing) }
            routing.post { admin_user_route_not_found!(routing) }
          end

          routing.on 'delete' do
            routing.post { admin_user_route_not_found!(routing) }
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

          routing.post { admin_user_route_not_found!(routing) }
        end
      end
    end

    # Routes for projects
    route('projects') do |routing|
      routing.on 'new' do
        routing.get do
          require_login!(routing)
          require_email_verified!(routing)
          view :project_new
        end
      end

      routing.on 'my' do
        routing.get do
          require_login!(routing)
          require_email_verified!(routing)
          handle_my_projects(routing)
        end
      end

      routing.on String do |project_id|
        routing.on 'bids' do
          routing.post do
            handle_bid_submission(routing, project_id)
          end
        end

        routing.on 'award' do
          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_award_bid(routing, project_id)
          end
        end

        routing.on 'request_payment' do
          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_request_payment(routing, project_id)
          end
        end

        routing.on 'process_payment' do
          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_process_payment(routing, project_id)
          end
        end

        routing.on 'acknowledge_payment' do
          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_acknowledge_payment(routing, project_id)
          end
        end

        routing.on 'memberships' do
          routing.on 'accept' do
            routing.post do
              require_login!(routing)
              require_email_verified!(routing)
              handle_accept_membership_post(routing, project_id)
            end
          end

          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_add_membership_post(routing, project_id)
          end
        end

        routing.on 'edit' do
          routing.get do
            require_login!(routing)
            require_email_verified!(routing)
            handle_admin_edit_project_get(routing, project_id)
          end

          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_admin_edit_project_post(routing, project_id)
          end
        end

        routing.on 'delete' do
          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_admin_delete_project(routing, project_id)
          end
        end

        routing.on 'milestones' do
          routing.post do
            require_login!(routing)
            require_email_verified!(routing)
            handle_create_milestone(routing, project_id)
          end
        end

        routing.on 'escrow' do
          routing.on 'fund' do
            routing.post do
              require_login!(routing)
              require_email_verified!(routing)
              handle_fund_escrow(routing, project_id)
            end
          end

          routing.on 'release' do
            routing.post do
              require_login!(routing)
              require_email_verified!(routing)
              handle_release_escrow(routing, project_id)
            end
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

    def valid_uuid?(id)
      id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end

    def require_email_verified!(routing)
      return unless @current_account
      return if account_email_verified?(@current_account)

      flash[:error] =
        'Please verify your email before using this feature. Resend a verification email from your account page.'
      username = @current_account['username'] || @current_account[:username]
      routing.redirect "/account/#{username}"
    end

    def load_profile_account
      apply_account_to_session!(merge_profile_account(@current_account, get_auth_token))
    end

    def skip_session_sync?(request)
      %w[/auth/login /auth/sso /auth/sso_callback].include?(request.path)
    end

    def sync_current_account_from_api(account)
      return nil unless account

      token = account['token'] || account[:token] || get_auth_token
      return account if token.to_s.strip.empty?

      apply_account_to_session!(merge_profile_account(account, token))
    rescue ApiClient::ApiError => e
      return clear_current_session! if e.status == 401

      account
    end

    def merge_profile_account(base_account, token)
      fetched = FetchAccount.new(App.config).call(user_id: base_account['id'], auth_token: token)
      merged = account_data_hash(base_account).merge(account_data_hash(fetched))
      merged['token'] = token unless token.to_s.strip.empty?

      Account.from_hash(merged, token)
    end

    def account_data_hash(account)
      hash = if account.respond_to?(:to_h)
               account.to_h
             else
               account || {}
             end
      hash.transform_keys(&:to_s).dup
    end

    def apply_account_to_session!(account)
      @current_session.store_current_account(account)
      @current_account = account
      account
    end

    def clear_current_session!
      @current_session.delete_current_account
      @current_account = nil
    end

    def apply_verification_to_session!(verification_result)
      return unless @current_account
      return unless verification_result['id'] == @current_account['id']

      token = get_auth_token
      merged = account_data_hash(@current_account).merge(account_data_hash(verification_result))
      merged['email_verified'] = true
      merged['token'] = token unless token.to_s.strip.empty?

      apply_account_to_session!(Account.from_hash(merged, token))
    end

    def handle_verification_get(routing)
      token = routing.params['token'].to_s.strip
      if token.empty?
        flash[:error] = 'Verification link is invalid'
        return routing.redirect '/'
      end

      load_verification_locals(token)
      view :verify_email
    rescue FetchVerificationPreview::PreviewError, RegistrationToken::InvalidTokenError
      flash[:error] = 'Verification link is invalid or has expired'
      routing.redirect '/'
    rescue StandardError => e
      App.logger.warn "VERIFY PAGE FAILED: #{e.inspect}"
      flash.now[:error] = 'Unable to load verification form'
      response.status = 400
      @verification_token = token
      @verification_purpose = 'email_verification'
      view :verify_email
    end

    def load_verification_locals(token)
      @verification_token = token
      preview = FetchVerificationPreview.new(App.config).call(registration_token: token)
      @verification_purpose = preview['purpose']
      @registration_username = preview['username']
      @registration_email = preview['email']
    rescue FetchVerificationPreview::PreviewError
      preview = RegistrationToken.new.decode(token)
      @verification_purpose = 'registration'
      @registration_username = preview['username']
      @registration_email = preview['email']
    end

    def handle_verification_post(routing)
      token = routing.params['registration_token'].to_s.strip
      purpose = routing.params['verification_purpose'].to_s.strip

      if token.empty?
        flash[:error] = 'Verification link is invalid'
        return routing.redirect '/'
      end

      password = nil
      if purpose == 'registration'
        validation = Forms::Verify.new.call(
          password: routing.params['password'].to_s,
          password_confirm: routing.params['password_confirm'].to_s
        )

        if validation.failure?
          flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
          response.status = 400
          load_verification_locals(token)
          return view :verify_email
        end

        password = validation.to_h[:password]
      end

      result = CompleteVerification.new(App.config).call(
        registration_token: token,
        password: password
      )

      if result['token']
        verified_account = result.fetch('account', {}).merge('token' => result['token'])
        @current_session.store_current_account(verified_account)
        @current_session.delete_pending_registration
        flash[:notice] = 'Your account has been verified'
      else
        apply_verification_to_session!(result)
        flash[:notice] = 'Your email has been verified'
      end

      routing.redirect '/'
    rescue CompleteVerification::VerificationError => e
      flash[:error] = e.message
      routing.redirect '/'
    rescue ApiClient::ApiError => e
      flash[:error] = api_error_message(e, 'Verification failed')
      routing.redirect '/'
    end

    def account_email_verified?(account)
      return false unless account
      return true if admin?(account)

      return account.email_verified? if account.respond_to?(:email_verified?)

      value = account['email_verified']
      return true if value == true || value.to_s == 'true'
      return false if value == false || value.to_s == 'false'

      verified_at = account['email_verified_at']
      return !verified_at.to_s.strip.empty? if verified_at

      false
    end

    def redirect_to_profile(username)
      "/account/#{username}"
    end

    def handle_account_update(routing, username)
      account = @current_account
      account = load_profile_account
      return routing.redirect(redirect_to_profile(account['username'])) if account['username'] != username

      validation = Forms::AccountEdit.new.call(
        username: routing.params['username'].to_s.strip,
        email: routing.params['email'].to_s.strip,
        password: routing.params['password'].to_s,
        password_confirm: routing.params['password_confirm'].to_s,
        current_password: routing.params['current_password'].to_s
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        return view :account_edit, locals: { account: account, current_account: @current_account }
      end

      validated = validation.to_h
      current_password = validated.delete(:current_password)
      password = validated[:password]

      verify_current_password!(current_password) if password

      UpdateAccount.new(App.config).call(
        user_id: account['id'],
        username: validated[:username],
        email: validated[:email],
        password: password,
        auth_token: get_auth_token
      )

      merged_hash = (account.respond_to?(:to_h) ? account.to_h : account).merge(
        'username' => validated[:username],
        'email' => validated[:email]
      )
      merged_hash['email_verified'] = false if merged_hash['email'] != account['email']
      apply_account_to_session!(Account.from_hash(merged_hash, get_auth_token))

      flash[:notice] = if merged_hash['email'] != account['email']
                         'Verification email sent — please check your inbox.'
                       else
                         'Account updated successfully'
                       end
      routing.redirect redirect_to_profile(merged_hash['username'])
    rescue AuthenticateAccount::UnauthorizedError
      flash.now[:error] = 'Current password is incorrect'
      response.status = 403
      view :account_edit, locals: { account: account, current_account: @current_account }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to update account')
      response.status = e.status.to_i
      view :account_edit, locals: { account: account, current_account: @current_account }
    end

    def handle_resend_account_verification(routing, username)
      if @current_account['username'] != username
        return routing.redirect(redirect_to_profile(@current_account['username']))
      end

      account = merge_profile_account(@current_account, get_auth_token)

      if account_email_verified?(account)
        apply_account_to_session!(account)
        flash[:notice] = 'Your email is already verified'
        return routing.redirect '/'
      end

      ResendAccountVerification.new(App.config).call(
        user_id: account['id'],
        auth_token: get_auth_token
      )
      flash[:notice] = 'Verification email sent — open the link in your inbox to verify your address.'
      routing.redirect redirect_to_profile(account['username'])
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to resend verification email')
      response.status = e.status.to_i
      view :account, locals: { account: account, current_account: @current_account }
    end

    def verify_current_password!(current_password)
      AuthenticateAccount.new(App.config).call(
        username: @current_account['username'],
        password: current_password
      )
    end

    def system_roles_of(current_account)
      return [] unless current_account

      if current_account.respond_to?(:system_roles)
        current_account.system_roles || []
      elsif current_account.is_a?(Hash)
        current_account.dig('include', 'system_roles') || current_account['system_roles'] || []
      else
        []
      end
    end

    def user_role_names(user)
      return [] unless user

      candidates = [
        user['profile_roles'],
        user['system_roles'],
        user['system_role']
      ]
      candidates.flatten.compact.map(&:to_s).map(&:strip).reject(&:empty?).uniq
    end

    def admin_role_user?(user)
      roles = user_role_names(user)
      capabilities = user['capabilities'] || {}
      roles.include?('admin') ||
        roles.include?('system_admin') ||
        capabilities['admin'] == true ||
        capabilities['system_admin'] == true ||
        capabilities['can_manage_accounts'] == true
    end

    def primary_account_role(user)
      roles = user_role_names(user)
      return 'admin' if admin_role_user?(user)
      return 'member' if roles.include?('member')

      roles.first.to_s
    end

    def same_account?(user, current_account)
      return false unless user && current_account

      user['id'].to_s == current_account['id'].to_s
    end

    def can_manage_user_role?(user, current_account)
      can_manage_accounts?(current_account) && !same_account?(user, current_account)
    end

    def role_action_label(user)
      admin_role_user?(user) ? 'Manage Role' : 'Promote'
    end

    def admin?(current_account)
      return false unless current_account

      # Prefer Account#admin? when available (reads API capabilities). Fall back to legacy checks.
      return true if current_account.respond_to?(:admin?) && current_account.admin?

      if current_account.respond_to?(:[]) || current_account.is_a?(Hash)
        current_account['system_role'] == 'admin' ||
          system_roles_of(current_account).any? { |role| role == 'admin' || role == 'system_admin' }
      else
        false
      end
    end

    # Check API-provided policy summaries to determine whether an action is allowed on a resource.
    # If the API did not return a policy for the resource, fall back to the existing server-side checks in views.
    def allowed?(resource, action)
      return resource.allowed?(action) if resource.is_a?(SecureBiddingApp::Project)

      # Grab policy from Hash-like resources (support model objects that implement [] / dig)
      policy = if resource.respond_to?(:[]) then resource['policy'] elsif resource.is_a?(Hash) then resource['policy'] else nil end
      return false unless policy.is_a?(Hash) && !policy.empty?

      # Map legacy/view action names to canonical API policy keys
      mapping = {
        'edit' => 'update',
        'delete' => 'destroy',
        'create_bid' => 'bid',
        'submit_bid' => 'bid',
        'create' => 'create',
        'view_bids' => 'view_bid_submissions',
        'manage_owners' => 'manage_memberships',
        'accept_ownership' => 'accept_ownership',
        'is_owner' => 'assigned_owner',
        'assigned_owner' => 'assigned_owner',
        'admin_access' => 'admin_access',
        'view_bid_count' => 'view_bid_count',
        'manage_milestones' => 'manage_milestones'
      }

      key = action.to_s
      candidate = mapping[key] || key
      variants = [candidate, candidate.gsub('-', '_'), candidate.gsub(' ', '_'), "#{candidate}_allowed"]
      variants.any? { |k| !!policy[k] }
    end

    def number_to_currency(amount)
      format('$%.2f', amount)
    end

    def format_bidding_deadline(value)
      SecureBiddingApp::TaipeiTime.display(value)
    end

    def bidding_deadline_input_value(value)
      SecureBiddingApp::TaipeiTime.input_value(value)
    end

    def normalize_bidding_deadline_param(value)
      SecureBiddingApp::TaipeiTime.to_api_iso(value) || value.to_s.strip
    end

    def fetch_published_projects
      catalog_projects(FetchProjects.new(App.config).call)
    rescue FetchProjects::ServiceError => e
      App.logger.warn "Failed to fetch projects: #{e.message}"
      []
    end

    def catalog_projects(projects)
      (projects || []).select { |project| allowed?(project, 'available_for_bidding') }
    end

    def get_auth_token
      @current_session.auth_token
    end

    def handle_add_membership_post(routing, project_id)
      username = routing.params['username'].to_s.strip
      account_id = routing.params['account_id'].to_s.strip
      if username.empty? && account_id.empty?
        flash.now[:error] = 'Username is required'
        response.status = 400
        return view :project_detail, locals: project_detail_locals(project_id)
      end

      result = CreateProjectMembership.new(App.config).call(
        project_id: project_id,
        username: username.empty? ? nil : username,
        account_id: account_id.empty? ? nil : account_id,
        auth_token: get_auth_token
      )

      if result.is_a?(Hash) && result['status'] == 'pending'
        invitee = result['username'] || username
        flash[:notice] = "Invitation sent to #{invitee} — they must accept to become project owner"
      else
        flash[:notice] = 'User added as project owner'
      end

      routing.redirect "/projects/#{project_id}"
    rescue CreateProjectMembership::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      view :project_detail, locals: project_detail_locals(project_id)
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to add co-owner')
      response.status = e.status.to_i
      view :project_detail, locals: project_detail_locals(project_id)
    end

    def handle_accept_membership_post(routing, project_id)
      AcceptProjectMembership.new(App.config).call(project_id: project_id, auth_token: get_auth_token)
      flash[:notice] = 'You are now a project owner'
      routing.redirect "/projects/#{project_id}"
    rescue AcceptProjectMembership::PermissionError => e
      flash.now[:error] = e.message
      response.status = 403
      view :project_detail, locals: project_detail_locals(project_id)
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to accept invitation')
      response.status = e.status.to_i
      view :project_detail, locals: project_detail_locals(project_id)
    end

    def handle_my_projects(routing)
      unless @current_account
        flash[:error] = 'You must log in to view your projects'
        return routing.redirect '/auth/login'
      end

      projects = FetchProjects.new(App.config).call(auth_token: get_auth_token)
      buckets = partition_my_projects(projects)
      filter = routing.params['filter'].to_s.strip
      filter = 'all' unless %w[all owned admin invites freelancer bids active closed].include?(filter)

      view :my_projects,
           locals: {
             current_account: @current_account,
             projects: projects,
             owned_projects: buckets[:owned],
             admin_projects: buckets[:admin],
             pending_invite_projects: buckets[:pending_invites],
             freelancer_projects: buckets[:freelancer],
             bidder_projects: buckets[:bidder],
             active_owned_projects: buckets[:active_owned],
             active_admin_projects: buckets[:active_admin],
             active_freelancer_projects: buckets[:active_freelancer],
             active_bidder_projects: buckets[:active_bidder],
             closed_owned_projects: buckets[:closed_owned],
             closed_admin_projects: buckets[:closed_admin],
             closed_freelancer_projects: buckets[:closed_freelancer],
             filter: filter,
             platform_admin: admin?(@current_account)
           }
    rescue FetchProjects::ServiceError => e
      flash.now[:error] = "Failed to fetch your projects: #{e.message}"
      response.status = 500
      view :my_projects,
           locals: {
             current_account: @current_account,
             projects: [],
             owned_projects: [],
             admin_projects: [],
             pending_invite_projects: [],
             freelancer_projects: [],
             bidder_projects: [],
             active_owned_projects: [],
             active_admin_projects: [],
             active_freelancer_projects: [],
             active_bidder_projects: [],
             closed_owned_projects: [],
             closed_admin_projects: [],
             closed_freelancer_projects: [],
             filter: 'all',
             platform_admin: false
           }
    end

    ACTIVE_PROJECT_STATES = %w[published in_progress payment_pending].freeze

    def partition_my_projects(projects)
      owned = []
      admin = []
      pending_invites = []
      freelancer = []
      bidder = []

      (projects || []).each do |project|
        if project_pending_invite?(project)
          pending_invites << project
        elsif project_owned?(project)
          owned << project
        elsif project_admin?(project)
          admin << project
        end
        freelancer << project if project_freelancer?(project)
        bidder << project if project_bidder?(project)
      end

      {
        owned: owned,
        admin: admin,
        pending_invites: pending_invites,
        freelancer: freelancer,
        bidder: bidder,
        active_owned: owned.select { |project| project_active?(project) },
        active_admin: admin.select { |project| project_active?(project) },
        active_freelancer: freelancer.select { |project| project_active?(project) },
        active_bidder: bidder.select { |project| allowed?(project, 'track_open_bid') },
        closed_owned: owned.select { |project| project_closed?(project) },
        closed_admin: admin.select { |project| project_closed?(project) },
        closed_freelancer: freelancer.select { |project| project_closed?(project) }
      }
    end

    def project_admin_only?(project)
      project_admin?(project) && !project_owned?(project)
    end

    def project_active?(project)
      ACTIVE_PROJECT_STATES.include?(project_state(project))
    end

    def project_owned?(project)
      allowed?(project, 'assigned_owner') || allowed?(project, 'is_owner')
    end

    def project_admin?(project)
      allowed?(project, 'admin_access')
    end

    def project_pending_invite?(project)
      allowed?(project, 'accept_ownership')
    end

    def project_freelancer?(project)
      allowed?(project, 'view_as_awarded_bidder')
    end

    def project_bidder?(project)
      project_has_bid?(project) && !project_freelancer?(project)
    end

    def project_has_bid?(project)
      bid = project['my_bid_submission']
      return true if bid.is_a?(Hash) && !bid['id'].to_s.strip.empty?

      allowed?(project, 'has_bid')
    end

    def project_closed?(project)
      project_state(project) == 'closed'
    end

    def project_state(project)
      if project.respond_to?(:[])
        project['state'].to_s
      else
        project.to_s
      end
    end

    def project_state_badge_class(state)
      case state.to_s
      when 'saved' then 'bg-primary text-white'
      when 'published' then 'bg-success text-white'
      when 'in_progress' then 'bg-info text-white'
      when 'payment_pending' then 'bg-warning text-dark'
      when 'closed' then 'bg-secondary text-white'
      else 'bg-light text-dark'
      end
    end

    def project_relationship_label(project, fallback = 'Owner')
      if project_pending_invite?(project)
        'Pending invite'
      elsif project_admin?(project)
        'Admin'
      elsif project_owned?(project) && project_freelancer?(project)
        'Owner, Freelancer'
      elsif project_freelancer?(project)
        'Freelancer'
      elsif project_owned?(project) && project_has_bid?(project)
        'Owner, Bidder'
      elsif project_owned?(project)
        'Owner'
      elsif project_has_bid?(project)
        'Bidder'
      else
        fallback
      end
    end

    def fetch_project_detail(project_id)
      auth_token = get_auth_token
      FetchProjectDetail.new(App.config).call(project_id, auth_token: auth_token)
    end

    def enrich_project_workspace(project)
      data = project.to_h
      token = get_auth_token
      return Project.from_hash(data) unless token

      project_id = project['id']
      if project.allowed?('view_bid_count')
        count_payload = FetchProjectBidCount.new(App.config).call(project_id, auth_token: token)
        data['bid_count'] = count_payload['bid_count']
      end

      if project.allowed?('manage_milestones')
        milestone_payload = FetchProjectMilestones.new(App.config).call(project_id, auth_token: token)
        data['milestones'] = milestone_payload['milestones'] || []
      end

      if project.allowed?('view_bids')
        bid_payload = FetchProjectBidSubmissions.new(App.config).call(project_id, auth_token: token)
        data['bids'] = bid_payload['bid_submissions'] || []
      end

      Project.from_hash(data)
    rescue FetchProjectBidCount::ServiceError, FetchProjectMilestones::ServiceError, FetchProjectBidSubmissions::ServiceError => e
      App.logger.warn "Project workspace enrichment failed: #{e.message}"
      Project.from_hash(data)
    end

    def project_detail_locals(project_id)
      project = enrich_project_workspace(fetch_project_detail(project_id))
      {
        project: project,
        current_account: @current_account,
        is_owner: project.allowed?('assigned_owner')
      }
    rescue FetchProjectDetail::UnauthorizedError
      clear_current_session!
      project = enrich_project_workspace(FetchProjectDetail.new(App.config).call(project_id))
      {
        project: project,
        current_account: @current_account,
        is_owner: false,
        session_expired: true
      }
    rescue FetchProjectDetail::NotFoundError
      { project: nil, current_account: @current_account, is_owner: false, project_unavailable: :not_found }
    rescue FetchProjectDetail::ForbiddenError
      { project: nil, current_account: @current_account, is_owner: false, project_unavailable: :forbidden }
    end

    def handle_project_detail(_routing, project_id)
      locals = project_detail_locals(project_id)
      flash.now[:error] = 'Your session expired. Please log in again to manage this project.' if locals[:session_expired]
      if locals[:project].nil?
        case locals[:project_unavailable]
        when :forbidden
          flash.now[:error] = 'You do not have access to this project.'
          response.status = 403
        else
          flash.now[:error] = 'Project not found or is no longer available.'
          response.status = 404
        end
      end
      view :project_detail, locals: locals
    rescue FetchProjectDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :project_detail,
           locals: { project: nil, current_account: @current_account, is_owner: false }
    end

    def can_create_projects?(account = @current_account)
      return false unless account

      return account.can_create_projects? if account.respond_to?(:can_create_projects?)

      !admin?(account)
    end

    def can_manage_accounts?(account = @current_account)
      return false unless account

      return account.can_manage_accounts? if account.respond_to?(:can_manage_accounts?)

      admin?(account)
    end

    def handle_create_project(routing)
      require_login!(routing)
      require_email_verified!(routing)

      unless can_create_projects?(@current_account)
        flash.now[:error] = 'You cannot create projects with your current account'
        response.status = 403
        return view :project_new
      end

      # Validate
      validation = Forms::ProjectNew.new.call(
        title: routing.params['title'].to_s.strip,
        description: routing.params['description'].to_s.strip,
        required_documents: project_required_documents_from_params(routing.params),
        budget_cents: routing.params['budget_cents'].to_s.strip.empty? ? nil : routing.params['budget_cents'].to_s.strip.to_i,
        state: routing.params['state'].to_s.strip,
        bidding_deadline: normalize_bidding_deadline_param(routing.params['bidding_deadline']),
        nacl_public_key: routing.params['nacl_public_key'].to_s.strip,
        nacl_encrypted_private_key: routing.params['nacl_encrypted_private_key'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        return view :project_new
      end

      validated = validation.to_h

      CreateProject.new(App.config).call(
        title: validated[:title],
        description: validated[:description],
        required_documents: validated[:required_documents],
        budget_cents: validated[:budget_cents].to_s,
        state: validated[:state],
        bidding_deadline: validated[:bidding_deadline],
        nacl_public_key: validated[:nacl_public_key],
        nacl_encrypted_private_key: validated[:nacl_encrypted_private_key],
        auth_token: get_auth_token
      )

      flash[:notice] = 'Project created successfully'
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

    def handle_create_milestone(routing, project_id)
      locals = project_detail_locals(project_id)
      unless locals[:project] && allowed?(locals[:project], 'manage_milestones')
        flash[:error] = 'You are not allowed to manage milestones for this project'
        return routing.redirect "/projects/#{project_id}"
      end

      CreateMilestone.new(App.config).call(
        project_id: project_id,
        title: routing.params['title'],
        budget_cents: routing.params['budget_cents'],
        description: routing.params['description'],
        auth_token: get_auth_token
      )
      flash[:notice] = 'Milestone created'
      routing.redirect "/projects/#{project_id}"
    rescue CreateMilestone::ValidationError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    rescue CreateMilestone::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    end

    def handle_fund_escrow(routing, project_id)
      milestone_id = routing.params['milestone_id'].to_s
      FundEscrow.new(App.config).call(milestone_id: milestone_id, auth_token: get_auth_token)
      flash[:notice] = 'Escrow funded (placeholder gateway)'
      routing.redirect "/projects/#{project_id}"
    rescue FundEscrow::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    end

    def handle_release_escrow(routing, project_id)
      milestone_id = routing.params['milestone_id'].to_s
      ReleaseEscrow.new(App.config).call(milestone_id: milestone_id, auth_token: get_auth_token)
      flash[:notice] = 'Escrow released to contractor (placeholder gateway)'
      routing.redirect "/projects/#{project_id}"
    rescue ReleaseEscrow::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    end

    def handle_bid_submission(routing, project_id)
      require_login!(routing)
      require_email_verified!(routing)

      unless valid_uuid?(project_id)
        flash.now[:error] = 'Invalid project ID format'
        response.status = 404
        return view :project_detail, locals: project_detail_locals(project_id).merge(project: nil, is_owner: false)
      end

      # Validate
      validation = Forms::BidSubmission.new.call(
        project_id: project_id,
        contractor_alias: routing.params['contractor_alias'].to_s.strip,
        encrypted_bid_amount: routing.params['encrypted_bid_amount'].to_s.strip,
        encrypted_proposal_text: routing.params['encrypted_proposal_text'].to_s.strip
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        return view :project_detail, locals: project_detail_locals(project_id)
      end

      validated = validation.to_h

      result = SubmitBid.new(App.config).call(
        project_id: project_id,
        bidder_account_id: @current_account['id'],
        contractor_alias: validated[:contractor_alias],
        encrypted_bid_amount: validated[:encrypted_bid_amount],
        encrypted_proposal_text: validated[:encrypted_proposal_text],
        encrypted_document: routing.params['encrypted_document'].to_s.strip,
        document_file_name: routing.params['document_file_name'].to_s.strip,
        document_file_hash: routing.params['document_file_hash'].to_s.strip,
        auth_token: @current_account['token']
      )

      flash[:notice] = result['status'] == 'updated' ? 'Bid updated successfully' : 'Bid submitted successfully'
      routing.redirect '/projects/my'
    rescue SubmitBid::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      view :project_detail, locals: project_detail_locals(project_id)
    rescue SubmitBid::AuthorizationError => e
      flash.now[:error] = e.message
      response.status = 403
      view :project_detail, locals: project_detail_locals(project_id)
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to submit bid')
      response.status = e.status.to_i
      view :project_detail, locals: project_detail_locals(project_id)
    end

    def handle_award_bid(routing, project_id)
      bid_submission_id = routing.params['bid_submission_id'].to_s
      AwardProjectBid.new(App.config).call(
        project_id: project_id,
        bid_submission_id: bid_submission_id,
        awarded_bid_amount_cents: routing.params['awarded_bid_amount_cents'].to_s.strip,
        auth_token: get_auth_token
      )
      flash[:notice] = 'Bidder selected. Project is now in progress.'
      routing.redirect "/projects/#{project_id}"
    rescue AwardProjectBid::AuthorizationError, AwardProjectBid::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    end

    def handle_request_payment(routing, project_id)
      RequestProjectPayment.new(App.config).call(project_id: project_id, auth_token: get_auth_token)
      flash[:notice] = 'Payment request sent to the project owner.'
      routing.redirect "/projects/#{project_id}"
    rescue RequestProjectPayment::AuthorizationError, RequestProjectPayment::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    end

    def handle_process_payment(routing, project_id)
      ProcessProjectPayment.new(App.config).call(
        project_id: project_id,
        auth_token: get_auth_token
      )
      flash[:notice] = 'Payment sent. Waiting for the freelancer to accept.'
      routing.redirect "/projects/#{project_id}"
    rescue ProcessProjectPayment::AuthorizationError, ProcessProjectPayment::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
    end

    def handle_acknowledge_payment(routing, project_id)
      AcknowledgeProjectPayment.new(App.config).call(project_id: project_id, auth_token: get_auth_token)
      flash[:notice] = 'Payment accepted. Project closed.'
      routing.redirect "/projects/#{project_id}"
    rescue AcknowledgeProjectPayment::AuthorizationError, AcknowledgeProjectPayment::ServiceError => e
      flash[:error] = e.message
      routing.redirect "/projects/#{project_id}"
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

    def api_error_message(error, fallback)
      return error.body['error'].to_s if error.body.is_a?(Hash) && error.body['error']
      return error.body['message'].to_s if error.body.is_a?(Hash) && error.body['message']

      fallback
    end

    def handle_admin_edit_project_get(_routing, project_id)
      locals = project_detail_locals(project_id)
      project = locals[:project]
      unless project && allowed?(project, 'edit')
        response.status = 403
        flash.now[:error] = 'You are not allowed to edit this project'
        return view :project_detail, locals: locals
      end

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
      locals = project_detail_locals(project_id)
      unless locals[:project] && allowed?(locals[:project], 'edit')
        response.status = 403
        flash.now[:error] = 'You are not allowed to edit this project'
        return view :project_detail, locals: locals
      end

      # Validate
      validation = Forms::ProjectEdit.new.call(
        title: routing.params['title'].to_s.strip,
        description: routing.params['description'].to_s.strip,
        required_documents: project_required_documents_from_params(routing.params),
        budget_cents: routing.params['budget_cents'].to_s.strip.empty? ? nil : routing.params['budget_cents'].to_s.strip.to_i,
        state: routing.params['state'].to_s.strip,
        bidding_deadline: normalize_bidding_deadline_param(routing.params['bidding_deadline'])
      )

      if validation.failure?
        flash.now[:error] = validation.errors.to_h.map { |k, v| "#{k} #{v.join(', ')}" }.join('; ')
        response.status = 400
        project = project_detail_locals(project_id)[:project]
        return view :project_edit, locals: { project: project, current_account: @current_account }
      end

      validated = validation.to_h

      UpdateProject.new(App.config).call(
        project_id: project_id,
        title: validated[:title],
        description: validated[:description],
        required_documents: validated[:required_documents],
        budget_cents: validated[:budget_cents].to_s,
        state: validated[:state],
        bidding_deadline: validated[:bidding_deadline],
        auth_token: get_auth_token
      )

      flash[:notice] = 'Project updated successfully'
      routing.redirect "/projects/#{project_id}"
    rescue UpdateProject::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      project = project_detail_locals(project_id)[:project]
      view :project_edit, locals: { project: project, current_account: @current_account }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to update project')
      response.status = e.status.to_i
      project = project_detail_locals(project_id)[:project]
      view :project_edit, locals: { project: project, current_account: @current_account }
    end

    def handle_admin_delete_project(routing, project_id)
      locals = project_detail_locals(project_id)
      unless locals[:project] && allowed?(locals[:project], 'delete')
        flash[:error] = 'You are not allowed to delete this project'
        return routing.redirect "/projects/#{project_id}"
      end

      DeleteProject.new(App.config).call(project_id: project_id, auth_token: get_auth_token)

      flash[:notice] = 'Project deleted successfully'
      routing.redirect '/'
    rescue DeleteProject::NotFoundError
      response.status = 404
      flash[:error] = 'Project not found'
      routing.redirect '/'
    rescue ApiClient::ApiError => e
      flash[:error] = api_error_message(e, 'Failed to delete project')
      routing.redirect "/projects/#{project_id}"
    end

    def project_required_documents_from_params(params)
      params['required_documents'].to_s
                                   .lines
                                   .map(&:strip)
                                   .reject(&:empty?)
    end

    def admin_user_route_not_found!(routing)
      response.status = 404
      routing.halt
    end

    def handle_admin_users_list(routing)
      unless can_manage_accounts?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can view users'
        return routing.redirect '/'
      end

      users = FetchUsers.new(App.config).call(auth_token: get_auth_token)
      view :admin_users_list, locals: { users: users, current_account: @current_account }
    rescue FetchUsers::ServiceError => e
      flash.now[:error] = e.message
      response.status = 500
      view :admin_users_list, locals: { users: [], current_account: @current_account }
    end

    def handle_admin_view_user(routing, user_id)
      unless can_manage_accounts?(@current_account)
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

    def handle_admin_user_roles_get(routing, user_id)
      unless can_manage_accounts?(@current_account)
        response.status = 403
        flash.now[:error] = 'Only admins can manage roles'
        return routing.redirect '/'
      end

      user = FetchUserDetail.new(App.config).call(user_id)
      if same_account?(user, @current_account)
        flash[:error] = 'Admins cannot change their own account role'
        return routing.redirect "/admin/users/#{user_id}"
      end

      roles = AssignSystemRole::VALID_ROLES
      current_role = primary_account_role(user)
      view :admin_user_roles,
           locals: { user: user, roles: roles, current_role: current_role,
                     current_account: @current_account }
    rescue FetchUserDetail::NotFoundError
      response.status = 404
      flash.now[:error] = 'User not found'
      view :admin_user_roles,
           locals: { user: nil, roles: [], current_role: nil, current_account: @current_account }
    rescue FetchUserDetail::ServiceError => e
      response.status = 500
      flash.now[:error] = e.message
      view :admin_user_roles,
           locals: { user: nil, roles: [], current_role: nil, current_account: @current_account }
    end

    def handle_admin_user_roles_post(routing, user_id)
      unless can_manage_accounts?(@current_account)
        response.status = 403
        flash[:error] = 'Only admins can manage roles'
        return routing.redirect '/'
      end

      system_role = routing.params['system_role'].to_s.strip
      if user_id.to_s == @current_account['id'].to_s
        flash[:error] = 'Admins cannot change their own account role'
        return routing.redirect "/admin/users/#{user_id}"
      end

      AssignSystemRole.new(App.config).call(
        account_id: user_id,
        system_role: system_role,
        auth_token: get_auth_token
      )

      flash[:notice] = 'User role updated successfully'
      routing.redirect "/admin/users/#{user_id}/roles"
    rescue AssignSystemRole::ValidationError => e
      flash.now[:error] = e.message
      response.status = 400
      user = FetchUserDetail.new(App.config).call(user_id)
      roles = AssignSystemRole::VALID_ROLES
      current_role = primary_account_role(user)
      view :admin_user_roles,
           locals: { user: user, roles: roles, current_role: current_role,
                     current_account: @current_account }
    rescue ApiClient::ApiError => e
      flash.now[:error] = api_error_message(e, 'Failed to assign role')
      response.status = e.status.to_i
      user = FetchUserDetail.new(App.config).call(user_id)
      roles = AssignSystemRole::VALID_ROLES
      current_role = primary_account_role(user)
      view :admin_user_roles,
           locals: { user: user, roles: roles, current_role: current_role,
                     current_account: @current_account }
    end
  end
end
