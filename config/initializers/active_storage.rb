# frozen_string_literal: true

ActiveSupport.on_load(:active_storage_attachment) do
  attribute :uuid, :string, default: -> { SecureRandom.uuid }

  has_many_attached :preview_images

  def signed_uuid
    @signed_uuid ||= ApplicationRecord.signed_id_verifier.generate(uuid, expires_in: 6.hours, purpose: :attachment)
  end
end

# rubocop:disable Metrics/BlockLength
ActiveSupport.on_load(:active_storage_blob) do
  attribute :uuid, :string, default: -> { SecureRandom.uuid }
  attribute :io_data, :string, default: ''

  def self.proxy_url(blob, expires_at: nil, filename: nil, host: nil)
    # Use blob.url which automatically uses the correct route based on resolve_model_to_route config
    # Set ActiveStorage::Current.url_options to ensure correct host/port
    original_url_options = ActiveStorage::Current.url_options
    ActiveStorage::Current.url_options = Docuseal.default_url_options.merge({ host: }.compact)
    begin
      url = blob.url(expires_in: expires_at ? (expires_at.to_i - Time.current.to_i).seconds : nil)
      # If filename is provided and different, append it to the URL
      if filename && filename != blob.filename.to_s
        uri = URI.parse(url)
        uri.path = "#{uri.path}/#{ERB::Util.url_encode(filename)}"
        url = uri.to_s
      end
      url
    ensure
      ActiveStorage::Current.url_options = original_url_options
    end
  end

  def uuid
    super || begin
      new_uuid = SecureRandom.uuid
      update_columns(uuid: new_uuid)
      new_uuid
    end
  end

  def signed_uuid(expires_at: nil)
    expires_at = expires_at.to_i if expires_at

    ApplicationRecord.signed_id_verifier.generate([uuid, 'blob', expires_at].compact)
  end

  def delete
    service.delete(key)
  end
end

ActiveStorage::LogSubscriber.detach_from(:active_storage) if Rails.env.production?

Rails.configuration.to_prepare do
  ActiveStorage::DiskController.after_action do
    response.set_header('cache-control', 'public, max-age=31536000') if action_name == 'show'
  end

  ActiveStorage::Blobs::ProxyController.before_action do
    response.set_header('Access-Control-Allow-Origin', '*')
    response.set_header('Access-Control-Allow-Methods', 'GET')
    response.set_header('Access-Control-Allow-Headers', '*')
    response.set_header('Access-Control-Max-Age', '1728000')
  end

  ActiveStorage::Blobs::RedirectController.before_action do
    response.set_header('Access-Control-Allow-Origin', '*')
    response.set_header('Access-Control-Allow-Methods', 'GET')
    response.set_header('Access-Control-Allow-Headers', '*')
    response.set_header('Access-Control-Max-Age', '1728000')
  end

  ActiveStorage::DirectUploadsController.before_action do
    head :forbidden
  end

  LoadActiveStorageConfigs.call
rescue StandardError => e
  Rails.logger.error(e) unless Rails.env.production?

  nil
end
# rubocop:enable Metrics/BlockLength
