# frozen_string_literal: true

module Docuseal
  URL_CACHE = ActiveSupport::Cache::MemoryStore.new
  PRODUCT_URL = 'https://gitlab.rubenrikk.nl/hgv-hengelo/hgv-signing'
  PRODUCT_EMAIL_URL = ENV.fetch('PRODUCT_EMAIL_URL', PRODUCT_URL)
  ENQUIRIES_URL = PRODUCT_URL
  PRODUCT_NAME = 'HGV Signing'
  DEFAULT_APP_URL = ENV.fetch('APP_URL', 'http://localhost:3000')
  GITHUB_URL = 'https://gitlab.rubenrikk.nl/hgv-hengelo/hgv-signing'
  DISCORD_URL = '/'
  TWITTER_URL = '/'
  TWITTER_HANDLE = '@hgvsigning'
  CHATGPT_URL = PRODUCT_URL
  SUPPORT_EMAIL = 'support@rubenrikk.nl'
  HOST = ENV.fetch('HOST', 'localhost')
  AATL_CERT_NAME = 'docuseal_aatl'
  CONSOLE_URL = '/'
  CLOUD_URL = '/'
  CDN_URL = '/'

  CERTS = JSON.parse(ENV.fetch('CERTS', '{}'))
  TIMESERVER_URL = ENV.fetch('TIMESERVER_URL', nil)
  VERSION_FILE_PATH = Rails.root.join('.version')

  DEFAULT_URL_OPTIONS = {
    host: HOST,
    port: ENV.fetch('PORT', '3000').to_i,
    protocol: ENV['FORCE_SSL'].present? ? 'https' : 'http'
  }.freeze

  module_function

  def version
    @version ||= VERSION_FILE_PATH.read.strip if VERSION_FILE_PATH.exist?
  end

  def multitenant?
    false
  end

  def advanced_formats?
    multitenant?
  end

  def demo?
    false
  end

  def active_storage_public?
    ENV['ACTIVE_STORAGE_PUBLIC'] == 'true'
  end

  def default_pkcs
    return if Docuseal::CERTS['enabled'] == false

    @default_pkcs ||= GenerateCertificate.load_pkcs(Docuseal::CERTS)
  end

  def fulltext_search?
    return @fulltext_search unless @fulltext_search.nil?

    @fulltext_search =
      if SearchEntry.table_exists?
        Docuseal.multitenant? || AccountConfig.exists?(key: :fulltext_search, value: true)
      else
        false
      end
  end

  def enable_pwa?
    true
  end

  def pdf_format
    @pdf_format ||= ENV['PDF_FORMAT'].to_s.downcase
  end

  def trusted_certs
    @trusted_certs ||=
      ENV['TRUSTED_CERTS'].to_s.gsub('\\n', "\n").split("\n\n").map do |base64|
        OpenSSL::X509::Certificate.new(base64)
      end
  end

  def default_url_options
    return DEFAULT_URL_OPTIONS if multitenant?

    @default_url_options ||= begin
      value = EncryptedConfig.find_by(key: EncryptedConfig::APP_URL_KEY)&.value if ENV['APP_URL'].blank?

      if value.blank? && ENV['HOST'].present?
        build_url_options_from_host
      else
        build_url_options_from_url(value || DEFAULT_APP_URL)
      end
    end
  end

  def build_url_options_from_host
    protocol = ENV['FORCE_SSL'].present? ? 'https' : 'http'
    options = { host: HOST, protocol: protocol }
    add_port_if_needed(options, protocol)
    options
  end

  def build_url_options_from_url(url_string)
    url = Addressable::URI.parse(url_string)
    options = { host: url.host, protocol: url.scheme }
    add_port_if_needed(options, url.scheme, url.port)
    options
  end

  def add_port_if_needed(options, protocol, port = nil)
    # Don't add port to URLs when using FORCE_SSL (reverse proxy/tunnel setup)
    return if ENV['FORCE_SSL'].present? && port.nil?

    port ||= ENV.fetch('PORT', nil)&.to_i
    return unless port

    default_port = protocol == 'https' ? 443 : 80
    options[:port] = port if port != default_port
  end

  def product_name
    PRODUCT_NAME
  end

  def refresh_default_url_options!
    @default_url_options = nil
  end
end
