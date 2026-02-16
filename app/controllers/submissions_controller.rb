# frozen_string_literal: true

class SubmissionsController < ApplicationController
  before_action :load_template, only: %i[new create]
  authorize_resource :template, only: %i[new create]

  load_and_authorize_resource :submission, only: %i[show destroy]
  before_action only: :create do
    authorize!(:create, Submission)
  end

  def show
    @submission = Submissions.preload_with_pages(@submission)

    unless @submission.submitters.all?(&:completed_at?)
      ActiveRecord::Associations::Preloader.new(
        records: [@submission],
        associations: [submitters: :start_form_submission_events]
      ).call
    end

    render :show, layout: 'plain'
  end

  def new
    authorize!(:new, Submission)
  end

  def create
    # E-mail verzenden is altijd verplicht
    params[:send_email] = '1'

    handle_editor_message_restrictions
    handle_template_message_saving

    submissions = create_submissions_from_params

    Submissions.send_signature_requests(submissions)
    SearchEntries.enqueue_reindex(submissions)

    redirect_to template_path(@template), notice: I18n.t('new_recipients_have_been_added')
  rescue Submissions::CreateFromSubmitters::BaseError => e
    render turbo_stream: turbo_stream.replace(:submitters_error, partial: 'submissions/error',
                                                                 locals: { error: e.message }),
           status: :unprocessable_content
  end

  def destroy
    notice =
      if params[:permanently].in?(['true', true])
        @submission.destroy!

        I18n.t('submission_has_been_removed')
      else
        @submission.update!(archived_at: Time.current)

        I18n.t('submission_has_been_archived')
      end

    redirect_back(fallback_location: @submission.template_id ? template_path(@submission.template) : root_path, notice:)
  end

  private

  def handle_editor_message_restrictions
    return unless current_user.role == User::EDITOR_ROLE

    params.delete(:save_message)
    params.delete(:subject)
    params.delete(:body)
    params.delete(:is_custom_message)
  end

  def handle_template_message_saving
    return if current_user.role == User::EDITOR_ROLE

    save_template_message(@template, params) if params[:save_message] == '1'
    [params.delete(:subject), params.delete(:body)] if params[:is_custom_message] != '1'
  end

  def create_submissions_from_params
    if params[:emails].present?
      create_submissions_from_emails
    else
      create_submissions_from_submitters
    end
  end

  def create_submissions_from_emails
    emails = normalize_emails_param
    Submissions.create_from_emails(template: @template,
                                   user: current_user,
                                   source: :invite,
                                   mark_as_sent: params[:send_email] == '1',
                                   emails: emails,
                                   params: params.merge('send_completed_email' => true))
  end

  def create_submissions_from_submitters
    submissions_attrs = submissions_params[:submission].to_h.values
    submissions_attrs, =
      Submissions::NormalizeParamUtils.normalize_submissions_params!(submissions_attrs, @template)

    Submissions.create_from_submitters(template: @template,
                                       user: current_user,
                                       source: :invite,
                                       submitters_order: 'preserved',
                                       submissions_attrs:,
                                       params: params.merge('send_completed_email' => true))
  end

  def normalize_emails_param
    # Support both old format (emails as string/array) and new format (emails[1][], emails[2][], etc.)
    if params[:emails].is_a?(Hash)
      params[:emails].values.flatten.compact
    else
      params[:emails]
    end
  end

  def save_template_message(template, params)
    template.preferences['request_email_subject'] = params[:subject] if params[:subject].present?
    template.preferences['request_email_body'] = params[:body] if params[:body].present?

    template.save!
  end

  def submissions_params
    params.permit(submission: { submitters: [:uuid, :email, :phone, :name, { values: {} }] })
  end

  def load_template
    @template = Template.accessible_by(current_ability).find(params[:template_id])
  end
end
