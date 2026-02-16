# frozen_string_literal: true

require 'docuseal'

module Submitters
  module FormConfigs
    DEFAULT_KEYS = [AccountConfig::FORM_COMPLETED_BUTTON_KEY,
                    AccountConfig::FORM_COMPLETED_MESSAGE_KEY,
                    AccountConfig::FORM_WITH_CONFETTI_KEY,
                    # FORM_PREFILL_SIGNATURE_KEY removed - functionality disabled
                    AccountConfig::WITH_SIGNATURE_ID,
                    AccountConfig::ALLOW_TO_DECLINE_KEY,
                    # ENFORCE_SIGNING_ORDER_KEY removed - always enabled by default
                    AccountConfig::REQUIRE_SIGNING_REASON_KEY,
                    AccountConfig::REUSE_SIGNATURE_KEY,
                    AccountConfig::ALLOW_TO_PARTIAL_DOWNLOAD_KEY,
                    AccountConfig::ALLOW_TYPED_SIGNATURE,
                    AccountConfig::WITH_SUBMITTER_TIMEZONE_KEY,
                    AccountConfig::WITH_SIGNATURE_ID_REASON_KEY,
                    *(Docuseal.multitenant? ? [] : [AccountConfig::POLICY_LINKS_KEY])].freeze

    module_function

    def call(submitter, keys = [])
      configs = submitter.submission.account.account_configs.where(key: DEFAULT_KEYS + keys)

      completed_button = find_safe_value(configs, AccountConfig::FORM_COMPLETED_BUTTON_KEY) || {}
      completed_message = find_safe_value(configs, AccountConfig::FORM_COMPLETED_MESSAGE_KEY) || {}
      # Typed signatures are always enabled by default
      with_typed_signature = find_safe_value(configs, AccountConfig::ALLOW_TYPED_SIGNATURE) != false
      with_confetti = find_safe_value(configs, AccountConfig::FORM_WITH_CONFETTI_KEY) != false
      # Prefill signature is disabled - functionality removed
      prefill_signature = false
      reuse_signature = find_safe_value(configs, AccountConfig::REUSE_SIGNATURE_KEY) != false
      # Decline is always enabled by default
      with_decline = find_safe_value(configs, AccountConfig::ALLOW_TO_DECLINE_KEY) != false
      with_partial_download = find_safe_value(configs, AccountConfig::ALLOW_TO_PARTIAL_DOWNLOAD_KEY) != false
      # Signature ID is always enabled by default
      with_signature_id = find_safe_value(configs, AccountConfig::WITH_SIGNATURE_ID) != false
      # Signing reason is disabled by default
      require_signing_reason = find_safe_value(configs, AccountConfig::REQUIRE_SIGNING_REASON_KEY) == true
      # Enforce signing order is always enabled by default
      enforce_signing_order = true # find_safe_value(configs, AccountConfig::ENFORCE_SIGNING_ORDER_KEY) != false
      with_submitter_timezone = find_safe_value(configs, AccountConfig::WITH_SUBMITTER_TIMEZONE_KEY) == true
      with_signature_id_reason = find_safe_value(configs, AccountConfig::WITH_SIGNATURE_ID_REASON_KEY) != false
      policy_links = find_safe_value(configs, AccountConfig::POLICY_LINKS_KEY)

      attrs = { completed_button:, with_typed_signature:, with_confetti:,
                reuse_signature:, with_decline:, with_partial_download:,
                policy_links:, enforce_signing_order:, completed_message:,
                require_signing_reason:, prefill_signature:, with_submitter_timezone:,
                with_signature_id_reason:, with_signature_id: }

      keys.each do |key|
        attrs[key.to_sym] = configs.find { |e| e.key == key.to_s }&.value
      end

      attrs
    end

    def find_safe_value(configs, key)
      configs.find { |e| e.key == key }&.value
    end
  end
end
