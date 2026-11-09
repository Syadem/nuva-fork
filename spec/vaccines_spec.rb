# frozen_string_literal: true

RSpec.describe 'The vaccines folder' do
  files             = Dir.glob(NUVA_ROOT.join('vaccines', '*')).sort
  injection_methods = %w[intramuscular subcutaneous intradermal intranasal oral].freeze

  it 'contains vaccines' do
    expect(files).not_to be_empty
  end

  files.each do |file|
    context "for #{Pathname.new(file).relative_path_from(NUVA_ROOT)}" do
      let(:data) { YAML.safe_load_file(file) }

      it 'has a VAC integer ID filename and valid YAML' do
        expect(File.basename(file)).to match(/\AVAC-[1-9]\d*\.yml\z/)
        expect { YAML.safe_load_file(file) }.not_to raise_error
      end

      it 'matches the expected schema' do
        expect(data).to be_a(Hash)

        specific_fields = data['generic'] ? %w[valence_ids immunoglobulin] : %w[generic_vaccine_id injection_methods]
        
        expect(data.keys).to contain_exactly('id', 'name', 'description', 'notes', 'generic', 'created_at', 'updated_at', *specific_fields, 'other_names')

        expect(data['id']).to be_a(Integer)
        expect(data['id']).to be_positive

        expect(File.basename(file)).to eq("VAC-#{data['id']}.yml")

        expect(data['name']).to be_a(String)
        expect(data['name'].strip).not_to be_empty
        expect(data['description']).to(be_a(String).or be_nil)
        expect(data['notes']).to(be_a(String).or be_nil)
        expect(data['generic']).to(be(true).or be(false))
        expect(data['other_names']).to be_a(Array)
        expect(data['other_names']).to all(be_a(String))

        %w[created_at updated_at].each do |field|
          expect(data[field]).to be_a(Integer)
          expect(data[field]).to be >= 0
        end

        expect(data['updated_at']).to be >= data['created_at']

        if data['generic']
          expect(data['immunoglobulin']).to(be(true).or be(false))
          expect(data['valence_ids']).to be_a(Array)
          expect(data['valence_ids']).to all(be_a(Integer))
          expect(data['valence_ids']).to all(be_positive)
          expect(data['valence_ids']).to eq(data['valence_ids'].uniq)
        else
          expect(data['generic_vaccine_id']).to be_a(Integer)
          expect(data['generic_vaccine_id']).to be_positive
          expect(data['injection_methods']).to be_a(Array)
          expect(data['injection_methods']).to all(be_a(String))
          expect(data['injection_methods'] - injection_methods).to be_empty
        end
      end

      it 'references existing valences or a generic vaccine according to its type' do
        if data['generic']
          data['valence_ids'].each do |id|
            valence_file = NUVA_ROOT.join('valences', "VAL-#{id}.yml")

            expect(valence_file).to be_file
            expect(YAML.safe_load_file(valence_file)['id']).to eq(id)
          end
        else
          id = data['generic_vaccine_id']

          expect(id).to be_a(Integer)
          expect(id).to be_positive
          expect(id).not_to eq(data['id'])

          vaccine_file = NUVA_ROOT.join('vaccines', "VAC-#{id}.yml")

          expect(vaccine_file).to be_file

          generic_vaccine = YAML.safe_load_file(vaccine_file)

          expect(generic_vaccine['id']).to eq(id)
          expect(generic_vaccine['generic']).to be(true)
        end
      end

      TRANSLATION_LANGUAGES.each do |language|
        it "has a valid #{language} translation" do
          translation_file = NUVA_ROOT.join('translations', language, 'vaccines', File.basename(file))

          expect(translation_file).to be_file
          translation = YAML.safe_load_file(translation_file)

          expect(translation).to be_a(Hash)
          expect(translation.keys).to contain_exactly('name', 'description')

          if language == 'fr'
            expect(translation['name']).to be_a(String)
            expect(translation['name'].strip).not_to be_empty
          else
            expect(translation['name']).to(be_a(String).or be_nil)
          end
          
          expect(translation['description']).to(be_a(String).or be_nil)
        end
      end
    end
  end

  it 'contains unique IDs' do
    ids = files.map { |file| YAML.safe_load_file(file)['id'] }

    expect(ids).to eq(ids.uniq)
  end
end

RSpec.describe 'The vaccine translations' do
  it 'uses exactly the supported language folders' do
    languages = Dir.children(NUVA_ROOT.join('translations')).sort

    expect(languages).to eq(TRANSLATION_LANGUAGES.sort)
  end

  TRANSLATION_LANGUAGES.each do |language|
    it "contains exactly one #{language} file per vaccine, with no orphan files" do
      directory = NUVA_ROOT.join('translations', language, 'vaccines')

      expect(directory).to be_directory

      base_files = Dir.children(NUVA_ROOT.join('vaccines')).sort

      expect(Dir.children(directory).sort).to eq(base_files)
    end
  end
end
