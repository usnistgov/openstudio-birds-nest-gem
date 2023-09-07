# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ScheduleCompact
  # Returns the min and max value for this schedule.
  #
  # @author Andrew Parker, NREL.
  # return [Hash] Hash has two keys, min and max.
  def annual_min_max_value
    vals = []
    prev_str = ''
    extensibleGroups.each do |eg|
      if prev_str.include?('until')
        val = eg.getDouble(0)
        vals << val.get if val.is_initialized
      end
      str = eg.getString(0)
      prev_str = str.get.downcase if str.is_initialized
    end

    # Error if no values were found
    if vals.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleCompact', "Could not find any value in #{name} when determining min and max.")
      return { 'min' => 999.9, 'max' => 999.9 }
    end

    { 'min' => vals.min, 'max' => vals.max }
  end
end
