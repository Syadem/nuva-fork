# frozen_string_literal: true

RSpec.describe 'The antigen types folder' do
  files = Dir.glob(NUVA_ROOT.join('antigen_types', '*')).sort

  it 'contains antigen types' do
    expect(files).not_to be_empty
  end

  files.each do |file|
    context "for #{Pathname.new(file).relative_path_from(NUVA_ROOT)}" do
      let(:data) { YAML.safe_load_file(file) }

      it 'has an AGT integer ID filename and valid YAML' do
        expect(File.basename(file)).to match(/\AAGT-[1-9]\d*\.yml\z/)
        expect { YAML.safe_load_file(file) }.not_to raise_error
      end

      it 'matches the expected schema' do
        expect(data).to be_a(Hash)
        expect(data.keys).to contain_exactly('id', 'parent_id', 'name', 'created_at', 'updated_at')

        expect(data['id']).to be_a(Integer)
        expect(data['id']).to be_positive

        expect(File.basename(file)).to eq("AGT-#{data['id']}.yml")

        expect(data['parent_id']).to(be_a(Integer).or be_nil)

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

          parent_file = NUVA_ROOT.join('antigen_types', "AGT-#{data['parent_id']}.yml")

          expect(parent_file).to be_file
          expect(YAML.safe_load_file(parent_file)['id']).to eq(data['parent_id'])
        end
      end

      TRANSLATION_LANGUAGES.each do |language|
        it "has a valid #{language} translation, including when the name is null" do
          translation_file = NUVA_ROOT.join('translations', language, 'antigen_types', File.basename(file))

          expect(translation_file).to be_file

          translation = YAML.safe_load_file(translation_file)

          expect(translation).to be_a(Hash)
          expect(translation.keys).to contain_exactly('name')
          expect(translation['name']).to(be_a(String).or be_nil)
        end
      end
    end
  end

  it 'contains unique IDs' do
    ids = files.map { |file| YAML.safe_load_file(file)['id'] }

    expect(ids).to eq(ids.uniq)
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
        expect(visited).not_to include(current), "Parent cycle from AGT-#{id}: #{visited + [current]}"

        visited << current

        current = parents[current]
      end
    end
  end
end

RSpec.describe 'The antigen type translations' do
  it 'uses exactly the supported language folders' do
    languages = Dir.children(NUVA_ROOT.join('translations')).sort

    expect(languages).to eq(TRANSLATION_LANGUAGES.sort)
  end

  TRANSLATION_LANGUAGES.each do |language|
    it "contains exactly one #{language} file per antigen type, with no orphan files" do
      directory = NUVA_ROOT.join('translations', language, 'antigen_types')

      expect(directory).to be_directory

      base_files = Dir.children(NUVA_ROOT.join('antigen_types')).sort
      
      expect(Dir.children(directory).sort).to eq(base_files)
    end
  end
end
