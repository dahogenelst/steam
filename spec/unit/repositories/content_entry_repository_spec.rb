require 'spec_helper'

require_relative '../../../lib/locomotive/steam/adapters/filesystem.rb'

describe Locomotive::Steam::ContentEntryRepository do

  let(:_fields) { instance_double('Fields', selects: [], belongs_to: [], many_to_many: [], dates_and_date_times: []) }
  let(:type)    { build_content_type('Articles', label_field_name: :title, localized_names: [:title], fields: _fields, fields_by_name: { title: instance_double('Field', name: :title, type: :string) }, fields_with_default: []) }
  let(:entries) { [{ content_type_id: 1, _position: 0, _label: 'Update #1', title: { fr: 'Mise a jour #1' }, text: { en: 'added some free stuff', fr: 'phrase FR' }, date: '2009/05/12', category: 'General' }] }
  let(:locale)  { :en }
  let(:site)    { instance_double('Site', _id: 1, default_locale: :en, locales: %i(en fr)) }
  let(:adapter) { Locomotive::Steam::FilesystemAdapter.new(nil) }

  let(:content_type_repository) { instance_double('ContentTypeRepository') }
  let(:repository)  { described_class.new(adapter, site, locale, content_type_repository) }

  before do
    allow(adapter).to receive(:collection).and_return(entries)
    adapter.cache = NoCacheStore.new
  end

  describe '#all' do

    let(:conditions) { nil }

    subject { repository.with(type).all(conditions) }

    it { expect(subject.size).to eq 1 }

    describe 'first element' do

      subject { repository.with(type).all(conditions).first }

      it { expect(subject.class).to eq Locomotive::Steam::ContentEntry }
      it { expect(subject._label.translations).to eq('en' => 'Update #1', 'fr' => 'Mise a jour #1') }
      it { expect(subject._slug.translations).to eq('en' => 'update-number-1', 'fr' => 'mise-a-jour-number-1') }
      it { expect(subject.title.translations).to eq('en' => 'Update #1', 'fr' => 'Mise a jour #1') }
      it { expect(subject.content_type).to eq type }

    end

    describe 'including also the not visible entries' do

      let(:entries) { [
        { content_type_id: 1, _position: 0, _label: 'Update #1', title: { fr: 'Mise a jour #1' }, text: { en: 'added some free stuff', fr: 'phrase FR' }, date: '2009/05/12', category: 'General' },
        { content_type_id: 1, _position: 1, _label: 'Update #2 [HIDDEN]', title: { fr: 'Mise a jour #1' }, text: { en: 'added some free stuff', fr: 'phrase FR' }, date: '2009/05/12', category: 'General', _visible: false }
      ] }

      let(:conditions) { { _visible: nil } }

      it { expect(subject.size).to eq 2 }

    end

  end

  describe '#build' do

    let(:attributes) { { title: 'Hello world' } }
    subject { repository.with(type).build(attributes) }

    it { expect(subject.title[:en]).to eq 'Hello world' }
    it { expect(subject.content_type).to eq type }

  end

  describe '#exists?' do

    let(:conditions) { {} }
    subject { repository.with(type).exists?(conditions) }

    it { expect(subject).to eq true }

    context 'more specific conditions' do

      let(:conditions) { { '_slug' => 'update-number-1' } }
      it { expect(subject).to eq true }

    end

    context 'conditions which do match any entries' do

      let(:conditions) { { '_slug' => 'foo' } }
      it { expect(subject).to eq false }

    end

  end

  describe '#by_slug' do

    let(:slug) { nil }
    subject { repository.with(type).by_slug(slug) }

    it { is_expected.to eq nil }

    context 'existing slug' do
      let(:slug) { 'update-number-1' }
      it { expect(subject.title.translations).to eq('en' => 'Update #1', 'fr' => 'Mise a jour #1') }
    end

  end

  describe '#value_for' do

    let(:entry)       { nil }
    let(:conditions)  { {} }
    let(:name)        { :title }
    subject { repository.with(type).value_for(entry, name, conditions) }

    it { is_expected.to eq nil }

    context 'existing entry' do
      let(:entry) { instance_double('Entry', title: 'Hello world') }
      it { is_expected.to eq 'Hello world' }

      context 'unknown field' do
        let(:name) { :authors }
        it { is_expected.to eq nil }
      end
    end

    context 'with a has_many field' do
      let(:type) { build_content_type('Articles', label_field_name: :title, localized_names: [:title], fields: _fields, fields_by_name: { articles: instance_double('Field', type: :has_many) }, fields_with_default: []) }
      let(:proxy_repository) { repository.dup }
      let(:entry) { instance_double('Entry', articles: proxy_repository) }
      let(:name) { :articles }
      let(:conditions) { { published: true } }

      it 'does not modify the local conditions of the initial proxy repository' do
        expect(subject.local_conditions).to eq(content_type_id: 1, published: true)
        expect(proxy_repository.local_conditions).to eq(content_type_id: 1)
      end

    end

  end

  describe '#next or #previous' do

    let(:direction) { 'asc' }
    let(:type)      { build_content_type('Articles', order_by: { _position: direction }, label_field_name: :title, localized_names: [:title], fields: _fields, fields_by_name: { title: instance_double('Field', name: :title, type: :string) }, fields_with_default: []) }
    let(:entry)     { nil }
    let(:entries) do
      [
        { content_type_id: 1, _position: 0, _label: 'Update #1', title: { fr: 'Mise a jour #1' }, text: { en: 'added some free stuff', fr: 'phrase FR' }, date: '2009/05/12', category: 'General' },
        { content_type_id: 1, _position: 1, _label: 'Update #2', title: { fr: 'Mise a jour #2' }, text: { en: 'bla bla', fr: 'blabbla' }, date: '2009/05/12', category: 'General' },
        { content_type_id: 1, _position: 2, _label: 'Update #3', title: { fr: 'Mise a jour #3' }, text: { en: 'bla bla', fr: 'blabbla' }, date: '2009/05/12', category: 'General' },
        { content_type_id: 1, _position: 3, _label: 'Update #4', title: { fr: 'Mise a jour #4' }, text: { en: 'bla bla', fr: 'blabbla' }, date: '2009/05/12', category: 'General' }
      ]
    end

    describe '#next' do

      subject { repository.next(entry) }

      it { is_expected.to eq nil }

      context 'being last' do

        let(:entry) { instance_double('Entry', content_type: type, _position: 3) }
        it { is_expected.to eq nil }

      end

      context 'being middle' do

        let(:entry) { instance_double('Entry', content_type: type, _position: 0) }
        it { expect(subject._position).to eq 1 }

        describe 'another example' do

          let(:entry) { instance_double('Entry', content_type: type, _position: 1) }
          it { expect(subject._position).to eq 2 }

        end

        context 'changing direction' do

          let(:direction) { 'desc' }
          let(:entry) { instance_double('Entry', content_type: type, _position: 2) }
          it { expect(subject._position).to eq 1 }

        end

      end

    end

    describe '#previous' do

      subject { repository.previous(entry) }

      it { is_expected.to eq nil }

      context 'being first' do

        let(:entry) { instance_double('Entry', content_type: type, _position: 0) }
        it { is_expected.to eq nil }

      end

      context 'being middle' do

        let(:entry) { instance_double('Entry', content_type: type, _position: 1) }
        it { expect(subject._position).to eq 0 }

        describe 'another example' do

          let(:entry) { instance_double('Entry', content_type: type, _position: 2) }
          it { expect(subject._position).to eq 1 }

        end

        context 'changing direction' do

          let(:direction) { 'desc' }
          let(:entry) { instance_double('Entry', content_type: type, _position: 2) }
          it { expect(subject._position).to eq 3 }

        end

      end

    end

  end

  describe '#group_by_select_option' do

    let(:type) { nil }
    let(:name) { nil }

    subject { repository.with(type).group_by_select_option(name) }

    it { is_expected.to eq({}) }

    context 'select field' do

      let(:fields) do
        {
          title:    instance_double('TitleField', name: :title, type: :string),
          category: instance_double('SelectField', name: :category, type: :select, localized: true, select_options: [])
        }
      end
      let(:type) { build_content_type('Articles', order_by: '_position asc', label_field_name: :title, localized_names: [:title, :category_id], fields: _fields, fields_by_name: fields, fields_with_default: []) }
      let(:name) { :category }

      let(:options) {
        [
          instance_double('SelectOption1', _id: '0', name: instance_double('I18nField', :[] => 'cooking', translations: { 'en' => 'cooking' })),
          instance_double('SelectOption2', _id: '1', name: instance_double('I18nField', :[] => 'wine', translations: { 'en' => 'wine' })),
          instance_double('SelectOption3', _id: '2', name: instance_double('I18nField', :[] => 'bread', translations: { 'en' => 'bread' }))
        ]
      }

      let(:entries) do
        [
          { content_type_id: 1, _position: 0, _label: 'Recipe #1', category_id: { 'en' => '0' } },
          { content_type_id: 1, _position: 1, _label: 'Recipe #2', category_id: { 'en' => '2' } },
          { content_type_id: 1, _position: 2, _label: 'Recipe #3', category_id: { 'en' => '2' } },
          { content_type_id: 1, _position: 3, _label: 'Recipe #4', category_id: { 'en' => '42' } } # unknown category
        ]
      end

      before {
        allow(content_type_repository).to receive(:select_options).and_return(options)
        %w(cooking wine bread).each_with_index do |name, position|
          allow(fields[:category].select_options).to receive(:by_id_or_name).with(position.to_s).and_return(options.at(position))
        end
        allow(fields[:category].select_options).to receive(:by_id_or_name).with('42').and_return(nil)
      }

      it { expect(subject.size).to eq 4 }
      it { expect(subject.map { |h| h[:name] }).to eq ['cooking', 'wine', 'bread', nil] }
      it { expect(subject.map { |h| h[:entries].size }).to eq [1, 0, 2, 1] }

    end

  end

  describe 'belongs_to' do

    let(:field)   { instance_double('Field', name: :author, type: :belongs_to, association_options: { target_id: 2 }) }
    let(:type)    { build_content_type('Articles', label_field_name: :title, association_fields: [field], fields_with_default: []) }
    let(:entries) { [{ content_type_id: 1, title: 'Hello world', author_id: 'john-doe' }] }
    let(:other_type)    { build_content_type('Authors', _id: 2, label_field_name: :name, fields: _fields, fields_by_name: { name: instance_double('Field', name: :name, type: :string) }, fields_with_default: []) }
    let(:other_entries) { [{ content_type_id: 2, _id: 'john-doe', name: 'John Doe' }] }

    let(:type_repository) { instance_double('ArticleBelongsToRepository', selects: [], belongs_to: [], many_to_many: [], dates_and_date_times: []) }

    before do
      allow(type).to receive(:fields).and_return(type_repository)
      allow(content_type_repository).to receive(:find).with(2).and_return(other_type)
    end

    subject { repository.with(type).by_slug('hello-world') }

    it { expect(subject.author.class).to eq Locomotive::Steam::Models::BelongsToAssociation }

    it 'calls the new repository to fetch the target entity' do
      author = subject.author
      allow(adapter).to receive(:collection).and_return(other_entries)
      expect(author.name).to eq 'John Doe'
    end

  end

  describe 'has_many' do

    let(:field)   { instance_double('Field', name: :articles, type: :has_many, association_options: { target_id: 2, inverse_of: :author, order_by: 'position_in_author' }) }
    let(:type)    { build_content_type('Authors', label_field_name: :name, association_fields: [field], fields_with_default: []) }
    let(:entries) { [{ content_type_id: 1, _id: 'john-doe', name: 'John Doe' }] }
    let(:other_type) { build_content_type('Articles', _id: 2, label_field_name: :title, fields: _fields, fields_by_name: { name: instance_double('Field', name: :title, type: :string) }, fields_with_default: []) }
    let(:other_entries) {
        [
          { content_type_id: 2, _id: 'hello-world', title: 'Hello world', author_id: 'john-doe', position_in_author: 2 },
          { content_type_id: 2, _id: 'lorem-ipsum', title: 'Lorem ipsum', author_id: 'john-doe', position_in_author: 1 },
          { content_type_id: 2, _id: 'lost', title: 'Lost', author_id: 'jane-doe' },
        ]
      }

    let(:type_repository) { instance_double('AuthorRepository', selects: [], belongs_to: [], many_to_many: [], dates_and_date_times: []) }

    before do
      allow(type).to receive(:fields).and_return(type_repository)
      allow(content_type_repository).to receive(:find).with(2).and_return(other_type)
    end

    subject { repository.with(type).by_slug('john-doe') }

    it { expect(subject.articles.class).to eq Locomotive::Steam::Models::HasManyAssociation }

    it 'calls the new repository to fetch the target entities' do
      articles = subject.articles
      allow(adapter).to receive(:collection).and_return(other_entries)
      expect(articles.all.map(&:title)).to eq ['Lorem ipsum', 'Hello world']
    end

  end

  describe 'many_to_many' do

    let(:field)   { instance_double('Field', name: :articles, type: :many_to_many, association_options: { target_id: 2, inverse_of: :authors }) }
    let(:type)    { build_content_type('Authors', label_field_name: :name, association_fields: [field], fields: _fields, fields_with_default: []) }
    let(:entries) { [{ content_type_id: 1, _id: 1, name: 'John Doe', article_ids: ['hello-world', 'lorem-ipsum'] }] }
    let(:other_type)    { build_content_type('Articles', _id: 2, label_field_name: :title, fields: _fields, fields_by_name: { name: instance_double('Field', name: :title, type: :string) }, fields_with_default: []) }
    let(:other_entries) {
        [
          { content_type_id: 2, _id: 'hello-world', title: 'Hello world', author_id: 'john-doe', position_in_author: 2 },
          { content_type_id: 2, _id: 'lorem-ipsum', title: 'Lorem ipsum', author_id: 'john-doe', position_in_author: 1 },
          { content_type_id: 2, _id: 'lost', title: 'Lost', author_id: 'jane-doe' },
        ]
      }

    let(:type_repository) { instance_double('AuthorRepository', selects: [], belongs_to: [], many_to_many: [], dates_and_date_times: []) }

    before do
      allow(type).to receive(:fields).and_return(type_repository)
      allow(content_type_repository).to receive(:find).with(2).and_return(other_type)
    end

    subject { repository.with(type).by_slug('john-doe') }

    it { expect(subject.articles.class).to eq Locomotive::Steam::Models::ManyToManyAssociation }

    it 'calls the new repository to fetch the target entities' do
      articles = subject.articles
      allow(adapter).to receive(:collection).and_return(other_entries)
      expect(articles.all.map(&:title)).to eq ['Hello world', 'Lorem ipsum']
    end

  end

  describe '#conditions_without_order_by' do

    let(:conditions) { {} }

    subject { repository.with(type).send(:conditions_without_order_by, conditions) }

    it { is_expected.to eq([{ _visible: true, content_type_id: 1 }, nil]) }

    context 'select fields' do

      let(:value)       { 'CMS' }
      let(:option)      { instance_double('Option', _id: 42)}
      let(:options)     { instance_double('OptionRepository', by_name: option, :'locale=' => nil) }
      let(:field)       { instance_double('SelectField', name: 'category', persisted_name: 'category_id', select_options: options) }
      let(:_fields)     { instance_double('Fields', selects: [field], belongs_to: [], many_to_many: [], dates_and_date_times: []) }
      let(:conditions)  { { 'category' => value } }

      it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'category_id' => 42 }, nil]) }

    end

    context 'date fields' do

      let(:value)       { '2009/09/10' }
      let(:field)       { instance_double('DateField', name: 'launched_at', persisted_name: 'launched_at', type: :date) }
      let(:_fields)     { instance_double('Fields', selects: [], belongs_to: [], many_to_many: [], dates_and_date_times: [field]) }
      let(:conditions)  { { 'launched_at' => value } }

      it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'launched_at' => Date.parse('2009/09/10') }, nil]) }

    end

    context 'date time fields' do

      before { Time.zone = 'Paris' }

      let(:value)       { '2007/06/29 21:15:00' }
      let(:field)       { instance_double('DateField', name: 'launched_at', persisted_name: 'launched_at', type: :date_time) }
      let(:_fields)     { instance_double('Fields', selects: [], belongs_to: [], many_to_many: [], dates_and_date_times: [field]) }
      let(:conditions)  { { 'launched_at' => value } }

      it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'launched_at' => Time.zone.parse('2007/06/29 21:15:00').to_datetime }, nil]) }

    end

    context 'belongs_to fields' do

      let(:value)       { 42 }
      let(:field)       { instance_double('BelongsToField', name: 'person', persisted_name: 'person_id', target_id: '42') }
      let(:_fields)     { instance_double('Fields', selects: [], belongs_to: [field], many_to_many: [], dates_and_date_times: []) }
      let(:conditions)  { { 'person' => value } }

      it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'person_id' => 42 }, nil]) }

      context 'the target value is a content entry' do

        let(:value) { instance_double('TargetContentEntry', _id: 1) }

        it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'person_id' => 1 }, nil]) }

      end

      context 'the target is a hash' do

        let(:value) { { '_id' => 42 } }

        it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'person_id' => 42 }, nil]) }

      end

      context 'the target value is an arry of content entry' do

        let(:value) { [instance_double('TargetContentEntry', _id: 1), instance_double('TargetContentEntry', _id: 2)] }
        let(:conditions)  { { 'person.in' => value } }

        it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'person_id.in' => [1, 2] }, nil]) }

      end

      context 'testing a nil value (field.ne => nil)' do

        let(:conditions)  { { 'person.ne' => nil } }
        it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'person_id.ne' => nil }, nil]) }

      end

    end

    context 'many_to_many fields' do

      let(:value)       { 42 }
      let(:field)       { instance_double('ManyToManyField', name: 'tags', persisted_name: 'tag_ids', target_id: '42') }
      let(:_fields)     { instance_double('Fields', selects: [], belongs_to: [], many_to_many: [field], dates_and_date_times: []) }
      let(:conditions)  { { 'tags.in' => value } }

      it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'tag_ids.in' => [42] }, nil]) }

      context 'the target value is a content entry' do

        let(:value) { [instance_double('TargetContentEntry', _id: 1), 42] }

        it { is_expected.to eq([{ _visible: true, content_type_id: 1, 'tag_ids.in' => [1, 42] }, nil]) }

      end

    end

  end

  def build_content_type(name, attributes = {})
    instance_double(name,
      {
        _id:                    1,
        slug:                   name.to_s.downcase,
        order_by:               nil,
        localized_names:        [],
        association_fields:     [],
        fields_by_name:         {}
      }.merge(attributes))
  end

end
