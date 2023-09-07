# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ScheduleRuleset
  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule
  # (always 1.0, 24/7, 365) would return a value of 8760.
  #
  # @author Andrew Parker, NREL.  Matt Leach, NORESCO.
  # @return [Double] The total number of full load hours for this schedule.
  def annual_equivalent_full_load_hrs
    annual_hours
  end

  # Returns the min and max value for this schedule.
  # It doesn't evaluate design days only run-period conditions
  #
  # @author David Goldwasser, NREL.
  # @return [Hash] Hash has two keys, min and max.
  def annual_min_max_value
    # gather profiles
    profiles = []
    profiles << defaultDaySchedule
    rules = scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    # test profiles
    min = nil
    max = nil
    profiles.each do |profile|
      profile.values.each do |value|
        if min.nil?
          min = value
        elsif min > value
          min = value
        end
        if max.nil?
          max = value
        elsif max < value
          max = value
        end
      end
    end

    { 'min' => min, 'max' => max }
  end

  # Returns the total number of hours where the schedule
  # is greater than the specified value.
  #
  # @author Andrew Parker, NREL.
  # @param lower_limit [Double] the lower limit.  Values equal to the limit
  # will not be counted.
  # @return [Double] The total number of hours
  # this schedule is above the specified value.
  def annual_hours_above_value(lower_limit)
    annual_hours
  end

  private

  def annual_hours
    # Define the start and end date
    year_end_date, year_start_date = year_start_end

    # Get the ordered list of all the day schedules
    # that are used by this schedule ruleset
    day_schs = getDaySchedules(year_start_date, year_end_date)

    # Get a 365-value array of which schedule is used on each day of the year,
    day_schs_used_each_day = getActiveRuleIndices(year_start_date, year_end_date)
    if !day_schs_used_each_day.length == 365
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "#{name} does not have 365 daily schedules accounted for, cannot accurately calculate annual EFLH.")
      return 0
    end

    # Create a map that shows how many days each schedule is used
    day_sch_freq = day_schs_used_each_day.group_by { |n| n }

    # Build a hash that maps schedule day index to schedule day
    schedule_index_to_day = {}
    day_schs.each_with_index do |day_sch, i|
      schedule_index_to_day[day_schs_used_each_day[i]] = day_sch
    end

    # Loop through each of the schedules that is used, figure out the
    # hours for that day, then multiply this by the number
    # of days that day schedule applies and add this to the total.
    annual_hrs = 0
    default_day_sch = defaultDaySchedule
    day_sch_freq.each do |freq|
      sch_index = freq[0]
      number_of_days_sch_used = freq[1].size

      # Get the day schedule at this index
      day_sch = if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
                  default_day_sch
                else
                  schedule_index_to_day[sch_index]
                end

      # Determine the hours for just one day
      daily_hrs = 0
      values = day_sch.values
      times = day_sch.times

      previous_time_decimal = 0
      times.each_with_index do |time, i|
        time_decimal = (time.days * 24) + time.hours + (time.minutes / 60) + (time.seconds / 3600)
        duration_of_value = time_decimal - previous_time_decimal

        daily_hrs += values[i] * duration_of_value
        previous_time_decimal = time_decimal
      end

      # Multiply the daily hours by the number
      # of days this schedule is used per year
      # and add this to the overall total
      annual_hrs += daily_hrs * number_of_days_sch_used
    end

    annual_hrs
  end

  def year_start_end
    year = if model.yearDescription.is_initialized
             model.yearDescription.get.assumedYear
           else
             OpenStudio.logFree(
               OpenStudio::Info,
               'openstudio.standards.ScheduleRuleset',
               'WARNING: Year description is not specified; assuming 2009, the default year OS uses.'
             )
             2009
           end

    [
      OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year),
      OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    ]
  end
end
