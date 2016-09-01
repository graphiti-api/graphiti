class ApplicationController < ActionController::Base
  skip_after_action :warn_about_not_setting_whodunnit
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  def current_user
    OpenStruct.new(id: 'testuser')
  end

  def user_for_paper_trail
      nil # disable whodunnit tracking
  end
end
