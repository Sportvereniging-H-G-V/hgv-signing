# frozen_string_literal: true

RSpec.describe 'Template Builder' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, attachment_count: 3, except_field_types: %w[phone payment]) }

  before do
    sign_in(author)
  end

  context 'when manage template documents' do
    before do
      visit edit_template_path(template)
    end

    it 'replaces the document' do
      doc = find("div[id='documents_container'] div[data-document-uuid='#{template.schema[1]['attachment_uuid']}'")
      doc.click

      initial_count = template.reload.documents.count

      doc.find('.replace-document-button').click
      doc.find('.replace-document-button input[type="file"]', visible: false)
         .attach_file(Rails.root.join('spec/fixtures/sample-image.png'))

      expect(page).to have_content('sample-image', wait: 10)

      # Reload template buiten de expect block om transactie problemen te voorkomen
      template.reload
      expect(template.documents.count).to eq(initial_count + 1)
    end
  end
end
