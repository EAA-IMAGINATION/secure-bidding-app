# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Google OAuth CSRF protection' do
  it 'stores state in session when building the Google login URL' do
    get '/auth/login'

    _(last_response.status).must_equal 200
    _(last_request.session['sso_state']).wont_be_nil
    _(last_response.body).must_include "state=#{last_request.session['sso_state']}"
  end

  it 'rejects callback when state does not match session' do
    get '/auth/login'
    session_state = last_request.session['sso_state']

    get '/auth/sso_callback', { state: 'wrong-state', code: 'unused' }

    _(last_response.status).must_equal 302
    _(last_response.location).must_include '/auth/login'
    _(last_request.session['sso_state']).must_be_nil
    _(session_state).wont_equal 'wrong-state'
  end
end

describe 'Security headers' do
  it 'sets a Content-Security-Policy header' do
    get '/auth/login'

    _(last_response.status).must_equal 200
    _(last_response.headers['Content-Security-Policy']).wont_be_nil
    _(last_response.headers['Content-Security-Policy']).must_include "default-src 'self'"
  end

  it 'accepts CSP violation reports' do
    post '/security/report_csp_violation',
         '{"csp-report":{"document-uri":"http://localhost/"}}',
         'CONTENT_TYPE' => 'application/json'

    _(last_response.status).must_equal 204
  end
end
