# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ThermalZone
  # Determines heating status.  If the zone has a thermostat
  # with a maximum heating setpoint above 5C (41F),
  # counts as heated.  Plenums are also assumed to be heated.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if heated, false if not
  def heated?
    temp_f = 41
    temp_c = OpenStudio.convert(temp_f, 'F', 'C').get

    htd = false

    # Check if the zone has radiant heating,
    # and if it does, get heating setpoint schedule
    # directly from the radiant system to check.
    equipment.each do |equip|
      htg_sch = nil
      if equip.to_ZoneHVACHighTemperatureRadiant.is_initialized
        equip = equip.to_ZoneHVACHighTemperatureRadiant.get
        if equip.heatingSetpointTemperatureSchedule.is_initialized
          htg_sch = equip.heatingSetpointTemperatureSchedule.get
        end
      elsif equip.to_ZoneHVACLowTemperatureRadiantElectric.is_initialized
        equip = equip.to_ZoneHVACLowTemperatureRadiantElectric.get
        htg_sch = equip.heatingSetpointTemperatureSchedule.get
      elsif equip.to_ZoneHVACLowTempRadiantConstFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
        htg_coil = equip.heatingCoil
        if htg_coil.to_CoilHeatingLowTempRadiantConstFlow.is_initialized
          htg_coil = htg_coil.to_CoilHeatingLowTempRadiantConstFlow.get
          if htg_coil.heatingHighControlTemperatureSchedule.is_initialized
            htg_sch = htg_coil.heatingHighControlTemperatureSchedule.get
          end
        end
      elsif equip.to_ZoneHVACLowTempRadiantVarFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
        htg_coil = equip.heatingCoil
        if htg_coil.to_CoilHeatingLowTempRadiantVarFlow.is_initialized
          htg_coil = htg_coil.to_CoilHeatingLowTempRadiantVarFlow.get
          if htg_coil.heatingControlTemperatureSchedule.is_initialized
            htg_sch = htg_coil.heatingControlTemperatureSchedule.get
          end
        end
      end

      # Move on if no heating schedule was found
      next if htg_sch.nil?

      # Get the setpoint from the schedule
      if htg_sch.to_ScheduleRuleset.is_initialized
        htg_sch = htg_sch.to_ScheduleRuleset.get
        max_c = htg_sch.annual_min_max_value['max']
        htd = true if max_c > temp_c
      elsif htg_sch.to_ScheduleConstant.is_initialized
        htg_sch = htg_sch.to_ScheduleConstant.get
        max_c = htg_sch.annual_min_max_value['max']
        htd = true if max_c > temp_c
      elsif htg_sch.to_ScheduleCompact.is_initialized
        htg_sch = htg_sch.to_ScheduleCompact.get
        max_c = htg_sch.annual_min_max_value['max']
        htd = true if max_c > temp_c
      else
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} used an unknown schedule type for the heating setpoint; assuming heated.")
        htd = true
      end
    end

    # Unheated if no thermostat present
    return htd if thermostat.empty?

    # Check the heating setpoint
    tstat = thermostat.get
    if tstat.to_ThermostatSetpointDualSetpoint
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      htg_sch = tstat.getHeatingSchedule
      if htg_sch.is_initialized
        htg_sch = htg_sch.get
        if htg_sch.to_ScheduleRuleset.is_initialized
          htg_sch = htg_sch.to_ScheduleRuleset.get
          max_c = htg_sch.annual_min_max_value['max']
          htd = true if max_c > temp_c
        elsif htg_sch.to_ScheduleConstant.is_initialized
          htg_sch = htg_sch.to_ScheduleConstant.get
          max_c = htg_sch.annual_min_max_value['max']
          htd = true if max_c > temp_c
        elsif htg_sch.to_ScheduleCompact.is_initialized
          htg_sch = htg_sch.to_ScheduleCompact.get
          max_c = htg_sch.annual_min_max_value['max']
          htd = true if max_c > temp_c
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} used an unknown schedule type for the heating setpoint; assuming heated.")
          htd = true
        end
      end
    elsif tstat.to_ZoneControlThermostatStagedDualSetpoint
      tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      htg_sch = tstat.heatingTemperatureSetpointSchedule
      if htg_sch.is_initialized
        htg_sch = htg_sch.get
        if htg_sch.to_ScheduleRuleset.is_initialized
          htg_sch = htg_sch.to_ScheduleRuleset.get
          max_c = htg_sch.annual_min_max_value['max']
          htd = true if max_c > temp_c
        end
      end
    end

    return htd
  end

  # Determines cooling status.  If the zone has a thermostat
  # with a minimum cooling setpoint below 33C (91F),
  # counts as cooled.  Plenums are also assumed to be cooled.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if cooled, false if not
  def cooled?
    temp_f = 91
    temp_c = OpenStudio.convert(temp_f, 'F', 'C').get

    cld = false

    # Check if the zone has radiant cooling,
    # and if it does, get cooling setpoint schedule
    # directly from the radiant system to check.
    equipment.each do |equip|
      clg_sch = nil
      if equip.to_ZoneHVACLowTempRadiantConstFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
        clg_coil = equip.heatingCoil
        if clg_coil.to_CoilCoolingLowTempRadiantConstFlow.is_initialized
          clg_coil = clg_coil.to_CoilCoolingLowTempRadiantConstFlow.get
          if clg_coil.coolingLowControlTemperatureSchedule.is_initialized
            clg_sch = clg_coil.coolingLowControlTemperatureSchedule.get
          end
        end
      elsif equip.to_ZoneHVACLowTempRadiantVarFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
        clg_coil = equip.heatingCoil
        if clg_coil.to_CoilCoolingLowTempRadiantVarFlow.is_initialized
          clg_coil = clg_coil.to_CoilCoolingLowTempRadiantVarFlow.get
          if clg_coil.coolingControlTemperatureSchedule.is_initialized
            clg_sch = clg_coil.coolingControlTemperatureSchedule.get
          end
        end
      end
      # Move on if no cooling schedule was found
      next if clg_sch.nil?

      # Get the setpoint from the schedule
      if clg_sch.to_ScheduleRuleset.is_initialized
        clg_sch = clg_sch.to_ScheduleRuleset.get
        min_c = clg_sch.annual_min_max_value['min']
        cld = true if min_c < temp_c
      elsif clg_sch.to_ScheduleConstant.is_initialized
        clg_sch = clg_sch.to_ScheduleConstant.get
        min_c = clg_sch.annual_min_max_value['min']
        cld = true if min_c < temp_c
      elsif clg_sch.to_ScheduleCompact.is_initialized
        clg_sch = clg_sch.to_ScheduleCompact.get
        min_c = clg_sch.annual_min_max_value['min']
        cld = true if min_c < temp_c
      else
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
        cld = true
      end
    end

    # Unheated if no thermostat present
    return cld if thermostat.empty?

    # Check the cooling setpoint
    tstat = thermostat.get
    if tstat.to_ThermostatSetpointDualSetpoint
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      clg_sch = tstat.getCoolingSchedule
      if clg_sch.is_initialized
        clg_sch = clg_sch.get
        if clg_sch.to_ScheduleRuleset.is_initialized
          clg_sch = clg_sch.to_ScheduleRuleset.get
          min_c = clg_sch.annual_min_max_value['min']
          cld = true if min_c < temp_c
        elsif clg_sch.to_ScheduleConstant.is_initialized
          clg_sch = clg_sch.to_ScheduleConstant.get
          min_c = clg_sch.annual_min_max_value['min']
          cld = true if min_c < temp_c
        elsif clg_sch.to_ScheduleCompact.is_initialized
          clg_sch = clg_sch.to_ScheduleCompact.get
          min_c = clg_sch.annual_min_max_value['min']
          cld = true if min_c < temp_c
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
          cld = true
        end
      end
    elsif tstat.to_ZoneControlThermostatStagedDualSetpoint
      tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      clg_sch = tstat.coolingTemperatureSetpointSchedule
      if clg_sch.is_initialized
        clg_sch = clg_sch.get
        if clg_sch.to_ScheduleRuleset.is_initialized
          clg_sch = clg_sch.to_ScheduleRuleset.get
          min_c = clg_sch.annual_min_max_value['min']
          cld = true if min_c < temp_c
        end
      end
    end

    return cld
  end
end
