require 'spec_helper'

describe Locomotive::Steam::Liquid::Tags::RedirectTo do

  let(:prefix_default)  { false }
  let(:assigns)         { {} }
  let(:current_locale)  { 'en' }
  let(:locales)         { ['en'] }
  let(:services)        { Locomotive::Steam::Services.build_instance }
  let(:site)            { instance_double('Site', locales: locales, default_locale: 'en', prefix_default_locale: prefix_default) }
  let(:context)         { ::Liquid::Context.new(assigns, {}, { services: services, site: site, locale: current_locale }) }

  subject { render_template(source, context) }

  before { allow(services).to receive(:current_site).and_return(site) }

  describe 'parsing' do

    let(:source) { '{% redirect_to %}' }
    it { expect { subject }.to raise_error('Valid syntax: redirect_to <page|page_handle|content_entry|external_url>(, locale: [fr|de|...], with: <page_handle>, permanent: [true|false]') }

  end

  describe 'external url' do

    let(:source) { '{% redirect_to "https://www.locomotivecms.com" %}' }

    it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to https://www.locomotivecms.com (301)') }

    context 'non permanent redirection' do

      let(:source) { '{% redirect_to "https://www.locomotivecms.com", permanent: false %}' }

      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to https://www.locomotivecms.com (302)') }

    end

  end

  describe 'unknown page' do

    let(:source) { '{% redirect_to index %}' }

    before do
      expect(services.page_finder).to receive(:by_handle).with('index').and_return(nil)
    end

    it { is_expected.to eq '' }

  end

  describe 'from a handle of a page' do

    let(:drop)      { Locomotive::Steam::Liquid::Drops::Page.new(page) }
    let(:page)      { liquid_instance_double('Index', title: 'Index', handle: 'index', fullpath: fullpath, localized_attributes: { fullpath: true }, templatized?: false) }
    let(:fullpath)  { { en: 'index', fr: 'index' } }
    let(:source)    { '{% redirect_to index %}' }

    before do
      expect(services.page_finder).to receive(:by_handle).with('index').and_return(page)
      allow(page).to receive(:to_liquid).and_return(drop)
    end

    it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to / (301)') }

    context 'and a different locale' do

      let(:source) { "{% redirect_to index, locale: 'fr' %}" }
      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /fr (301)') }

    end

    context 'the current locale in session is different from the requested locale' do

      let(:current_locale)  { 'fr' }
      let(:locales)         { ['en', 'fr'] }
      let(:source)          { "{% redirect_to index, locale: 'en' %}" }

      before do
        services.url_builder.current_locale = current_locale
      end

      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /en (301)') }

      context 'prefix_default_locale is true' do

        let(:prefix_default) { true }
        it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /en (301)') }

      end

    end

    context 'prefix_default_locale is true' do

      let(:prefix_default) { true }
      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /en (301)') }

    end

  end

  describe 'from a page (drop) itself' do

    let(:assigns)   { { 'about_us' => drop } }
    let(:drop)      { Locomotive::Steam::Liquid::Drops::Page.new(page) }
    let(:page)      { liquid_instance_double('AboutUs', title: 'About us', handle: 'index', localized_attributes: { fullpath: true }, fullpath: fullpath, templatized?: false) }
    let(:fullpath)  { { en: 'about-us', fr: 'a-notre-sujet' } }
    let(:source)    { '{% redirect_to about_us %}' }

    it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /about-us (301)') }

    context 'and a different locale' do

      let(:source) { "{% redirect_to about_us, locale: 'fr' %}" }
      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /fr/a-notre-sujet (301)') }

      context 'locale is a variable' do

        let(:assigns) { { 'about_us' => drop, 'language' => 'fr' } }
        let(:source) { "{% redirect_to about_us, locale: language %}" }

        it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /fr/a-notre-sujet (301)') }

      end

    end

  end

  describe 'from a content entry (drop)' do

    let(:assigns)     { { 'article' => entry_drop } }
    let(:entry_drop)  { Locomotive::Steam::Liquid::Drops::ContentEntry.new(entry) }
    let(:entry)       { liquid_instance_double('Article', localized_attributes: { _slug: true }, _slug: { en: 'hello-world', fr: 'bonjour-monde' }) }
    let(:drop)        { Locomotive::Steam::Liquid::Drops::Page.new(page) }
    let(:page)        { liquid_instance_double('ArticleTemplate', title: 'Template of an article', handle: 'article', localized_attributes: { fullpath: true }, fullpath: { en: 'my-articles/content_type_template', fr: 'mes-articles/content_type_template' }, content_entry: entry_drop.send(:_source), templatized?: true) }
    let(:source)      { '{% redirect_to article %}' }

    before do
      allow(services.repositories.page).to receive(:template_for).with(entry, nil).and_return(page)
      allow(page).to receive(:to_liquid).and_return(drop)
    end

    it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /my-articles/hello-world (301)') }

    context 'and a different locale' do

      let(:source) { "{% redirect_to article, locale: 'fr' %}" }
      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /fr/mes-articles/bonjour-monde (301)') }

    end

    context 'and a different template' do

      let(:archive) { liquid_instance_double('ArticleTemplate', title: 'Template of an article', handle: 'article', localized_attributes: { fullpath: true }, fullpath: { en: 'my-archives/content_type_template', fr: 'mes-archives/content_type_template' }, content_entry: entry_drop.send(:_source), templatized?: true) }
      let(:drop)    { Locomotive::Steam::Liquid::Drops::Page.new(archive) }

      before do
        allow(services.repositories.page).to receive(:template_for).with(entry, 'archives').and_return(archive)
        allow(archive).to receive(:to_liquid).and_return(drop)
      end

      let(:source) { "{% redirect_to article, with: archives, locale: fr %}" }
      it { expect { subject }.to raise_error(Locomotive::Steam::RedirectionException, 'Redirect to /fr/mes-archives/bonjour-monde (301)') }

    end

  end

end
