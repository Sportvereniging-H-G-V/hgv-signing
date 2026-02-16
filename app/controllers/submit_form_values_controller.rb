# frozen_string_literal: true

class SubmitFormValuesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def index
    submitter = find_submitter

    return render json: {} if completed_or_declined?(submitter)
    return render json: {} if submission_inactive?(submitter.submission)

    value = submitter.values[params['field_uuid']]
    after_time = parse_after_param

    attachment = find_attachment_by_value(submitter, value, after_time)
    attachment ||= find_recent_signature_after(submitter, after_time, value)

    update_submitter_value_with_attachment(submitter, value, attachment)

    render json: {
      value: value || attachment&.uuid,
      attachment: attachment&.as_json(only: %i[uuid created_at], methods: %i[url filename content_type])
    }, head: :ok
  end

  private

  def find_submitter
    Submitter.find_by!(slug: params[:submit_form_slug])
  end

  def completed_or_declined?(submitter)
    submitter.completed_at? || submitter.declined_at?
  end

  def submission_inactive?(submission)
    submission.template&.archived_at? || submission.archived_at? || submission.expired?
  end

  # Parse the 'after' parameter; it arrives as a JSON-encoded string timestamp.
  def parse_after_param
    return if params[:after].blank?

    raw = params[:after]

    parsed =
      begin
        Time.zone.parse(JSON.parse(raw).to_s)
      rescue JSON::ParserError, TypeError
        nil
      end

    begin
      parsed || Time.zone.parse(raw)
    rescue ArgumentError
      nil
    end
  end

  def find_attachment_by_value(submitter, value, after_time)
    return if value.blank?

    if after_time
      submitter.attachments.where(created_at: after_time..).find_by(uuid: value)
    else
      submitter.attachments.find_by(uuid: value)
    end
  end

  # For QR-code flow: if value is not set yet, look for the most recent signature
  # attachment created after the given time.
  def find_recent_signature_after(submitter, after_time, current_value)
    return if after_time.blank?

    recent = submitter.attachments
                      .where(created_at: after_time..)
                      .where(name: 'attachments')
                      .order(created_at: :desc)
                      .first

    return unless recent&.content_type&.start_with?('image/')
    return recent if current_value.blank? || current_value == recent.uuid

    recent
  end

  def update_submitter_value_with_attachment(submitter, current_value, attachment)
    return unless attachment
    return if current_value.present?

    submitter.values[params[:field_uuid]] = attachment.uuid
    submitter.save(validate: false)
  end
end
