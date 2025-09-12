class Api::V1::Profile::MfaController < Api::BaseController
  before_action :set_user
  before_action :check_mfa_feature_available
  before_action :set_mfa_service
  before_action :check_mfa_enabled, only: [:destroy, :backup_codes]
  before_action :check_mfa_disabled, only: [:create, :verify]
  before_action :validate_otp, only: [:verify, :backup_codes, :destroy]
  before_action :validate_password, only: [:destroy]

  def show; end

  def create
    @backup_codes = @mfa_service.enable_two_factor_with_backup_codes!
  end

  def verify
    @mfa_service.verify_and_activate!
  end

  def destroy
    @mfa_service.disable_two_factor!
  end

  def backup_codes
    @backup_codes = @mfa_service.generate_backup_codes!
  end

  private

  def set_user
    @user = current_user
  end

  def set_mfa_service
    @mfa_service = Mfa::ManagementService.new(user: @user)
  end

  def check_mfa_enabled
    render_could_not_create_error(I18n.t('errors.mfa.not_enabled')) unless @user.mfa_enabled?
  end

  def check_mfa_feature_available
    return if Chatwoot.mfa_enabled?

    render json: {
      error: I18n.t('errors.mfa.feature_unavailable',
                    default: 'MFA feature is not available. Please configure encryption keys.')
    }, status: :forbidden
  end

  def check_mfa_disabled
    render_could_not_create_error(I18n.t('errors.mfa.already_enabled')) if @user.mfa_enabled?
  end

  def validate_otp
    authenticated = Mfa::AuthenticationService.new(
      user: @user,
      otp_code: mfa_params[:otp_code]
    ).authenticate

    return if authenticated

    render_could_not_create_error(I18n.t('errors.mfa.invalid_code'))
  end

  def validate_password
    return if @user.valid_password?(mfa_params[:password])

    render_could_not_create_error(I18n.t('errors.mfa.invalid_credentials'))
  end

  def mfa_params
    params.permit(:otp_code, :password)
  end
end
