# frozen_string_literal: true

class DatabaseMailer < ApplicationMailer
  def export_complete(user, export)
    @user = user
    @export = export
    @current_account = user.account

    I18n.with_locale(@current_account.locale) do
      mail(
        to: user.email,
        subject: I18n.t('database_export_complete_subject')
      )
    end
  end

  def export_failed(user, error_message)
    @user = user
    @error_message = error_message
    @current_account = user.account

    I18n.with_locale(@current_account.locale) do
      mail(
        to: user.email,
        subject: I18n.t('database_export_failed_subject')
      )
    end
  end

  def import_complete(user)
    @user = user
    @current_account = user.account

    I18n.with_locale(@current_account.locale) do
      mail(
        to: user.email,
        subject: I18n.t('database_import_complete_subject')
      )
    end
  end

  def import_failed(user, error_message, backup_path)
    @user = user
    @error_message = error_message
    @backup_path = backup_path
    @current_account = user.account

    I18n.with_locale(@current_account.locale) do
      mail(
        to: user.email,
        subject: I18n.t('database_import_failed_subject')
      )
    end
  end
end
