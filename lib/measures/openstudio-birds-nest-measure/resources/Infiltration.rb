# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Convert the infiltration rate at a typical value for the prototype buildings
# to an infiltration rate at 50Pa
# per the inverse of the method described here:  http://www.taskair.net/knowledge/Infiltration%20Modeling%20Guidelines%20for%20Commercial%20Building%20Energy%20Analysis.pdf
#
# @param infiltration_rate_m3_per_s [Double] initial infiltration rate in m^3/s
# @return [Double] the infiltration rate, adjusted to 50 Pa
def adjust_infiltration_to_50_Pa(infiltration_rate_m3_per_s)

  # Details of these coefficients can be found in paper
  alpha = 0.22 # unitless - terrain adjustment factor
  uh = 4.47 # m/s - wind speed
  rho = 1.18 # kg/m^3 - air density
  cs = 0.1617 # unitless - positive surface pressure coefficient
  n = 0.65 # unitless - infiltration coefficient

  # Calculate the typical pressure - same for all building types
  typical_pressure_pa = 0.5 * cs * rho * uh ** 2

  # Define the final pressure, in this case 50Pa for ACH50
  fifty_pa = 50.0 # 50 Pa

  infiltration_rate_m3_per_s / (typical_pressure_pa / fifty_pa) ** n / (1.0 + alpha)
end

#######################################################################################################
# Air Leakage / Infiltration
# Currently only estimate air leakage at 50 Pa using "space" design flow rates (m3/s) and volumes.
# Currently providing ELA, and using basic conversion to ACH50. TO DO: provide more accurate calculation.
# Currently does not allow for combination of infiltration types.
# Need to expand to include other design flow rate options (e.g., m3/s-m2, ACH/hr) and zoneinfiltration:flowcoefficient
# Also need to populate from an HPXML file data (e.g., leakiness description).
#######################################################################################################

def get_airinfiltration(model, runner)
  # Calculate the volume of the building and the infiltration rates for each space.
  total_infiltration_ela_cm2 = model.getSpaces
                                    .flat_map(&:spaceInfiltrationEffectiveLeakageAreas)
                                    .map(&:effectiveAirLeakageArea)
                                    .sum
  ach50 = calc_ach50(model, total_infiltration_ela_cm2)

  runner.registerInfo("Total Infiltration (ELA) is #{total_infiltration_ela_cm2} cm2.")
  runner.registerInfo("ACH50 is #{ach50}.")

  {
    'componentsAirSealed' => [{}],
    'airLeakageUnit' => 'ACH', # Defaulted to ACH for now.
    'fanPressure' => 50, # Defaulted to 50 Pa for now
    'airLeakageValue' => ach50.round(3),
    'leakinessDescription' => leakiness(ach50),
    'effectiveLeakageArea' => total_infiltration_ela_cm2.round(2) # Currently not using this value unless there is no ACH50 value.
  }
end

def calc_ach50(model, total_infiltration_ela_cm2)
  # Determine the ACH (air changes per hour) using the total infiltration and volume.
  total_volume_m3 = model.getSpaces.map(&:volume).sum
  total_infiltration_typical_pressure_m3_per_s = model.getSpaces.map(&:infiltrationDesignFlowRate).sum

  runner.registerInfo("Total Volume is #{total_volume_m3} m3.")
  runner.registerInfo("Total Infiltration (m3/s) is #{total_infiltration_typical_pressure_m3_per_s}.")

  total_infiltration_50Pa_m3_per_s = infiltration_50Pa_m3_per_s(
    total_infiltration_typical_pressure_m3_per_s, total_infiltration_ela_cm2
  )
  (total_infiltration_50Pa_m3_per_s / total_volume_m3) * 3600 # air-change/sec to air-change/hr
end

def leakiness(ach_50)
  if ach_50 > 10.0
    'VERY_LEAKY'
  elsif ach_50 < 10.0 && ach_50 > 7.0
    'LEAKY'
  elsif ach_50 < 7.0 && ach_50 > 3.0
    'AVERAGE'
  elsif ach_50 < 3.0 && ach_50 > 1.0
    'TIGHT'
  elsif ach_50 < 1.0
    'VERY_TIGHT'
  end
end

def infiltration_50Pa_m3_per_s(total_infiltration_typical_pressure_m3_per_s, total_infiltration_ela_cm2)
  # Convert the infiltration rate from typical pressure to an infiltration rate at 50 Pa
  if total_infiltration_typical_pressure_m3_per_s != 0
    adjust_infiltration_to_50_Pa(total_infiltration_typical_pressure_m3_per_s)
  elsif total_infiltration_ela_cm2 != 0
    # m3/s = CFM50 / 2118.882; ELA(cm2)=(CFM50/18)*6.4516
    (total_infiltration_ela_cm2 * 0.001316735)
  end
end
