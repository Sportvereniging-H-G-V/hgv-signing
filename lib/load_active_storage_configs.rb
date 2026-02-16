# frozen_string_literal: true

module LoadActiveStorageConfigs
  STORAGE_YML_PATH = Rails.root.join('config/storage.yml')

  module_function

  def call
    reload unless loaded?
  end

  def loaded?
    @loaded
  end

  def reload
    # Always use disk (local) storage
    return if Rails.env.test?
    return if Rails.env.development?

    service_configurations = ActiveSupport::ConfigurationFile.parse(STORAGE_YML_PATH)
    ActiveStorage::Blob.services = ActiveStorage::Service::Registry.new(service_configurations)
    ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:disk)
  ensure
    @loaded = true
  end
end
