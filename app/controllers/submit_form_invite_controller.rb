# frozen_string_literal: true

class SubmitFormInviteController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def create
    submitter = Submitter.find_by!(slug: params[:submit_form_slug])

    return head :unprocessable_content unless can_invite?(submitter)

    invite_submitters = filter_invite_submitters(submitter, 'invite_by_uuid')
    optional_invite_submitters = filter_invite_submitters(submitter, 'optional_invite_by_uuid')

    return head :unprocessable_content unless validate_optional_invites(submitter, optional_invite_submitters)

    # Include required signers of hidden optional signers (e.g. when person is >= 16 the
    # 2nd signer is hidden, but the 3rd and 4th signers that depend on it must still be invited)
    cascaded_invite_submitters = find_cascaded_invite_submitters(submitter, optional_invite_submitters)
    invite_submitters += cascaded_invite_submitters

    create_invited_submitters(submitter, invite_submitters, optional_invite_submitters)

    submitter.submission.submitters.reload

    complete_submission_if_all_invited(submitter, invite_submitters)
  end

  private

  def can_invite?(submitter)
    !submitter.declined_at? &&
      !submitter.completed_at? &&
      !submitter.submission.archived_at? &&
      !submitter.submission.expired? &&
      !submitter.submission.template&.archived_at?
  end

  def filter_invite_submitters(submitter, key = 'invite_by_uuid')
    (submitter.submission.template_submitters || submitter.submission.template.submitters).select do |s|
      s[key] == submitter.uuid && submitter.submission.submitters.none? { |e| e.uuid == s['uuid'] }
    end
  end

  def submitters_attributes
    params.require(:submission).permit(submitters: [%i[uuid email]]).fetch(:submitters, [])
  end

  def validate_optional_invites(submitter, optional_invite_submitters)
    optional_invite_submitters.each do |item|
      attrs = submitters_attributes.find { |e| e[:uuid] == item['uuid'] }
      next unless attrs

      return false if under_16_required?(submitter, item) && attrs[:email].blank?
    end

    true
  end

  def create_invited_submitters(submitter, invite_submitters, optional_invite_submitters)
    ApplicationRecord.transaction do
      (invite_submitters + optional_invite_submitters).each do |item|
        create_submitter_if_valid(submitter, item)
      end

      submitter.submission.update!(submitters_order: :preserved)
    end
  end

  def create_submitter_if_valid(submitter, item)
    attrs = submitters_attributes.find { |e| e[:uuid] == item['uuid'] }

    return if attrs.blank? || attrs[:email].blank?

    submitter.submission.submitters.create!(**attrs, account_id: submitter.account_id)

    SubmissionEvents.create_with_tracking_data(submitter, 'invite_party', request, { uuid: submitter.uuid })
  end

  def complete_submission_if_all_invited(submitter, invite_submitters)
    if invite_submitters.all? { |s| submitter.submission.submitters.any? { |e| e.uuid == s['uuid'] } }
      Submitters::SubmitValues.call(submitter, ActionController::Parameters.new(completed: 'true'), request)

      head :ok
    else
      head :unprocessable_content
    end
  end

  def find_cascaded_invite_submitters(submitter, optional_invite_submitters)
    # Detect optional signers that were hidden in the form (their UUID was not submitted at all)
    # This happens when conditions prevent them from showing, e.g. age >= 16 hides the parent/guardian
    submitted_uuids = submitters_attributes.pluck(:uuid)
    hidden_optional_uuids = optional_invite_submitters
                            .reject { |item| submitted_uuids.include?(item['uuid']) }
                            .pluck('uuid')

    return [] if hidden_optional_uuids.empty?

    # Return required signers whose invite chain goes through a hidden optional signer
    all_template_subs = submitter.submission.template_submitters || submitter.submission.template.submitters
    all_template_subs.select do |s|
      hidden_optional_uuids.include?(s['invite_by_uuid']) &&
        submitter.submission.submitters.none? { |e| e.uuid == s['uuid'] }
    end
  end

  def under_16_required?(submitter, optional_invite_submitter)
    # Get all values from the current submitter (first party)
    all_submitters_values = submitter.submission.submitters.reduce({}) { |acc, sub| acc.merge(sub.values) }
    all_submitters_values = all_submitters_values.merge(submitter.values)

    # Get template fields to find the birthdate field
    template_fields = submitter.submission.template_fields || submitter.submission.template.fields

    # Find birthdate field by looking for age_less_than conditions with value 16
    birthdate_field_uuid = find_birthdate_field_uuid(optional_invite_submitter, template_fields)

    return false unless birthdate_field_uuid

    # Get birthdate value
    birthdate_value = all_submitters_values[birthdate_field_uuid]
    return false if birthdate_value.blank?

    # Calculate age
    age = calculate_age_from_date(birthdate_value)
    return false if age.nil?

    age < 16
  end

  def find_birthdate_field_uuid(optional_invite_submitter, template_fields)
    # Check fields of the optional invite submitter
    submitter_fields = template_fields.select { |f| f['submitter_uuid'] == optional_invite_submitter['uuid'] }

    submitter_fields.each do |field|
      next if field['conditions'].blank?

      field['conditions'].each do |condition|
        return condition['field_uuid'] if condition['action'] == 'age_less_than' && condition['value'].to_i == 16
      end
    end

    # Also check if the submitter itself has conditions
    return nil if optional_invite_submitter['conditions'].blank?

    optional_invite_submitter['conditions'].each do |condition|
      return condition['field_uuid'] if condition['action'] == 'age_less_than' && condition['value'].to_i == 16
    end

    nil
  end

  def calculate_age_from_date(date_string)
    return nil if date_string.blank?

    birth_date = Date.parse(date_string.to_s)
    today = Date.current
    age = today.year - birth_date.year
    age -= 1 if today < birth_date + age.years

    age
  rescue StandardError
    nil
  end
end
