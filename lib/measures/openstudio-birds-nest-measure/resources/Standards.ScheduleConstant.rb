# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ScheduleConstant
  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule
  # (always 1.0, 24/7, 365) would return a value of 8760.
  #
  # @author Andrew Parker, NREL
  # return [Double] The total number of full load hours for this schedule
  def annual_equivalent_full_load_hrs
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ScheduleRuleset', "Calculating total annual EFLH for schedule: #{name}")

    return annual_flh = value * 8760
  end

  # Returns the min and max value for this schedule.
  # It doesn't evaluate design days only run-period conditions
  #
  # @author David Goldwasser, NREL.
  # return [Hash] Hash has two keys, min and max.
  def annual_min_max_value
    result = { 'min' => value, 'max' => value }

    return result
  end
end
