# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#############################################################
# Appliances - user inputs required because no way to identify appliances from the model
#############################################################
	#Initialize Appliance Object, which will be an object of objects for each appliance.
	#TO DO - Currently there will only be 1 appliance for each type selected, but this should be expanded in the future.
	#TO DO - the current json format is not consistent with the example output file because the arrays are reported.
	#But there is no heading for the type of appliances.


def get_appliances(runner, appliance_clothes_washer, appliance_clothes_dryer,
	appliance_cooking_range, appliance_frig, appliance_dishwasher, appliance_freezer)

	appliances = {}

	# Create Clothes Washer object and add to appliance object.
	clotheswashers = []
	app_clothes_washer_cert = ''
	app_clothes_washer_modified_energy_factor = 0
	app_clothes_washer_water_factor = 0
	app_clothes_washer_cap = 0
	app_clothes_washer_cert = ''

	#runner.registerInfo("Clothes Washer is #{appliance_clothes_washer}.")

	# Only need the certification type for clothes washer.
	# Assume only 1 clothes washer. Should add option for more with multifaimly.
	# Hard code values that are not currently needed for BIRDS NEST.
	app_clothes_washer_type = 'FRONT_LOADER'
	#runner.registerInfo("Clothes Washer Type is #{app_clothes_washer_type}.")

	if appliance_clothes_washer != 'No Clothes Washer'
		app_clothes_washer_count = 1
		if appliance_clothes_washer == 'EnergyStar'
			app_clothes_washer_cert = 'ENERGY_STAR'
		else
			app_clothes_washer_cert = 'NULL'
		end
		clothes_washer = {
		'type' => app_clothes_washer_type,
		'thirdPartyCertification' => app_clothes_washer_cert,	#
		'modifiedEnergyFactor' => app_clothes_washer_modified_energy_factor,	#
		'waterFactor' => app_clothes_washer_water_factor,
		'capacity' => app_clothes_washer_cap,
		'numberOfUnits' => app_clothes_washer_count,
		}
	else
		app_clothes_washer_count = 0
		clothes_washer = {}
	end
	#runner.registerInfo("Identified number of clothes washers = #{app_clothes_washer_count}.")
	# runner.registerInfo("Clothes Washer Certification is #{app_clothes_washer_cert}.")
	#runner.registerInfo("Successfully created Clothes Washer Object: #{clothes_washer}.")

	clotheswashers << clothes_washer # Assumes only one clothes washer. Could create a do loop if more than one is available.
	appliances['clothesWashers'] = clotheswashers

	# Create Clothes Dryer object and add to appliance object.
	clothesdryers = []
	app_clothes_dryer_efficiency_factor = 0
	app_clothes_dryer_number_of_units = 0
	app_clothes_dryer_type = 'DRYER'
	app_clothes_dryer_fuel_type = ''
	app_clothes_dryer_third_party_certification = 'NULL'

	#runner.registerInfo("Clothes Dryer is #{appliance_clothes_dryer}.")

	if appliance_clothes_dryer != 'No Clothes Dryer'
		app_clothes_dryer_number_of_units = 1

		if appliance_clothes_dryer == 'Electric' || appliance_clothes_dryer == 'Electric Heat Pump' || appliance_clothes_dryer == 'Electric Premium'
			app_clothes_dryer_fuel_type = 'ELECTRICITY'
		elsif appliance_clothes_dryer == 'Gas' || appliance_clothes_dryer == 'Gas Premium'
			app_clothes_dryer_fuel_type = 'NATURAL_GAS'
		elsif appliance_clothes_dryer == 'Propane'
			app_clothes_dryer_fuel_type = 'PROPANE'
		end
		clothes_dryer = {
		  'efficiencyFactor' => app_clothes_dryer_efficiency_factor,
		  'numberOfUnits' => app_clothes_dryer_number_of_units,
		  'type' => app_clothes_dryer_type,
		  'fuelType' => app_clothes_dryer_fuel_type,
		  'thirdPartyCertification' => app_clothes_dryer_third_party_certification,
		}
	else
		app_clothes_dryer_number_of_units = 0
		clothes_dryer = {}
	end
	#runner.registerInfo("Identified number of clothes dryers = #{app_clothes_dryer_number_of_units}.")
	#runner.registerInfo("Successfully created Clothes Dryer Object: #{clothes_dryer}.")

	clothesdryers << clothes_dryer # Assumes only one clothes dryer. Could create a do loop if more than one is available.
	appliances['clothesDryers'] = clothesdryers

	# Create Cooking Range object and add to appliance object.
	cookingranges = []
	app_cooking_range_is_induction = false
	app_cooking_range_number_of_units = 0
	app_cooking_range_fuel_type = 'NULL'
	app_cooking_range_third_party_certification = 'NULL'

	#runner.registerInfo("Cookling Range is #{appliance_cooking_range}.")

	if appliance_cooking_range == 'No Cooking Range'
		app_cooking_range_number_of_units = 0
		app_cooking_range_fuel_type = 'NULL'
		cooking_range = {}
	else
		app_cooking_range_number_of_units = 1
		if appliance_cooking_range == 'Electric Induction'
			app_cooking_range_is_induction = true
		end
		if appliance_cooking_range == 'Electric' || appliance_cooking_range == 'Electric Induction'
			app_cooking_range_fuel_type = 'ELECTRICITY'
		elsif appliance_cooking_range == 'Gas'
			app_cooking_range_fuel_type = 'NATURAL_GAS'
		elsif appliance_cooking_range == 'Propane'
			app_cooking_range_fuel_type = 'PROPANE'
		end
		cooking_range = {
		  'isInduction' => app_cooking_range_is_induction,
		  'numberOfUnits' => app_cooking_range_number_of_units,
		  'fuelType' => app_cooking_range_fuel_type,
		  'thirdPartyCertification' => app_cooking_range_third_party_certification,
		}
	end
	#runner.registerInfo("Successfully created Cooking Range Object: #{cooking_range}.")

	cookingranges << cooking_range # Assumes only one cooking range. Could create a do loop if more than one is available.
	appliances['cookingRanges'] = cookingranges

	# Create Refrigerator object and add to appliance object.
	frigs = []
	app_frig_type = 'FULL_SIZE_TWO_DOORS'
	app_frig_cert = 'NULL'
	app_frig_vol = 0
	app_frig_count = 0

	#runner.registerInfo("Frig is #{appliance_frig}.")
	app_frig_type, detail2, app_frig_eff, detail4 , app_frig_vol, app_frig_cert = appliance_frig.split('_')
    #runner.registerInfo("Frig Detais are: #{app_frig_type}, #{detail2}, #{app_frig_eff}, #{detail4}, #{app_frig_vol}, #{app_frig_cert}.")

	# Need the cert amd  type for clothes washer.
	# Assume only 1 clothes washer. Should add option for more with multifaimly.
	# Hard code values that are not currently needed for BIRDS NEST.
	#runner.registerInfo("Frig Type is #{app_frig_type}.")

	frig_cert_enum = ""
	if app_frig_type != 'None'
		app_frig_count = 1
		frig_type_enum = ""
		if app_frig_type == 'BottomFreezer'
			frig_type_enum = 'BOTTOM_FREEZER'
		elsif app_frig_type == 'SideFreezer'
			frig_type_enum = 'SIDE_BY_SIDE'
		elsif app_frig_type == 'TopFreezer'
			frig_type_enum = 'TOP_FREEZER'
		end

		if app_frig_cert == 'EnergyStar'
			frig_cert_enum = 'ENERGY_STAR'
		end
		# Currently does not provide the type of appliance object, just an array. Need to match the proto format
		refrigerator = {
		'type' => frig_type_enum,
		'thirdPartyCertification' => frig_cert_enum,	#
		'volume' => app_frig_vol.to_f,
		'numberOfUnits' => app_frig_count,
		'ef' => app_frig_eff.to_f
		}
	else
		app_frig_count = 0
		frig_type_enum = 'UNCATEGORIZED'
		frig_cert_enum = 'NULL'
		# Currently does not provide the type of appliance object, just an array. Need to match the proto format
		refrigerator = {}
	end
	#runner.registerInfo("Identified number of refrigerators = #{app_frig_count}.")
	#runner.registerInfo("Successfully created Refrigerator Object: #{refrigerator}.")

	frigs << refrigerator # Assumes only one frig. Could create a do loop if more than one is available.
	appliances['refrigerators'] = frigs

	#Need to add all the other appliances in the same manner as the clothes washer and frig

	# Create Dishwasher and add to appliance object.
	dishwashers = []
	app_dishwasher_energy_factor = 0
	app_dishwasher_rated_water_per_cycle = 0
	app_dishwasher_place_setting_capacity = 0
	app_dishwasher_number_of_units = 0
	app_dishwasher_type = 'BUILT_IN_UNDER_COUNTER'
	app_dishwasher_fuel_type = 'ELECTRICITY'
	app_dishwasher_third_party_certification = 'NULL'

	#runner.registerInfo("Dishwasher is #{appliance_dishwasher}.")

	if appliance_dishwasher != 'No Dishwasher'
		app_dishwasher_number_of_units = 1
	else
		app_dishwasher_number_of_units = 0
	end
	#runner.registerInfo("Identified number of dishwashers = #{app_dishwasher_number_of_units}.")

	if app_dishwasher_number_of_units == 0
		dishwasher = {}
	else
		dishwasher = {
		  'energyFactor' => app_dishwasher_energy_factor,
		  'ratedWaterPerCycle' => app_dishwasher_rated_water_per_cycle,
		  'placeSettingCapacity' => app_dishwasher_place_setting_capacity,
		  'numberOfUnits' => app_dishwasher_number_of_units,
		  'type' => app_dishwasher_type,
		  'fuelType' => app_dishwasher_fuel_type,
		  'thirdPartyCertification' => app_dishwasher_third_party_certification,
		}
	end
	#runner.registerInfo("Successfully created Dishwasher Object: #{dishwasher}.")

	dishwashers << dishwasher # Assumes only one dishwasher. Could create a do loop if more than one is available.
	appliances['dishWashers'] = dishwashers

	# Create Freezer and add to appliance object.
	freezers = []
	app_freezer_volume = 0
	app_freezer_number_of_units = 0
	app_freezer_third_party_certification = 'NULL'

	#runner.registerInfo("Freezer is #{appliance_freezer}.")
	app_freezer_type = ""
	app_freezer_eff = 0

	freezer_config_enum = ""
	if appliance_freezer == 'No_Freezer'
		app_freezer_number_of_units = 0
		freezer_config_enum = 'UNCATEGORIZED'
		freezer = {}
	else
		app_freezer_number_of_units = 1
		#runner.registerInfo("Freezer Detais are: #{app_freezer_type}, #{app_freezer_eff}.")
		app_freezer_type, freezer_eff_string, app_freezer_eff = appliance_freezer.split('_')

		if app_freezer_type == 'Chest'
			freezer_config_enum = 'CASE'
		elsif app_freezer_type == 'Upright'
			freezer_config_enum = 'UNCATEGORIZED'
		end

		freezer = {
		  'volume' => app_freezer_volume,
		  'ef' => app_freezer_eff.to_f,
		  'numberOfUnits' => app_freezer_number_of_units,
		  'configuration' => freezer_config_enum,
		  'thirdPartyCertification' => app_freezer_third_party_certification
		}
		runner.registerInfo("Successfully created Freezer Object: #{freezer}.")

		freezers << freezer # Assumes only one frezzer. Could create a do loop if more than one is available.
	end
	#runner.registerInfo("Identified number of freezers = #{app_freezer_number_of_units}.")

	appliances['freezers'] = freezers

	return appliances
end
