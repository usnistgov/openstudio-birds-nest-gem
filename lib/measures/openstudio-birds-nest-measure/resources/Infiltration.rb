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
  typical_pressure_pa = 0.5 * cs * rho * uh**2
  
  # Define the final pressure, in this case 50Pa for ACH50
  fifty_pa = 50.0 # 50 Pa
  
  infiltration_rate_fifty_pa_m3_per_s = infiltration_rate_m3_per_s / (typical_pressure_pa/fifty_pa)**n / (1.0 + alpha) 
  
  return infiltration_rate_fifty_pa_m3_per_s

end

#######################################################################################################
# Air Leakage / Infiltration
# Currently only estimate air leakage at 50 Pa using "space" design flow rates (m3/s) and volumes.
# Currently providing ELA, and using basic conversion to ACH50. TO DO: provide more accurate calculation.
# Currently does not allow for combination of infiltration types.
# Need to expand to include other design flow rate options (e.g., m3/s-m2, ACH/hr) and zoneinfiltration:flowcoefficient
# Also need to populate from an HPXML file data (e.g., leakiness description).
#######################################################################################################

def get_airinfiltration(model, runner, idf)

    total_volume_m3 = 0
    total_infiltration_typical_pressure_m3_per_s = 0
	total_infiltration_ela_cm2 = 0
    #Calculate the volume of the building and the infiltration rates for each space.
	model.getSpaces.each do |space|
      total_volume_m3 += space.volume
      total_infiltration_typical_pressure_m3_per_s += space.infiltrationDesignFlowRate
	  
	  space.spaceInfiltrationEffectiveLeakageAreas.each do |ela|
		total_infiltration_ela_cm2 += ela.effectiveAirLeakageArea
		runner.registerInfo("Space ELA is #{ela.effectiveAirLeakageArea} cm2.")
	  end
	end
	runner.registerInfo("Total Volume is #{total_volume_m3} m3.")
	runner.registerInfo("Total Infiltration (m3/s) is #{total_infiltration_typical_pressure_m3_per_s}.")
	runner.registerInfo("Total Infiltration (ELA) is #{total_infiltration_ela_cm2} cm2.")

    # Convert the infiltration rate from typical pressure to an infiltration rate at 50 Pa
    if total_infiltration_typical_pressure_m3_per_s != 0
		total_infiltration_50Pa_m3_per_s = adjust_infiltration_to_50_Pa(total_infiltration_typical_pressure_m3_per_s)
    elsif total_infiltration_ela_cm2 != 0
		total_infiltration_50Pa_m3_per_s = (total_infiltration_ela_cm2 * 0.001316735) #m3/s = CFM50 / 2118.882; ELA(cm2)=(CFM50/18)*6.4516
	else
	end
	# Determine the ACH (air changes per hour) using the total infiltration and volume.
    ach_50 = (total_infiltration_50Pa_m3_per_s / total_volume_m3) * 3600 # air-change/sec to air-change/hr
	runner.registerInfo("ACH50 is #{ach_50}.")
	
	# Use ACH50 to describe leakiness.
	if ach_50 > 10.0
		leakiness = 'VERY_LEAKY'
	elsif ach_50 < 10.0 && ach_50 > 7.0
		leakiness = 'LEAKY'
	elsif ach_50 < 7.0 && ach_50 > 3.0
		leakiness = 'AVERAGE'	
	elsif ach_50 < 3.0 && ach_50 > 1.0
		leakiness = 'TIGHT'
	elsif ach_50 < 1.0
		leakiness = 'VERY_TIGHT'	
	end

	# provide details on the air sealing that was completed. TO DO - fill only with HPXML file.
	components_air_sealed = []
	# components_air_sealed << {
		# 'attic' => 'OTHER',
		# 'basementCrawlspace' => 'OTHER_SPACE_TYPE',
		# 'livingSpace' => 'OTHER_LIVING_SPACE'
	# }
	components_air_sealed << {}
	runner.registerInfo("Air sealing was completed for #{components_air_sealed}.")

    return {  
      'componentsAirSealed' => components_air_sealed,
	  'airLeakageUnit' => 'ACH',				# Defaulted to ACH for now.			
	  'fanPressure' => 50,						# Defaulted to 50 Pa for now
	  'airLeakageValue' => ach_50.round(3),				
	  'leakinessDescription' => leakiness,	
	  'effectiveLeakageArea' => total_infiltration_ela_cm2.round(2)			#Currently not using this value unless there is no ACH50 value.
    }


end
