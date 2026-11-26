# frozen_string_literal: true

RSpec.describe 'The valences folder' do
  files = Dir.glob(NUVA_ROOT.join('valences', '*')).sort

  let(:valence_type_ancestors) do
    parents = Dir.glob(NUVA_ROOT.join('valence_types', '*.yml')).to_h do |file|
      type = YAML.safe_load_file(file)
      [type['id'], type['parent_id']]
    end

    lambda do |id|
      chain = [id]
      chain << id while (id = parents[id]) && !chain.include?(id)
      chain
    end
  end

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
        expect(data.keys).to contain_exactly('id', 'parent_id', 'valence_type_id', 'name', 'abbreviation', 'notes', 'created_at', 'updated_at')

        expect(data['id']).to be_a(Integer)
        expect(data['id']).to be_positive

        expect(File.basename(file)).to eq("VAL-#{data['id']}.yml")

        expect(data['parent_id']).to(be_a(Integer).or be_nil)

        expect(data['abbreviation']).to be_a(String)
        expect(data['abbreviation'].strip).not_to be_empty

        expect(data['name']).to be_a(String)
        expect(data['name'].strip).not_to be_empty

        expect(data['notes']).to(be_a(String).or be_nil)

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

      it 'references an existing valence type, optional for a root' do
        next if data['parent_id'].nil? && data['valence_type_id'].nil?

        expect(data['valence_type_id']).to be_a(Integer)
        expect(data['valence_type_id']).to be_positive

        valence_type_file = NUVA_ROOT.join('valence_types', "VTY-#{data['valence_type_id']}.yml")

        expect(valence_type_file).to be_file
        expect(YAML.safe_load_file(valence_type_file)['id']).to eq(data['valence_type_id'])
      end

      it "has the same valence type as its parent or one of its subtypes" do
        next unless data['parent_id']

        parent      = YAML.safe_load_file(NUVA_ROOT.join('valences', "VAL-#{data['parent_id']}.yml"))
        parent_type = parent['valence_type_id']

        next unless parent_type

        allowed = valence_type_ancestors.call(data['valence_type_id'])

        expect(allowed).to include(parent_type),
          "VAL-#{data['id']} (#{data['abbreviation']}) has VTY-#{data['valence_type_id']}, " \
          "which is not VTY-#{parent_type} of its parent VAL-#{parent['id']} (#{parent['abbreviation']}) nor one of its subtypes"
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
        expect(visited).not_to include(current), "Parent cycle from VAL-#{id}: #{visited + [current]}"

        visited << current

        current = parents[current]
      end
    end
  end
end
