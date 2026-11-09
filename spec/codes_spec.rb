# frozen_string_literal: true

require 'csv'
require 'set'

RSpec.describe 'The code mappings' do
  codes_directory  = NUVA_ROOT.join('codes')
  concept_prefixes = { 'antigen_types' => 'AGT', 'diseases' => 'DIS', 'vaccines' => 'VAC', 'valences' => 'VAL' }
  uuid_pattern     = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  it 'contains exactly the four concept directories' do
    expect(codes_directory).to be_directory
    expect(codes_directory.children.map { |entry| entry.basename.to_s }).to match_array(concept_prefixes.keys)
  end

  concept_prefixes.each do |concept, prefix|
    context "for #{concept}" do
      let(:directory) { codes_directory.join(concept) }

      let(:concept_ids) do
        NUVA_ROOT
          .join(concept).glob("#{prefix}-*.yml")
          .map { |file| file.basename('.yml').to_s.delete_prefix("#{prefix}-") }
          .to_set
      end

      it 'contains CSV mappings with valid references and text codes' do
        expect(directory).to be_directory

        directory.children.sort.each do |file|
          relative_path = file.relative_path_from(NUVA_ROOT)

          expect(file).to be_file
          expect(file.basename.to_s).to match(/\A[a-z0-9][a-z0-9_-]*\.csv\z/)

          header, *rows = CSV.read(file, encoding: 'UTF-8')

          expect(header).to eq(%w[nuva_id code]), "#{relative_path} must have the header nuva_id,code"
          expect(rows).not_to be_empty, "#{relative_path} must contain at least one mapping"

          rows.each.with_index(2) do |row, number|
            location = "#{relative_path} row #{number}"

            expect(row.size).to eq(2), "#{location} must contain exactly two fields"

            id, code = row

            expect(id).to match(/\A[1-9][0-9]*\z/), "#{location} has an invalid NUVA ID: #{id.inspect}"
            expect(concept_ids).to include(id), "#{location} references an unknown #{prefix}-#{id}"
            expect(code).to match(/\S/), "#{location} must contain a code"
          end
        end
      end

      it 'maps every concept to exactly one unique SYADEM UUID' do
        syadem_file = directory.join('syadem.csv')

        expect(syadem_file).to be_file

        rows = CSV.read(syadem_file, encoding: 'UTF-8', headers: true)

        expect(rows['nuva_id']).to match_array(concept_ids.to_a)

        codes = rows['code']
        
        expect(codes).to all(match(uuid_pattern))
        expect(codes.map(&:downcase).uniq.size).to eq(codes.size)
      end
    end
  end
end
