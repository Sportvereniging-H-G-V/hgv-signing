# frozen_string_literal: true

# WebMock stubs voor externe HTTP requests in tests
RSpec.configure do |config|
  config.before do
    # Clear alle bestaande stubs eerst
    WebMock.reset!

    # Stub voor DownloadUtils - specifiek voor PDF/image downloads
    stub_request(:get, %r{^https?://[^/]+.*\.(pdf|png|jpg|jpeg|gif|doc|docx)$}i)
      .to_return(
        status: 200,
        body: Rails.root.join('spec/fixtures/sample-document.pdf').read,
        headers: { 'Content-Type' => 'application/pdf' }
      )

    # Stub voor DownloadUtils - generieke externe URLs (exclusief localhost)
    stub_request(:get, %r{^https?://(?!127\.0\.0\.1|localhost|0\.0\.0\.0)[^/]+})
      .to_return(
        status: 200,
        body: 'stubbed response',
        headers: { 'Content-Type' => 'application/octet-stream' }
      )

    # Stub voor externe API calls (bijv. eid-easy, timestamp servers, etc.)
    stub_request(:any, %r{^https?://.*\.(com|net|org|io|nl|eu)/})
      .to_return(
        status: 200,
        body: '{}',
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  config.after do
    # Cleanup na elke test
    WebMock.reset!
  end
end
