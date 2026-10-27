# frozen_string_literal: true

RSpec.describe 'The diseases folder' do
  files = Dir.glob(NUVA_ROOT.join('diseases', '*')).sort

  it 'contains diseases' do
    expect(files).not_to be_empty
  end

  files.each do |file|
    context "for #{Pathname.new(file).relative_path_from(NUVA_ROOT)}" do
      let(:data) { YAML.safe_load_file(file) }

      it 'has a DIS integer ID filename and valid YAML' do
        expect(File.basename(file)).to match(/\ADIS-[1-9]\d*\.yml\z/)
        expect { YAML.safe_load_file(file) }.not_to raise_error
      end

      it 'matches the expected schema' do
        expect(data).to be_a(Hash)
        expect(data.keys).to contain_exactly('id', 'name', 'created_at', 'updated_at', 'valence_ids', 'codes')

        expect(data['id']).to be_a(Integer)
        expect(data['id']).to be_positive

        expect(File.basename(file)).to eq("DIS-#{data['id']}.yml")

        expect(data['name']).to be_a(String)
        expect(data['name'].strip).not_to be_empty

        %w[created_at updated_at].each do |field|
          expect(data[field]).to be_a(Integer)
          expect(data[field]).to be >= 0
        end

        expect(data['updated_at']).to be >= data['created_at']

        expect(data['valence_ids']).to be_a(Array)
        expect(data['valence_ids']).to all(be_a(Integer))
        expect(data['valence_ids']).to all(be_positive)
        expect(data['valence_ids']).to eq(data['valence_ids'].uniq)
      end

      it 'references existing valences' do
        data['valence_ids'].each do |id|
          valence_file = NUVA_ROOT.join('valences', "VAL-#{id}.yml")

          expect(valence_file).to be_file
          expect(YAML.safe_load_file(valence_file)['id']).to eq(id)
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
          translation_file = NUVA_ROOT.join('translations', language, 'diseases', File.basename(file))

          expect(translation_file).to be_file

          translation = YAML.safe_load_file(translation_file)

          expect(translation).to be_a(Hash)
          expect(translation.keys).to contain_exactly('name')

          expect(translation['name']).to be_a(String)
          expect(translation['name'].strip).not_to be_empty
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
end

RSpec.describe 'The disease translations' do
  it 'uses exactly the supported language folders' do
    languages = Dir.children(NUVA_ROOT.join('translations')).sort

    expect(languages).to eq(TRANSLATION_LANGUAGES.sort)
  end

  TRANSLATION_LANGUAGES.each do |language|
    it "contains exactly one #{language} file per disease, with no orphan files" do
      directory = NUVA_ROOT.join('translations', language, 'diseases')

      expect(directory).to be_directory

      base_files = Dir.children(NUVA_ROOT.join('diseases')).sort

      expect(Dir.children(directory).sort).to eq(base_files)
    end
  end
end
