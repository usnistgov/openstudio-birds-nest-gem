# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#################################################################################################
# Lighting
#The code could be cleaned up to be more concise.
################################################################################################


def get_lighting(idf, runner, model, pct_inc_lts, pct_mh_lts, pcf_cfl_lf_lts, pct_led_lts)

	#Get lighting type fractions from user inputs. Not available from OS model.
	frac_inc = pct_inc_lts.to_f / 100.0
	#runner.registerInfo("Lighting Fraction for INC has been generated.")
	frac_mh = pct_mh_lts.to_f / 100.0
	#runner.registerInfo("Lighting Fraction for MH has been generated.")
	frac_cfl_lf = pcf_cfl_lf_lts.to_f / 100.0
	#runner.registerInfo("Lighting Fraction for CFL LF has been generated.")
	frac_led = pct_led_lts.to_f / 100.0
	#runner.registerInfo("Lighting Fraction variables have been generated.")

	# Create the lighting fractions array.
  	lighting_fractions = {
		'fracIncandescent' => frac_inc, #pct_inc_lts / 100.0,
		'fracMetalHalide' => frac_mh, #pct_mh_lts / 100.0,
		'fracCflLf' => frac_cfl_lf, #pct_cfl_lf_lts / 100.0,
		'fracLed' => frac_led #pct_led_lts / 100.0
	}
	#runner.registerInfo("Lighting Fraction Array has been generated.")
	
	# Calculate Total Lighting Wattage using the 3 different methods of including lighting in E+
	# This includes lighting level, watts per person, and watts per floor area, each require different calculations.
	total_wattage = 0
	#runner.registerInfo("Total wattage variable is initialized.")
	#Access each lights object and calculate the wattage based on the calculation method and then add to total wattage
	lights = idf.getObjectsByType("Lights".to_IddObjectType)
	#runner.registerInfo("Found Lights Objects.")
		lights.each do |lights|
			wattage = 0
			light_zone_area = 0
			light_name = lights.getString(0).get
			light_zone = lights.getString(1).get
			#runner.registerInfo("Found Light Name and Zone: #{light_name} and #{light_zone}.")
			thermal_zones = model.getThermalZones
			#runner.registerInfo("Found Thermal Zones: #{thermal_zones}.")
			thermal_zones.each do |thermal_zone|
				if thermal_zone.name.get.match(light_zone)
				thermal_zone_area = thermal_zone.floorArea
				#runner.registerInfo("Found Thermal Zone Area: #{thermal_zone_area}.")
				light_zone_area = thermal_zone_area
				#runner.registerInfo("Found Lighting Zone Area.")
				end
			end
			#runner.registerInfo("Found Light Name, Zone, and Area: #{light_name}, #{light_zone}, and #{light_zone_area}.")
			#get light calculation method and make wattage calculation
			light_calc_method = lights.getString(3).get
			#runner.registerInfo("Found Lighting Method: #{light_calc_method}.")
			if light_calc_method == 'LightingLevel'
				lighting_level = lights.getDouble(4).get
				#runner.registerInfo("Found Lighting Level.")
				wattage = lighting_level	
			elsif light_calc_method == 'Watts/Area'
				watts_per_area = lights.getString(5).get
				#runner.registerInfo("Found Watts/Area: #{watts_per_area}.")
				watts_per_area = watts_per_area.to_f
				#runner.registerInfo("Found Watts/Area.")
				wattage = watts_per_area * light_zone_area	
			elsif light_calc_method == 'Watts/Person'
				watts_per_person = lights.getDouble(6).get
				#runner.registerInfo("Found found Watts/Person.")
				people = idf.getObjectsByType("People".to_IddObjectType)
				people.each do |people|
					#runner.registerInfo("Found People Objects: #{people}.")
					people_zone = people.getString(1).get
					if people_zone == light_zone						
						people_calc_method = people.getString(3).get
						if people_calc_method == 'People'
							number_of_people = people.getString(5).get
						elsif people_calc_method == 'People/Area'
							people_per_area = people.getString(6).get
							number_of_people = people_per_area * light_zone_area
						elsif people_calc_method == 'Area/Person'
							area_per_person = people.getString(7).get
							number_of_people = light_zone_area / area_per_person
						end
					else
						number_of_people = 0
						#runner.registerInfo("People Zone not the same as Lighting Zone.")
					zone_wattage = watts_per_person * number_of_people
					end
					wattage += zone_wattage	
				end
			else
				runner.registerWarning("'#{light_name}' not used.")
			end
			total_wattage += wattage
			#runner.registerInfo("Summed Lighting Wattage.")
		end
	
	if not total_wattage.nil?
		total_wattage = total_wattage.round(1)
	end
	# Find any ceiling fans (only available from HPXML file).
	ceiling_fans = []
	ceiling_fan = {
		'thirdPartyCertification' => 'NULL'
	}
	ceiling_fans << ceiling_fan # This will be changed when HPXML is available. Change to default of no fan when released.
	#runner.registerInfo("Ceiling fan variable has been generated.")
	
	# lighting groups is unused for now. Below is the format for populating it.
	# lighting_groups = {
          # 'lightingType' => 'INCANDESCENT',
          # 'numberofUnits' => 0,
		  # 'averageWattage' => 0
        # },
        # {
          # 'lightingType' => 'OTHER_METAL_HALIDE',
          # 'numberofUnits' => 0,
		  # 'averageWattage' => 0
        # },
        # {
          # 'lightingType' => 'COMPACT_FLUORESCENT',
          # 'numberofUnits' => 0,
		  # 'averageWattage' => 0
        # },
        # {
          # 'lightingType' => 'LIGHT_EMITTING_DIODE',
          # 'numberofUnits' => 0,
		  # 'averageWattage' => 0
        # }
	
	
	# Create Lighting Object. Only need the lighting group OR the lighting fraction with total wattage for BIRDS NEST.
    return {  
      'lightingGroups' => [],						# would be populated with lighting_groups
	  'lightingFractions' => lighting_fractions,	#Comes from user inputs.
	  'totalWattage' => total_wattage, 				# Aggregate wattage for all lighting objects in the OSM, currently defaulted to 999
	  'ceilingFans' => ceiling_fans 	 			# Defaulted to an array of one EnergyStar for testing
    }

end