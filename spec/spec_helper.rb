# frozen_string_literal: true

require 'yaml'
require 'pathname'

NUVA_ROOT             = Pathname.new(__dir__).parent
TRANSLATION_LANGUAGES = %w[fr de lv gr pl].freeze

RSpec.configure do |config|
  config.disable_monkey_patching!
end
