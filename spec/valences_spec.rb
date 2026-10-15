# frozen_string_literal: true

RSpec.describe 'The valences folder' do
  files = Dir.glob(NUVA_ROOT.join('valences', '*')).sort

  it 'contains valences' do
    expect(files).not_to be_empty
  end

  files.each do |file|
    context "for #{Pathname.new(file).relative_path_from(NUVA_ROOT)}" do
      let(:data) { YAML.safe_load_file(file) }

      it 'has a VAL integer ID filename and valid YAML' do
        expect(File.basename(file)).to match(/\AVAL-[1-9]\d*\.yml\z/)
        expect { YAML.safe_load_file(file) }.not_to raise_error
      end

      it 'matches the expected schema' do
        expect(data).to be_a(Hash)
        expect(data.keys).to contain_exactly('id', 'parent_id', 'antigen_type_id', 'name', 'abbreviation', 'created_at', 'updated_at', 'codes')

        expect(data['id']).to be_a(Integer)
        expect(data['id']).to be_positive

        expect(File.basename(file)).to eq("VAL-#{data['id']}.yml")

        expect(data['parent_id']).to(be_a(Integer).or be_nil)
        expect(data['antigen_type_id']).to(be_a(Integer).or be_nil)

        expect(data['abbreviation']).to be_a(String)
        expect(data['abbreviation'].strip).not_to be_empty

        expect(data['name']).to be_a(String)
        expect(data['name'].strip).not_to be_empty

        %w[created_at updated_at].each do |field|
          expect(data[field]).to be_a(Integer)
          expect(data[field]).to be >= 0
        end
        
        expect(data['updated_at']).to be >= data['created_at']
      end

      it 'references an existing parent or is a root' do
        if data['parent_id']
          expect(data['parent_id']).to be_positive
          expect(data['parent_id']).not_to eq(data['id'])

          parent_file = NUVA_ROOT.join('valences', "VAL-#{data['parent_id']}.yml")

          expect(parent_file).to be_file
          expect(YAML.safe_load_file(parent_file)['id']).to eq(data['parent_id'])
        end
      end

      it 'references an existing antigen type when one is specified' do
        if data['antigen_type_id']
          expect(data['antigen_type_id']).to be_positive

          antigen_type_file = NUVA_ROOT.join('antigen-types', "AGT-#{data['antigen_type_id']}.yml")

          expect(antigen_type_file).to be_file
          expect(YAML.safe_load_file(antigen_type_file)['id']).to eq(data['antigen_type_id'])
        end
      end

      it 'contains exactly one SYADEM code with a UUID value' do
        expect(data['codes']).to be_a(Array)

        syadem_codes = data['codes'].filter { |c| c['nomenclature'] == 'SYADEM' }

        expect(syadem_codes.count).to eq(1)

        syadem_code = syadem_codes.first
        uuid_regex  = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

        expect(syadem_code).to be_a(Hash)
        expect(syadem_code.keys).to contain_exactly('nomenclature', 'code')
        expect(syadem_code['code']).to be_a(String)
        expect(syadem_code['code']).to match(uuid_regex)
      end

      it 'contains valid codes' do
        data['codes'].each do |code|
          expect(code).to be_a(Hash)
          expect(code.keys).to contain_exactly('nomenclature', 'code')
          expect(code['nomenclature']).to be_a(String)
          expect(code['code']).to be_a(String)
        end
      end

      TRANSLATION_LANGUAGES.each do |language|
        it "has a valid #{language} translation" do
          translation_file = NUVA_ROOT.join('translations', language, 'valences', File.basename(file))

          expect(translation_file).to be_file

          translation = YAML.safe_load_file(translation_file)

          expect(translation).to be_a(Hash)
          expect(translation.keys).to contain_exactly('name')
          
          if language == 'fr'
            expect(translation['name']).to be_a(String)
            expect(translation['name'].strip).not_to be_empty
          else
            expect(translation['name']).to(be_a(String).or be_nil)
          end
        end
      end
    end
  end

  it 'contains unique IDs' do
    ids = files.map { |file| YAML.safe_load_file(file)['id'] }

    expect(ids).to eq(ids.uniq)
  end

  it 'contains unique SYADEM UUID codes' do
    codes = files.map { |file| YAML.safe_load_file(file)['codes'].find { |code| code['nomenclature'] == 'SYADEM' }['code'] }

    expect(codes).to eq(codes.uniq)
  end

  it 'contains no parent cycles' do
    parents = files.to_h do |file|
      data = YAML.safe_load_file(file)
      [data['id'], data['parent_id']]
    end

    parents.each_key do |id|
      visited = []
      current = id

      while current && parents.key?(current)
        expect(visited).not_to include(current), "Parent cycle from VAL-#{id}: #{visited + [current]}"

        visited << current

        current = parents[current]
      end
    end
  end
end

RSpec.describe 'The valence translations' do
  it 'uses exactly the supported language folders' do
    languages = Dir.children(NUVA_ROOT.join('translations')).sort

    expect(languages).to eq(TRANSLATION_LANGUAGES.sort)
  end

  TRANSLATION_LANGUAGES.each do |language|
    it "contains exactly one #{language} file per valence, with no orphan files" do
      directory = NUVA_ROOT.join('translations', language, 'valences')

      expect(directory).to be_directory

      base_files = Dir.children(NUVA_ROOT.join('valences')).sort

      expect(Dir.children(directory).sort).to eq(base_files)
    end
  end
end
