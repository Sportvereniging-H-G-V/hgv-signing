# frozen_string_literal: true

module Api
  class AttachmentsController < ApplicationController
    skip_before_action :authenticate_user!
    skip_authorization_check

    def create
      @submitter = Submitter.find_by!(slug: params[:submitter_slug])

      attachment = Submitters.create_attachment!(@submitter, params)

      render json: attachment.as_json(
        only: %i[uuid created_at],
        methods: %i[url filename content_type signed_uuid]
      )
    rescue Submitters::MaliciousFileExtension => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rollbar.error(e) if defined?(Rollbar)

      render json: { error: I18n.t('unable_to_upload_file') }, status: :unprocessable_entity
    end
  end
end
