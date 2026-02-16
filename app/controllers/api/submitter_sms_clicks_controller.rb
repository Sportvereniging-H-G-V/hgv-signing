# frozen_string_literal: true

module Api
  class SubmitterSmsClicksController < ApplicationController
    skip_before_action :authenticate_user!
    skip_authorization_check

    def create
      @submitter = Submitter.find_by!(slug: params[:submitter_slug])

      if params[:c] == SubmissionEvents.build_tracking_param(@submitter, 'click_sms')
        SubmissionEvents.create_with_tracking_data(@submitter, 'click_sms', request)
      end

      render json: {}
    end
  end
end
