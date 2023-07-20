# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require_relative '../spec_helper'

RSpec.describe OpenStudio::BirdsNest do
  it 'has a version number' do
    expect(OpenStudio::BirdsNest::VERSION).not_to be nil
  end

  it 'has a measures directory' do
    instance = OpenStudio::BirdsNest::BirdsNest.new
    expect(File.exist?(instance.measures_dir)).to be true
  end
end
