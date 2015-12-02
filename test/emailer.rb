#!/usr/bin/env ruby
require 'yaml'
require_relative '../lib/solano_report_emailer'

def email_all
  config = YAML.load_file File.expand_path('../../config.yml', __FILE__)
  solano = config['solano']

  emailer = SolanoReportEmailer.new(solano['user'], solano['password'])

  emailer.login
  emailer.scrape_branch_links
end

email_all
