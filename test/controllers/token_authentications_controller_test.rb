# frozen_string_literal: true

require 'test_helper'

class TokenAuthenticationsControllerTest < ActionDispatch::IntegrationTest
  test 'when logging in fails because the email is missing' do
    assert_no_difference ['Session.count'] do
      post token_login_url
    end

    assert_response :not_found
  end

  test 'when logging in fails because the password is missing' do
    assert_no_difference ['Session.count'] do
      post token_login_url, params: { email: 'sterling@isiservice.com' }
    end

    assert_response :unauthorized
  end

  test 'when logging in fails because the email and password do not match' do
    assert_no_difference ['Session.count'] do
      post token_login_url, params: { email: 'sterling@isiservice.com', password: 'secrets' }
    end

    assert_response :unauthorized
  end

  test 'when logging in is successful' do
    assert_difference ['Session.count'] do
      post token_login_url, headers: { 'User-Agent': USER_AGENT }, params: { email: 'sterling@isiservice.com', password: 'secret' }
    end

    assert_response :created

    tokens = JSON.parse(response.body)
    assert tokens['access'].present?
    refute tokens['refresh'].present?
  end

  test 'when logging out without a session' do
    delete token_logout_url

    assert_response :unauthorized
    assert_equal 'Token is not found', JSON.parse(response.body)['errors'].first['detail']
  end

  test 'when logging out successfully the Session invalidated fields are updated' do
    Timecop.freeze

    mallory_archer = users(:mallory_archer)

    token(mallory_archer)

    Timecop.travel 30.seconds.from_now

    refute mallory_archer.sessions.first.invalidated?

    delete token_logout_url, headers: @headers

    assert_response :no_content
    assert mallory_archer.sessions.first.invalidated?
    assert mallory_archer.sessions.first.invalidated_by.present?
  end

  test 'when logging out successfully with the post method' do
    Timecop.freeze

    mallory_archer = users(:mallory_archer)

    token(mallory_archer)

    Timecop.travel 30.seconds.from_now

    refute mallory_archer.sessions.first.invalidated?

    post token_logout_url, headers: @headers

    assert_response :no_content
    assert mallory_archer.sessions.first.invalidated?
    assert mallory_archer.sessions.first.invalidated_by.present?
  end

  test 'when access to a protected resource with token authentication is forbidden' do
    Timecop.freeze

    token(users(:sterling_archer))

    Timecop.travel 30.seconds.from_now

    get api_v1_protected_users_url, headers: @headers

    assert_response :forbidden
    assert_equal 'You are forbidden from performing this action', JSON.parse(response.body)['errors'].first['detail']
  end

  test 'when accessing a protected resource with token authentication is permitted' do
    Timecop.freeze

    token(users(:some_administrator))

    Timecop.travel 30.seconds.from_now

    get api_v1_protected_users_url, headers: @headers

    assert_response :ok
    assert_equal 5, JSON.parse(response.body)['data'].length
  end
end