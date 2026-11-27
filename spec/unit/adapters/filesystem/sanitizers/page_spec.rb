require 'spec_helper'

require_relative '../../../../../lib/locomotive/steam/adapters/filesystem/sanitizer.rb'
require_relative '../../../../../lib/locomotive/steam/adapters/filesystem/sanitizers/page.rb'
require_relative '../../../../../lib/locomotive/steam/errors.rb'

describe Locomotive::Steam::Adapters::Filesystem::Sanitizers::Page do

  # the sections of a page come as JSON from its template (wagon)
  describe 'sections content' do

    let(:page) do
      { sections_content: { en: content }, sections_dropzone_content: { en: nil } }.tap do |page|
        def page.template_path; { en: 'app/views/pages/index.liquid' }; end
      end
    end

    subject { described_class.new.send(:transform_sections_content, page, :en); page[:sections_content][:en] }

    context 'JSON' do
      let(:content) { '{ "header": { "settings": { "title": "Hi" } } }' }
      it { is_expected.to eq('header' => { 'settings' => { 'title' => 'Hi' } }) }
    end

    context 'blank' do
      let(:content) { ' ' }
      it { is_expected.to eq nil }
    end

    context 'invalid JSON' do
      let(:content) { %({\n  "header": {\n    "settings" 1\n}) }
      it 'tells where' do
        expect { subject }.to raise_error(Locomotive::Steam::JsonParsingError) { |error|
          expect(error.template_name).to eq 'app/views/pages/index.liquid'
          expect(error.line_number).to eq 3
        }
      end
    end

  end

end
