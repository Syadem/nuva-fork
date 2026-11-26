# frozen_string_literal: true

require 'csv'

RSpec.describe 'The translations' do
  translations_directory = NUVA_ROOT.join('translations')

  concepts = {
    'diseases' => { prefix: 'DIS', fields: %w[name], name_required_in: TRANSLATION_LANGUAGES },
    'vaccines' => { prefix: 'VAC', fields: %w[name description], name_required_in: %w[fr] },
    'valences' => { prefix: 'VAL', fields: %w[name], name_required_in: %w[fr] },
    'valence_types' => { prefix: 'VTY', fields: %w[name], name_required_in: TRANSLATION_LANGUAGES }
  }

  it 'uses exactly the supported language folders' do
    expect(translations_directory.children.map { |c| c.basename.to_s }).to match_array(TRANSLATION_LANGUAGES)
  end

  TRANSLATION_LANGUAGES.each do |language|
    context "in #{language}" do
      directory = translations_directory.join(language)

      it 'contains exactly one CSV per concept' do
        expect(directory.children.map { |c| c.basename.to_s }).to match_array(concepts.keys.map { |c| "#{c}.csv" })
      end

      concepts.each do |concept, config|
        it "translates each of the #{concept} once, sorted by NUVA ID" do
          file          = directory.join("#{concept}.csv")
          relative_path = file.relative_path_from(NUVA_ROOT)
          fields        = config[:fields]
          header, *rows = CSV.read(file, encoding: 'UTF-8')

          expect(header).to eq(['nuva_id', *fields]), "#{relative_path} must have the header #{['nuva_id', *fields].join(',')}"

          rows.each.with_index(2) do |row, number|
            location = "#{relative_path} row #{number}"

            expect(row.size).to eq(fields.size + 1), "#{location} must contain exactly #{fields.size + 1} fields"

            id, *values = row

            expect(id).to match(/\A[1-9][0-9]*\z/), "#{location} has an invalid NUVA ID: #{id.inspect}"

            fields.zip(values).each do |field, value|
              if field == 'name' && config[:name_required_in].include?(language)
                expect(value.to_s.strip).not_to be_empty, "#{location} must have a name"
              end

              next unless value

              expect(value).not_to include("\r"), "#{location} has a carriage return in its #{field}"
              expect(value).to eq(value.strip), "#{location} has leading or trailing whitespace in its #{field}"
            end
          end

          ids = rows.map { |id, *| id.to_i }

          concept_ids =
            NUVA_ROOT
              .join(concept).glob("#{config[:prefix]}-*.yml")
              .map { |concept_file| concept_file.basename('.yml').to_s.delete_prefix("#{config[:prefix]}-").to_i }
              .sort

          missing_ids = concept_ids - ids
          unknown_ids = ids - concept_ids

          expect(missing_ids).to be_empty, "#{relative_path} is missing #{missing_ids.map { |id| "#{config[:prefix]}-#{id}" }.join(', ')}"
          expect(unknown_ids).to be_empty, "#{relative_path} references unknown #{unknown_ids.map { |id| "#{config[:prefix]}-#{id}" }.join(', ')}"
          expect(ids).to eq(concept_ids), "#{relative_path} must contain each ID once, sorted by NUVA ID"
        end
      end
    end
  end
end
