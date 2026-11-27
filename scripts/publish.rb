# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'json'
require 'pathname'
require 'time'
require 'yaml'
require 'nuva'

class NuvaDumpCreator
  ROOT = Pathname.new(__dir__).parent

  INJECTION_METHODS = {
    'intramuscular' => :Intramuscular,
    'subcutaneous' => :Subcutaneous,
    'oral' => :Oral,
    'intranasal' => :Intranasal,
    'intradermal' => :Intradermal
  }.freeze

  def initialize
    @vaccines       = load_concept('vaccines')
    @diseases       = load_concept('diseases')
    @valences       = load_concept('valences')
    @valence_types  = load_concept('valence_types')
    @vaccines_by_id = @vaccines.to_h { |vaccine| [vaccine['id'], vaccine] }
    @codes          = %w[vaccines diseases valences].to_h { |concept| [concept, load_codes(concept)] }
  end

  def call(version, lang, time)
    translations = load_translations(lang)

    db = Nuva::NuvaDatabase.new(
      schema_version: Nuva::SCHEMA_VERSION,
      version:,
      generated_at: time,
      locale: lang,
      vaccines: @vaccines.map { |data| vaccine(data, translations) },
      diseases: @diseases.map { |data| disease(data, translations) },
      valences: @valences.map { |data| valence(data, translations) },
      valence_types: @valence_types.map { |data| valence_type(data, translations) }
    )

    Nuva::NuvaDatabase.encode(db)
  end

  private

  def vaccine(data, translations)
    generic = data['generic'] ? data : @vaccines_by_id.fetch(data['generic_vaccine_id'])

    Nuva::Vaccine.new(
      id: data['id'],
      name: name(translations, 'vaccines', data),
      description: description(translations, data),
      injection_methods: data.fetch('injection_methods', []).map { |method| INJECTION_METHODS.fetch(method) },
      codes: @codes['vaccines'].fetch(data['id']),
      valence_ids: generic['valence_ids'],
      other_names: data['other_names'],
      generic: data['generic'],
      generic_vaccine_id: data['generic_vaccine_id'],
      immunoglobulin: generic['immunoglobulin'],
      **dates(data)
    )
  end

  def disease(data, translations)
    Nuva::Disease.new(
      id: data['id'],
      name: name(translations, 'diseases', data),
      codes: @codes['diseases'].fetch(data['id']),
      valence_ids: data['valence_ids'],
      **dates(data)
    )
  end

  def valence(data, translations)
    Nuva::Valence.new(
      id: data['id'],
      parent_id: data['parent_id'],
      name: name(translations, 'valences', data),
      abbreviation: data['abbreviation'],
      valence_type_id: data['valence_type_id'],
      codes: @codes['valences'].fetch(data['id']),
      **dates(data)
    )
  end

  def valence_type(data, translations)
    Nuva::ValenceType.new(
      id: data['id'],
      parent_id: data['parent_id'],
      name: name(translations, 'valence_types', data),
      **dates(data)
    )
  end

  def name(translations, concept, data)
    translations.dig(concept, data['id'], 'name') || data['name']
  end

  def description(translations, data)
    return data['description'] if translations.empty?

    translations.dig('vaccines', data['id'], 'description')
  end

  def dates(data)
    { created_at: Time.at(data['created_at']), updated_at: Time.at(data['updated_at']) }
  end

  def load_concept(concept)
    ROOT
      .join(concept)
      .glob('*.yml')
      .map { |file| YAML.safe_load_file(file) }
      .sort_by { |data| data['id'] }
  end

  def load_codes(concept)
    codes = Hash.new { |hash, key| hash[key] = [] }

    ROOT.join('codes', concept).glob('*.csv').sort.each do |file|
      nomenclature = file.basename('.csv').to_s.upcase

      CSV.foreach(file, headers: true) do |row|
        codes[Integer(row['nuva_id'])] << Nuva::Code.new(nomenclature:, value: row['code'])
      end
    end

    codes
  end

  def load_translations(lang)
    return {} if lang == 'en'

    %w[vaccines diseases valences valence_types].to_h do |concept|
      rows = CSV.read(ROOT.join('translations', lang, "#{concept}.csv"), headers: true, empty_value: nil)

      [concept, rows.to_h { |row| [Integer(row['nuva_id']), row.to_h] }]
    end
  end
end

version             = ARGV[0]
sha_commit          = ARGV[1]
major, minor, patch = version.split('.').map(&:to_i)
languages           = ['en', *Dir.glob('*', base: NuvaDumpCreator::ROOT.join('translations')).sort]
time                = Time.now
creator             = NuvaDumpCreator.new

FileUtils.mkdir_p('release_assets')
FileUtils.mkdir_p('versions')

languages.each do |lang|
  dump = creator.call({ major:, minor:, patch: }, lang, time)

  File.binwrite("release_assets/#{sha_commit}_#{lang}.db", dump)
end

version_data = JSON.pretty_generate({ version:, hash: sha_commit, created_at: time.iso8601 })

File.write("versions/#{time.iso8601}.json", version_data)
File.write('versions/latest.json', version_data)
