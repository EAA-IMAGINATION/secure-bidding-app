# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'webmock/minitest'
require 'base64'

ENV['MSG_KEY'] ||= Base64.strict_encode64('0123456789abcdef0123456789abcdef')

# Load app
require_relative '../require_app'
require_app

# Make services available at top level for tests
ApiClient = SecureBiddingApp::ApiClient
AuthenticateAccount = SecureBiddingApp::AuthenticateAccount
CheckAccountAvailability = SecureBiddingApp::CheckAccountAvailability
CreateProject = SecureBiddingApp::CreateProject
CurrentSession = SecureBiddingApp::CurrentSession
FetchAccount = SecureBiddingApp::FetchAccount
FetchProjectDetail = SecureBiddingApp::FetchProjectDetail
FetchProjects = SecureBiddingApp::FetchProjects
InitiateRegistration = SecureBiddingApp::InitiateRegistration
RegistrationToken = SecureBiddingApp::RegistrationToken
ResetAccountPassword = SecureBiddingApp::ResetAccountPassword
ResendAccountVerification = SecureBiddingApp::ResendAccountVerification
UpdateAccount = SecureBiddingApp::UpdateAccount
SubmitBid = SecureBiddingApp::SubmitBid
AssignSystemRole = SecureBiddingApp::AssignSystemRole
VerifyRegistration = SecureBiddingApp::CompleteVerification
CompleteVerification = SecureBiddingApp::CompleteVerification
FetchVerificationPreview = SecureBiddingApp::FetchVerificationPreview

module TestHelpers
  include Rack::Test::Methods

  def app
    @app ||= SecureBiddingApp::App
  end
end

Minitest::Spec.include TestHelpers
