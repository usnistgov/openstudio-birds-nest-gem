# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Get an array of all the HVAC (primary heating and cooling components)
# found in the model.  Note, this is not exhaustive, but covers the components
# that will be found in 90% of models.
# HotWater, ChilledWater, PackagedUnit, BuiltUpAirHandler
#
# @return [Array] returns an array of JSON objects, where
# each object represents an HVAC heating/cooling source.

########################################################
# HVAC Coils - Heating and Cooling Coils
########################################################
#Currently uses the last coil of a given type as the only coil of that type. This works for systems with only one heating and cooling coil,
#but homes with more than one system (e.g., room AC units) or with multiple coils that were included accidentally.

def get_hvac_heat_cool(model,runner,user_arguments, idf)

    pri_hvac = runner.getStringArgumentValue('pri_hvac',user_arguments)
    #sec_hvac = runner.getStringArgumentValue('sec_hvac',user_arguments)
	#Define the ductwork type to use for PTHP determination.
	ductwork = runner.getStringArgumentValue('ductwork',user_arguments)

    # Transform "None" to "NULL" for the secondary HVAC system, which is always 'None' for single family residential.
	# May not be for future multifamily capabilities.
	userHeatPumpType = nil
	userHeatPumpFuel = nil
	userBackUpType = nil
	userBackUpSystemFuel = nil
	userCoolingSystemType = nil
	userCoolingSystemFuel = nil
	userHeatingSystemType = nil
	userHeatingSystemFuel = nil
	userGeothermalLoopTransfer = nil
	userGeothermalLoopType = nil

	#sec_hvac = 'NULL' #if sec_hvac == 'None'

	hvac_string = pri_hvac.gsub('Com: ','').gsub('Res: ','').strip
	#runner.registerInfo("HVAC Type is #{hvac_string}.")
	detail1, detail2, detail3, detail4 = pri_hvac.split('_')
    #runner.registerInfo("HVAC Details are: #{detail1}, #{detail2}, #{detail3}, #{detail4}.")

	# The System Details is provided by the user because the model cannot completely provide that information for all systems.
	# Currently assumes that there is both heating and cooling in the building. Could add options for no AC or no heating.
	#Determine if there is a heat pump object to populate.
	# DIRECT_EXPANSION, CLOSED, OPEN - Assumes CLOSED for all GSHPs
	if (detail2 == 'HeatPump') && (detail3 == 'AirtoAir') && (detail4 == 'Std')
		userHeatPumpType = 'AIR_TO_AIR_STD'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'NULL'
		userGeothermalLoopType = 'NULL_GLT'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	elsif (detail2 == 'HeatPump') && (detail3 == 'AirtoAir') && (detail4 == 'SDHV')
		userHeatPumpType = 'AIR_TO_AIR_SDHV'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'NULL'
		userGeothermalLoopType = 'NULL_GLT'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	elsif (detail2 == 'HeatPump') && (detail3 == 'AirtoAir') && (detail4 == 'MiniSplitDucted')
		userHeatPumpType = 'MINI_SPLIT_DUCTED'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'NULL'
		userGeothermalLoopType = 'NULL_GLT'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	elsif (detail2 == 'HeatPump') && (detail3 == 'AirtoAir') && (detail4 == 'MiniSplitNonDucted')
		userHeatPumpType = 'MINI_SPLIT_NONDUCTED'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'NULL'
		userGeothermalLoopType = 'NULL_GLT'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	elsif (detail2 == 'HeatPump') && (detail3 == 'Geothermal') && (detail4 == 'Horizontal')
		userHeatPumpType = 'WATER_TO_AIR'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'CLOSED' # defaulted to closed
		userGeothermalLoopType = 'HORIZONTAL'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	elsif (detail2 == 'HeatPump') && (detail3 == 'Geothermal') && (detail4 == 'Vertical')
		userHeatPumpType = 'WATER_TO_AIR'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'CLOSED' # defaulted to closed
		userGeothermalLoopType = 'VERTICAL'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	elsif (detail2 == 'HeatPump') && (detail3 == 'Geothermal') && (detail4 == 'Slinky')
		userHeatPumpType = 'WATER_TO_AIR'
		userHeatPumpFuel = 'ELECTRICITY_HPF'
		userGeothermalLoopTransfer = 'CLOSED' # defaulted to closed
		userGeothermalLoopType = 'SLINKY'
		userBackUpType = 'INTEGRATED'
		userBackUpSystemFuel = 'ELECTRICITY'
	else
		userHeatPumpType = 'NULL_HPT'
		userHeatPumpFuel = 'NULL_HPF'
		userGeothermalLoopTransfer = 'NULL'
		userGeothermalLoopType = 'NULL_GLT'
		userBackUpType = 'NULL_BT'
		userBackUpSystemFuel = 'NULL'
	end

	# Determine if there is a cooling system object to populate. Currently exclude cental evaporative coolers.
	if detail2 == 'CentralAC'
		userCoolingSystemType = 'CENTRAL_AIR_CONDITIONING'
		userCoolingSystemFuel = 'ELECTRICITY'
	elsif detail2 == 'RoomAC'
		userCoolingSystemType = 'ROOM_AIR_CONDITIONER'
		userCoolingSystemFuel = 'ELECTRICITY'
	else
		userCoolingSystemType = 'NULL_CST'
		userCoolingSystemFuel = 'NULL'
	end

	# Determine if there is a heating system object to populate.
	if detail3 == 'Furnace'
		userHeatingSystemType = 'FURNACE'
		if detail4 == 'Gas'
			userHeatingSystemFuel = 'NATURAL_GAS'
		elsif detail4 == 'Oil'
			userHeatingSystemFuel = 'FUEL_OIL'
		elsif detail4 == 'Propane'
			userHeatingSystemFuel = 'PROPANE'
		elsif detail4 == 'Electric'
			userHeatingSystemFuel = 'ELECTRICITY'
		end
	elsif detail3 == 'Boiler'
		userHeatingSystemType = 'BOILER'
		if detail4 == 'Gas'
			userHeatingSystemFuel = 'NATURAL_GAS'
		elsif detail4 == 'Oil'
			userHeatingSystemFuel = 'FUEL_OIL'
		elsif detail4 == 'Propane'
			userHeatingSystemFuel = 'PROPANE'
		elsif detail4 == 'Electric'
			userHeatingSystemFuel = 'ELECTRICITY'
		end
	elsif detail3 == 'Baseboard'
		#TODO: Current code creates two hvac objects. One for central systems (AC/furnace/boiler) and one for zone level systems (e.g., baseboards)
		userHeatingSystemType = 'ELECTRIC_BASEBOARD'
		userHeatingSystemFuel = 'ELECTRICITY'
	elsif detail3 == 'NoHeat'
		userHeatingSystemType = 'NULL_HST'
		userHeatingSystemFuel = 'NULL'
	else
		userHeatingSystemType = 'NULL_HST'
		userHeatingSystemFuel = 'NULL'
	end

	#runner.registerInfo("User Heating System = #{detail3}, #{detail4}, #{userHeatingSystemType}, #{userHeatingSystemFuel}.")

	heatPumpType = nil
	heatPumpFuel = nil
	backUpType = nil
	backUpSystemFuel = nil
	coolingSystemType = nil
	coolingSystemFuel = nil
	heatingSystemType = nil
	heatingSystemFuel = nil
	geothermalLoopTransfer = nil
	geothermalLoopType = nil
	geothermalLoopLength = nil

	# Create the empty HVAC system array.
	hvac_sys = []
	heatPumps = []
	coolingSystems = []
	heatingSystems = []
	cooling_coil_type = nil
	cooling_coil_capacity = nil
	cooling_coil_eff = nil
	cooling_coil_eff_unit = nil
	cooling_coil_fuel = nil

	heating_coil_type = nil
	heating_coil_capacity = nil
	heating_coil_eff = nil
	heating_coil_eff_unit = nil
	heating_coil_fuel = nil

	heating_coil_type_1 = nil
	heating_coil_capacity_1 = nil
	heating_coil_eff_1 = nil
	heating_coil_eff_unit_1 = nil
	heating_coil_fuel_1 = nil

	heating_coil_type_2 = nil
	heating_coil_capacity_2 = nil
	heating_coil_eff_2 = nil
	heating_coil_eff_unit_2 = nil
	heating_coil_fuel_2 = nil

	backup_coil_type = nil
	backup_coil_capacity = nil
	backup_coil_capacity = nil
	backup_coil_eff = nil
	backup_coil_fuel = nil

	#loop through air loops
	airLoops = model.getAirLoopHVACs
	airLoops.each do |airLoop|

		isHeatPump = false
		isTemplateSystem = false
		heating_coil_1_found = false
		heating_coil_2_found = false
		# loop through supply components
		airLoop.supplyComponents.each do |sc|
			#runner.registerInfo("supply component = #{sc}.")
			#runner.registerInfo("supply component methods = #{sc.methods.sort}.")

			#check if this supply component is a system
			if sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
				#get info from unitary heatpump air to air
				uhpata = sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
				isHeatPump = true
				isTemplateSystem = true
				#runner.registerInfo("template unitary A2A system found = #{uhpata}.")

				if uhpata.heatingCoil.is_initialized
					heatingCoil = uhpata.heatingCoil.get
					heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(heatingCoil, runner)
				end

				if uhpata.coolingCoil.is_initialized
					coolingCoil = uhpata.coolingCoil.get
					cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(coolingCoil, runner)
				end

				if uhpata.supplementalHeatingCoil.is_initialized
					supplementalHeatingCoil = uhpata.supplementalHeatingCoil.get
					backup_coil_type, backup_coil_capacity, backup_coil_eff, backup_coil_eff_unit, backup_coil_fuel = get_heating_coil_info(supplementalHeatingCoil, runner)
				end
				if detail4 == 'Std'
					heatPumpType = 'AIR_TO_AIR_STD'
				else
					heatPumpType = 'AIR_TO_AIR_SDHV'
				end
				if heating_coil_type == 'DX Single Speed'
					heatPumpFuel = 'ELECTRICITY_HPF'
				else
					heatPumpFuel = 'NULL_HPF'
				end
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				if backup_coil_type != nil
					backUpType = 'INTEGRATED'
				else
					backUpType = 'NULL_BT'
				end
				if backup_coil_type == 'DX Single Speed'
					backUpSystemFuel = 'ELECTRICITY'
				else
					backUpSystemFuel = 'NULL'
				end
				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'NULL_HST'
				heatingSystemFuel = 'NULL'
			end
			if sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
				#get info from unitary heat pump air to air MS
				uhpatams = sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
				isHeatPump = true
				isTemplateSystem = true
				#runner.registerInfo("template unitary A2A MS system found = #{uhpatams}.")

				if uhpatams.heatingCoil.is_initialized
					heatingCoil = uhpatams.heatingCoil.get
					heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(heatingCoil, runner)
				end

				if uhpatams.coolingCoil.is_initialized
					coolingCoil = uhpatams.coolingCoil.get
					cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(coolingCoil, runner)
				end

				if uhpatams.supplementalHeatingCoil.is_initialized
					supplementalHeatingCoil = uhpatams.supplementalHeatingCoil.get
					backup_coil_type, backup_coil_capacity, backup_coil_eff, backup_coil_eff_unit, backup_coil_fuel = get_heating_coil_info(supplementalHeatingCoil, runner)
				end
				if detail4 == 'Std'
					heatPumpType = 'AIR_TO_AIR_STD'
				else
					heatPumpType = 'AIR_TO_AIR_SDHV'
				end
				if heating_coil_type == 'DX Multi Speed'
					heatPumpFuel = 'ELECTRICITY_HPF'
				else
					heatPumpFuel = 'NULL_HPF'
				end
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				if backup_coil_type != nil
					backUpType = 'INTEGRATED'
				else
					backUpType = 'NULL_BT'
				end
				if backup_coil_type == 'DX Multi Speed'
					backUpSystemFuel = 'ELECTRICITY'
				else
					backUpSystemFuel = 'NULL'
				end
				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'NULL_HST'
				heatingSystemFuel = 'NULL'
			end
			if sc.to_AirLoopHVACUnitarySystem.is_initialized
				#get info from unitary system
				us = sc.to_AirLoopHVACUnitarySystem.get
				#runner.registerInfo("template unitary system found = #{us}.")
				#runner.registerInfo("unitary system methods = #{us.methods.sort}.")
				isTemplateSystem = true

				if us.heatingCoil.is_initialized
					heatingCoil = us.heatingCoil.get
					heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(heatingCoil, runner)
				end

				if us.coolingCoil.is_initialized
					coolingCoil = us.coolingCoil.get
					cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(coolingCoil, runner)
				end

				if us.supplementalHeatingCoil.is_initialized
					supplementalHeatingCoil = us.supplementalHeatingCoil.get
					backup_coil_type, backup_coil_capacity, backup_coil_eff, backup_coil_eff_unit, backup_coil_fuel = get_heating_coil_info(supplementalHeatingCoil, runner)
				end
				runner.registerInfo("cooling_coil_type = #{cooling_coil_type}.")
				#runner.registerInfo("cooling_coil_capacity = #{cooling_coil_capacity}.")
				#runner.registerInfo("cooling_coil_eff = #{cooling_coil_eff}.")
				#runner.registerInfo("cooling_coil_eff_unit = #{cooling_coil_eff_unit}.")
				#runner.registerInfo("cooling_coil_fuel = #{cooling_coil_fuel}.")
				runner.registerInfo("heating_coil_type = #{heating_coil_type}.")
				#runner.registerInfo("heating_coil_capacity = #{heating_coil_capacity}.")
				#runner.registerInfo("heating_coil_eff = #{heating_coil_eff}.")
				#runner.registerInfo("heating_coil_eff_unit = #{heating_coil_eff_unit}.")
				#runner.registerInfo("heating_coil_fuel = #{heating_coil_fuel}.")
				runner.registerInfo("backup_coil_type = #{backup_coil_type}.")
				#runner.registerInfo("backup_coil_capacity = #{backup_coil_capacity}.")
				#runner.registerInfo("backup_coil_eff = #{backup_coil_eff}.")
				#runner.registerInfo("backup_coil_eff_unit = #{backup_coil_eff_unit}.")
				#runner.registerInfo("backup_coil_fuel = #{backup_coil_fuel}.")

				if (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (not heating_coil_type.nil? and heating_coil_type.include? 'DX')
					isHeatPump = true
					if detail4 == 'Std'
						#runner.registerInfo("Unitary A2A heat pump STD found")
						heatPumpType = 'AIR_TO_AIR_STD'
					elsif detail4 == 'SDHV'
						#runner.registerInfo("Unitary A2A heat pump SDHV found")
						heatPumpType = 'AIR_TO_AIR_SDHV'
					else
						#runner.registerInfo("Unitary A2A heat pump Other found")
						heatPumpType = 'AIR_TO_AIR_OTHER'
					end
					heatPumpFuel = 'ELECTRICITY_HPF'
					geothermalLoopTransfer = 'NULL'
					geothermalLoopType = 'NULL_GLT'
					if backup_coil_type != nil
						backUpType = 'INTEGRATED'
					else
						backUpType = 'NULL_BT'
					end
					backUpSystemFuel = 'ELECTRICITY'
					coolingSystemType = 'NULL_CST'
					coolingSystemFuel = 'NULL'
					heatingSystemType = 'NULL_HST'
					heatingSystemFuel = 'NULL'
				elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'ELECTRICITY'))
					isHeatPump = false
					#runner.registerInfo("Unitary AC+Furnace Electric found")
					coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
					coolingSystemFuel = 'ELECTRICITY'
					heatingSystemType = 'FURNACE'
					heatingSystemFuel = 'ELECTRICITY'

					heatPumpType = 'NULL_HPT'
					heatPumpFuel = 'NULL_HPF'
					geothermalLoopTransfer = 'NULL'
					geothermalLoopType = 'NULL_GLT'
					backUpType = 'NULL_BT'
					backUpSystemFuel = 'NULL'
				elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'NATURAL_GAS'))
					isHeatPump = false
					#runner.registerInfo("Unitary AC+Furnace Gas found")
					coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
					coolingSystemFuel = 'ELECTRICITY'
					heatingSystemType = 'FURNACE'
					heatingSystemFuel = 'NATURAL_GAS'

					heatPumpType = 'NULL_HPT'
					heatPumpFuel = 'NULL_HPF'
					geothermalLoopTransfer = 'NULL'
					geothermalLoopType = 'NULL_GLT'
					backUpType = 'NULL_BT'
					backUpSystemFuel = 'NULL'
				elsif not cooling_coil_type.nil? and heating_coil_type.nil?
					isHeatPump = false
					#runner.registerInfo("Unitary AC + No Heating")
					coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
					coolingSystemFuel = 'ELECTRICITY'
					heatingSystemType = 'NULL'
					heatingSystemFuel = 'NULL'

					heatPumpType = 'NULL_HPT'
					heatPumpFuel = 'NULL_HPF'
					geothermalLoopTransfer = 'NULL'
					geothermalLoopType = 'NULL_GLT'
					backUpType = 'NULL_BT'
					backUpSystemFuel = 'NULL'
				elsif cooling_coil_type.nil? and (not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'NATURAL_GAS'))
					isHeatPump = false
					#runner.registerInfo("No AC + Furnace Gas")
					coolingSystemType = 'NULL_CST'
					coolingSystemFuel = 'ELECTRICITY'
					heatingSystemType = 'FURNACE'
					heatingSystemFuel = 'NATURAL_GAS'

					heatPumpType = 'NULL_HPT'
					heatPumpFuel = 'NULL_HPF'
					geothermalLoopTransfer = 'NULL'
					geothermalLoopType = 'NULL_GLT'
					backUpType = 'NULL_BT'
					backUpSystemFuel = 'NULL'
				elsif cooling_coil_type.nil? and (not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'ELECTRICITY'))
					isHeatPump = false
					#runner.registerInfo("No AC + Furnace Electric found")
					coolingSystemType = 'NULL_CST'
					coolingSystemFuel = 'ELECTRICITY'
					heatingSystemType = 'FURNACE'
					heatingSystemFuel = 'ELECTRICITY'

					heatPumpType = 'NULL_HPT'
					heatPumpFuel = 'NULL_HPF'
					geothermalLoopTransfer = 'NULL'
					geothermalLoopType = 'NULL_GLT'
					backUpType = 'NULL_BT'
					backUpSystemFuel = 'NULL'
				elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'CoilCoolingWater') and (not heating_coil_type.nil? and heating_coil_type.include? 'CoilHeatingWater')
					isHeatPump = true
					#runner.registerInfo("Unitary W2A Heat pump found")
					heatPumpType = 'WATER_TO_AIR'
					heatPumpFuel = 'ELECTRICITY_HPF'
					geothermalLoopTransfer = 'CLOSED' # defaulted to closed
					if detail4 == 'Horizontal'
						geothermalLoopType = 'HORIZONTAL'
					elsif detail4 == 'Vertical'
						geothermalLoopType = 'VERTICAL'
					elsif detail4 == 'Slinky'
						geothermalLoopType = 'SLINKY'
					end
					backUpType = 'INTEGRATED'
					backUpSystemFuel = 'ELECTRICITY'
					# determine the bore length
					geothermalLoopLength = determineGeothermalLength(coolingCoil, runner)

					coolingSystemType = 'NULL_CST'
					coolingSystemFuel = 'NULL'
					heatingSystemType = 'NULL_HST'
					heatingSystemFuel = 'NULL'
				else
					runner.registerError("Unitary HVAC System is not recognized.")
				end
			end
			#TODO: add CentralHeatPumpSystem, water-to-air heat pump templates ?
			# search heat loop for heating coils
			# search cooling loop for cooling coils
			#TODO: more systems to add ? (horizontal geothermal, hot water baseboard?)

			#check for coils directly in the supply component list
			# not sure what to do if there are more than one
			if is_heating_coil(sc)
				if not heating_coil_1_found
					heating_coil_type_1, heating_coil_capacity_1, heating_coil_eff_1, heating_coil_eff_unit_1, heating_coil_fuel_1 = get_heating_coil_info(sc, runner)
					if heating_coil_type_1 == 'CoilHeatingWater'
						geothermalLoopLength = determineGeothermalLength(sc, runner)
					end
					heating_coil_1_found = true
				else
					heating_coil_type_2, heating_coil_capacity_2, heating_coil_eff_2, heating_coil_eff_unit_2, heating_coil_fuel_2 = get_heating_coil_info(sc, runner)
					if heating_coil_type_2 == 'CoilHeatingWater'
						geothermalLoopLength = determineGeothermalLength(sc, runner)
					end
					heating_coil_2_found = true
				end
			end
			if is_cooling_coil(sc)
				cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(sc, runner)
			end
		end
		#if not a template system then try to determine the system based on the coils. This is where central ac + baseboards need to be addressed.
		if not isTemplateSystem
			#if two heating coils are found then determine primary vs secondary coil
			if heating_coil_1_found and heating_coil_2_found
				#runner.registerInfo("found two heating coils = #{heating_coil_type_1}, #{heating_coil_type_2}.")
				if heating_coil_type_1.include? 'DX'
					#runner.registerInfo("Coil one is DX so its primary.")
					heating_coil_type = heating_coil_type_1
					heating_coil_capacity = heating_coil_capacity_1
					heating_coil_eff = heating_coil_eff_1
					heating_coil_eff_unit = heating_coil_eff_unit_1
					heating_coil_fuel = heating_coil_fuel_1

					backup_coil_type = heating_coil_type_2
					backup_coil_capacity = heating_coil_capacity_2
					backup_coil_eff = heating_coil_eff_2
					backup_coil_eff_unit = heating_coil_eff_unit_2
					backup_coil_fuel = heating_coil_fuel_2
				elsif heating_coil_type_2.include? 'DX'
					#runner.registerInfo("Coil two is DX so its primary.")
					heating_coil_type = heating_coil_type_2
					heating_coil_capacity = heating_coil_capacity_2
					heating_coil_eff = heating_coil_eff_2
					heating_coil_eff_unit = heating_coil_eff_unit_2
					heating_coil_fuel = heating_coil_fuel_2

					backup_coil_type = heating_coil_type_1
					backup_coil_capacity = heating_coil_capacity_1
					backup_coil_eff = heating_coil_eff_1
					backup_coil_eff_unit = heating_coil_eff_unit_1
					backup_coil_fuel = heating_coil_fuel_1
				elsif heating_coil_type_1.include? 'Water'
					#runner.registerInfo("Coil one is W2A so its primary.")
					heating_coil_type = heating_coil_type_1
					heating_coil_capacity = heating_coil_capacity_1
					heating_coil_eff = heating_coil_eff_1
					heating_coil_eff_unit = heating_coil_eff_unit_1
					heating_coil_fuel = heating_coil_fuel_1

					backup_coil_type = heating_coil_type_2
					backup_coil_capacity = heating_coil_capacity_2
					backup_coil_eff = heating_coil_eff_2
					backup_coil_eff_unit = heating_coil_eff_unit_2
					backup_coil_fuel = heating_coil_fuel_2
				elsif heating_coil_type_2.include? 'Water'
					#runner.registerInfo("Coil two is W2A so its primary.")
					heating_coil_type = heating_coil_type_2
					heating_coil_capacity = heating_coil_capacity_2
					heating_coil_eff = heating_coil_eff_2
					heating_coil_eff_unit = heating_coil_eff_unit_2
					heating_coil_fuel = heating_coil_fuel_2

					backup_coil_type = heating_coil_type_1
					backup_coil_capacity = heating_coil_capacity_1
					backup_coil_eff = heating_coil_eff_1
					backup_coil_eff_unit = heating_coil_eff_unit_1
					backup_coil_fuel = heating_coil_fuel_1
				elsif heating_coil_fuel_1 == 'NATURAL_GAS' and heating_coil_fuel_2 != 'NATURAL_GAS'
					#runner.registerInfo("Coil one is gas so its primary.")
					heating_coil_type = heating_coil_type_1
					heating_coil_capacity = heating_coil_capacity_1
					heating_coil_eff = heating_coil_eff_1
					heating_coil_eff_unit = heating_coil_eff_unit_1
					heating_coil_fuel = heating_coil_fuel_1

					backup_coil_type = heating_coil_type_2
					backup_coil_capacity = heating_coil_capacity_2
					backup_coil_eff = heating_coil_eff_2
					backup_coil_eff_unit = heating_coil_eff_unit_2
					backup_coil_fuel = heating_coil_fuel_2
				elsif heating_coil_fuel_2 == 'NATURAL_GAS' and heating_coil_fuel_1 != 'NATURAL_GAS'
					#runner.registerInfo("Coil two is gas so its primary.")
					heating_coil_type = heating_coil_type_2
					heating_coil_capacity = heating_coil_capacity_2
					heating_coil_eff = heating_coil_eff_2
					heating_coil_eff_unit = heating_coil_eff_unit_2
					heating_coil_fuel = heating_coil_fuel_2

					backup_coil_type = heating_coil_type_1
					backup_coil_capacity = heating_coil_capacity_1
					backup_coil_eff = heating_coil_eff_1
					backup_coil_eff_unit = heating_coil_eff_unit_1
					backup_coil_fuel = heating_coil_fuel_1
				elsif heating_coil_capacity_1 > heating_coil_capacity_2
					#runner.registerInfo("Coil one has a larger capacity so its primary.")
					heating_coil_type = heating_coil_type_1
					heating_coil_capacity = heating_coil_capacity_1
					heating_coil_eff = heating_coil_eff_1
					heating_coil_eff_unit = heating_coil_eff_unit_1
					heating_coil_fuel = heating_coil_fuel_1

					backup_coil_type = heating_coil_type_2
					backup_coil_capacity = heating_coil_capacity_2
					backup_coil_eff = heating_coil_eff_2
					backup_coil_eff_unit = heating_coil_eff_unit_2
					backup_coil_fuel = heating_coil_fuel_2
				else
					#runner.registerInfo("Coil two has a larger capacity so its primary.")
					heating_coil_type = heating_coil_type_2
					heating_coil_capacity = heating_coil_capacity_2
					heating_coil_eff = heating_coil_eff_2
					heating_coil_eff_unit = heating_coil_eff_unit_2
					heating_coil_fuel = heating_coil_fuel_2

					backup_coil_type = heating_coil_type_1
					backup_coil_capacity = heating_coil_capacity_1
					backup_coil_eff = heating_coil_eff_1
					backup_coil_eff_unit = heating_coil_eff_unit_1
					backup_coil_fuel = heating_coil_fuel_1
				end
			elsif heating_coil_1_found
				heating_coil_type = heating_coil_type_1
				heating_coil_capacity = heating_coil_capacity_1
				heating_coil_eff = heating_coil_eff_1
				heating_coil_eff_unit = heating_coil_eff_unit_1
				heating_coil_fuel = heating_coil_fuel_1
				#runner.registerInfo("Heating Coil Specs: #{heating_coil_type},#{heating_coil_capacity},#{heating_coil_eff},#{heating_coil_eff_unit}, and #{heating_coil_fuel}.")

				backup_coil_type = nil
				backup_coil_capacity = nil
				backup_coil_eff = nil
				backup_coil_eff_unit = nil
				backup_coil_fuel = nil
			end


			runner.registerInfo("cooling_coil_type = #{cooling_coil_type}.")
			#runner.registerInfo("cooling_coil_capacity = #{cooling_coil_capacity}.")
			#runner.registerInfo("cooling_coil_eff = #{cooling_coil_eff}.")
			#runner.registerInfo("cooling_coil_eff_unit = #{cooling_coil_eff_unit}.")
			#runner.registerInfo("cooling_coil_fuel = #{cooling_coil_fuel}.")
			runner.registerInfo("heating_coil_type = #{heating_coil_type}.")
			#runner.registerInfo("heating_coil_capacity = #{heating_coil_capacity}.")
			#runner.registerInfo("heating_coil_eff = #{heating_coil_eff}.")
			#runner.registerInfo("heating_coil_eff_unit = #{heating_coil_eff_unit}.")
			#runner.registerInfo("heating_coil_fuel = #{heating_coil_fuel}.")
			runner.registerInfo("backup_coil_type = #{backup_coil_type}.")
			#runner.registerInfo("backup_coil_capacity = #{backup_coil_capacity}.")
			#runner.registerInfo("backup_coil_eff = #{backup_coil_eff}.")
			#runner.registerInfo("backup_coil_eff_unit = #{backup_coil_eff_unit}.")
			#runner.registerInfo("backup_coil_fuel = #{backup_coil_fuel}.")

			# don't proceed if no heating coil and no cooling coil is found
			if cooling_coil_type.nil? and heating_coil_type.nil?
				runner.registerError("No heating and cooling coils found in an air loop.")
				return
			end
			# check for different combinations of coils.
			# DX heating and cooling coils
			if (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (not heating_coil_type.nil? and heating_coil_type.include? 'DX')
				isHeatPump = true
				if detail4 == 'Std'
					#runner.registerInfo("A2A heat pump STD found")
					heatPumpType = 'AIR_TO_AIR_STD'
				else
					#runner.registerInfo("A2A heat pump SDHV found")
					heatPumpType = 'AIR_TO_AIR_SDHV'
				end
				heatPumpFuel = 'ELECTRICITY_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'NULL_HST'
				heatingSystemFuel = 'NULL'
			# DX cooling coil (central AC) and furnace
			elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (not heating_coil_type.nil? and heating_coil_type.include? 'Furnace')
				isHeatPump = false
				#runner.registerInfo("AC+Furnace found")
				coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
				coolingSystemFuel = 'ELECTRICITY'
				heatingSystemType = 'FURNACE'
				heatingSystemFuel = heating_coil_fuel

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# No AC and furnace
			elsif cooling_coil_type.nil? and (not heating_coil_type.nil? and heating_coil_type.include? 'Furnace')
				isHeatPump = false
				#runner.registerInfo("No AC + Furnace found")
				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'FURNACE'
				heatingSystemFuel = heating_coil_fuel

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# DX cooling coil (central AC) and Water heated coil (boiler)
			elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (not heating_coil_type.nil? and heating_coil_type.include? 'CoilHeatingWater')
				isHeatPump = false
				#runner.registerInfo("AC+Boiler #{heating_coil_fuel} found")
				coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
				coolingSystemFuel = 'ELECTRICITY'
				heatingSystemType = 'BOILER'
				#TODO: determine fuel type via boiler:hotwater
				heatingSystemFuel = heating_coil_fuel

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# no AC and Water heated coil (boiler)
			elsif cooling_coil_type.nil? and (not heating_coil_type.nil? and heating_coil_type.include? 'CoilHeatingWater')
				isHeatPump = false
				#runner.registerInfo("No AC + Boiler found")
				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'BOILER'
				#TODO: determine fuel type via boiler:hotwater
				heatingSystemFuel = heating_coil_fuel

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# DX cooling coil (central AC) and user specified electric baseboard heating
			elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (heating_coil_type.nil? and userHeatingSystemType.include? 'ELECTRIC_BASEBOARD')
				isHeatPump = false
				#runner.registerInfo("AC + No Central Heating found - assume electric baseboard heating")
				coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
				coolingSystemFuel = 'ELECTRICITY'
				heatingSystemType = 'ELECTRIC_BASEBOARD'
				heatingSystemFuel = 'ELECTRICITY'

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# No AC and user specified electric baseboard heating
			elsif cooling_coil_type.nil? and (heating_coil_type.nil? and userHeatingSystemType.include? 'ELECTRIC_BASEBOARD')
				isHeatPump = false
				#runner.registerInfo("No AC + No Central Heating found - assume electric baseboard heating")
				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'ELECTRIC_BASEBOARD'
				heatingSystemFuel = 'ELECTRICITY'

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# DX cooling coil (central AC) and no heating
			elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'DX') and (heating_coil_type.nil? and not userHeatingSystemType.include? 'ELECTRIC_BASEBOARD')
				isHeatPump = false
				#runner.registerInfo("AC + No Central Heating found - assume no central or zone heating")
				coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
				coolingSystemFuel = 'ELECTRICITY'
				heatingSystemType = 'NULL_HST'
				heatingSystemFuel = 'NULL'

				heatPumpType = 'NULL_HPT'
				heatPumpFuel = 'NULL_HPF'
				geothermalLoopTransfer = 'NULL'
				geothermalLoopType = 'NULL_GLT'
				backUpType = 'NULL_BT'
				backUpSystemFuel = 'NULL'
			# Water to Air Heat pumps (water to air in the type of coil).
			elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'WaterToAir') and (not heating_coil_type.nil? and heating_coil_type.include? 'WaterToAir')
				isHeatPump = true
				#runner.registerInfo("W2A Heat pump found")
				heatPumpType = 'WATER_TO_AIR'
				heatPumpFuel = 'ELECTRICITY_HPF'
				geothermalLoopTransfer = 'CLOSED' # defaulted to closed
				if detail4 == 'Horizontal'
					geothermalLoopType = 'HORIZONTAL'
				elsif detail4 == 'Vertical'
					geothermalLoopType = 'VERTICAL'
				elsif detail4 == 'Slinky'
					geothermalLoopType = 'SLINKY'
				end
				backUpType = 'INTEGRATED'
				backUpSystemFuel = 'ELECTRICITY'

				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'NULL_HST'
				heatingSystemFuel = 'NULL'
			# Water heating and water cooling coils (water-to-air heat pump with geothermal) - ignoring district heating/cooling in houses
			elsif (not cooling_coil_type.nil? and cooling_coil_type.include? 'CoilCoolingWater') and (not heating_coil_type.nil? and heating_coil_type.include? 'CoilHeatingWater')
				isHeatPump = true
				#runner.registerInfo("W2A Heat pump found")
				heatPumpType = 'WATER_TO_AIR'
				heatPumpFuel = 'ELECTRICITY_HPF'
				geothermalLoopTransfer = 'CLOSED' # defaulted to closed
				if detail4 == 'Horizontal'
					geothermalLoopType = 'HORIZONTAL'
				elsif detail4 == 'Vertical'
					geothermalLoopType = 'VERTICAL'
				elsif detail4 == 'Slinky'
					geothermalLoopType = 'SLINKY'
				end
				backUpType = 'INTEGRATED'
				backUpSystemFuel = 'ELECTRICITY'

				coolingSystemType = 'NULL_CST'
				coolingSystemFuel = 'NULL'
				heatingSystemType = 'NULL_HST'
				heatingSystemFuel = 'NULL'
			else
				#runner.registerError("HVAC System is not a template system and is not recognized.")
			end
		end

		#runner.registerInfo("Heating Coil has efficiency of #{heating_coil_eff} and capacity of #{heating_coil_capacity}.")
		#runner.registerInfo("Heating System Type is #{heatingSystemType}.")
		#runner.registerInfo("Coolinging Coil has efficiency of #{cooling_coil_eff} and capacity of #{cooling_coil_capacity}.")
		#runner.registerInfo("Cooling System Type is #{coolingSystemType}.")
		#runner.registerInfo("Heat Pump Type is #{heatPumpType}.")
		#runner.registerInfo("Heat Pump Back Up Type is #{backUpType}.")
		#runner.registerInfo("Geothermal is #{geothermalLoopType}.")
		#runner.registerInfo("Combining User inputs and coil details to create HVAC system objects.")

		#runner.registerInfo("Cooling System: user - #{userCoolingSystemType}, model - #{coolingSystemType}.")
		#runner.registerInfo("Cooling System Fuel: user - #{userCoolingSystemFuel}, model - #{coolingSystemFuel}.")
		#runner.registerInfo("Heating System: user - #{userHeatingSystemType}, model - #{heatingSystemType}.")
		#runner.registerInfo("Heating System Fuel: user - #{userHeatingSystemFuel}, model - #{heatingSystemFuel}.")
		#runner.registerInfo("Heat Pump Type: user - #{userHeatPumpType}, model - #{heatPumpType}.")
		#runner.registerInfo("Heat Pump Fuel: user - #{userHeatPumpFuel}, model - #{heatPumpFuel}.")
		#runner.registerInfo("Backup Type: user - #{userBackUpType}, model - #{backUpType}.")
		#runner.registerInfo("Backup Fuel: user - #{userBackUpSystemFuel}, model - #{backUpSystemFuel}.")
		#runner.registerInfo("Geothermal Type: user - #{userGeothermalLoopType}, model - #{geothermalLoopType}.")
		#runner.registerInfo("Geothermal Transfer Type: user - #{userGeothermalLoopTransfer}, model - #{geothermalLoopTransfer}.")

		if userHeatPumpType != heatPumpType
			runner.registerError("User heatpump type does not match model. User: #{userHeatPumpType}, Model: #{heatPumpType}")
		end
		if userHeatPumpFuel != heatPumpFuel
			runner.registerError("User heatpump fuel does not match model. User: #{userHeatPumpFuel}, Model: #{heatPumpFuel}")
		end
		if userBackUpType != backUpType
			runner.registerError("User backup type does not match model. User: #{userBackUpType}, Model: #{backUpType}")
		end
		if userBackUpSystemFuel != backUpSystemFuel
			runner.registerError("User backup fuel type does not match model. User: #{userBackUpSystemFuel}, Model: #{backUpSystemFuel}")
		end
		if userCoolingSystemType != coolingSystemType
			runner.registerError("User cooling system type does not match model. User: #{userCoolingSystemType}, Model: #{coolingSystemType}")
		end
		if userCoolingSystemFuel != coolingSystemFuel
			runner.registerError("User cooling system fuel type does not match model. User: #{userCoolingSystemFuel}, Model: #{coolingSystemFuel}")
		end
		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end
		if userGeothermalLoopTransfer != geothermalLoopTransfer
			runner.registerError("User geothermal loop transfer does not match model. User: #{userGeothermalLoopTransfer}, Model: #{geothermalLoopTransfer}")
		end
		if userGeothermalLoopType != geothermalLoopType
			runner.registerError("User geothermal loop type does not match model. User: #{userGeothermalLoopType}, Model: #{geothermalLoopType}")
		end

		if isHeatPump
			#runner.registerInfo("Successfully identified the Heat Pump as #{heatPumpType}.")
			if heatPumpType != 'NULL_HPT'
				heatpump_sys = {
					'heatPumpType' => heatPumpType,
					'heatPumpFuel' => heatPumpFuel,
					'heatingCapacity' => heating_coil_capacity,
					'coolingCapacity' => cooling_coil_capacity,
					'annualCoolingEfficiency' => {
						'value' => cooling_coil_eff,
						'unit' => cooling_coil_eff_unit
					},
					'annualHeatingEfficiency' => {
						'value' => heating_coil_eff,
						'unit' => heating_coil_eff_unit
					},
					#'geothermalLoopTransfer' => geothermalLoopTransfer,
					'geothermalLoopType' => geothermalLoopType,
					'geothermalLoopLength' => geothermalLoopLength,
					'backupType' => backUpType,
					'backUpSystemFuel' => backUpSystemFuel,
					'backUpAfue' => backup_coil_eff,
					'backUpHeatingCapacity' => backup_coil_capacity
				}
			else
				heatpumpt_sys = {}
			end
			#runner.registerInfo("HVAC system is a heat pump.")
			#runner.registerInfo("HVAC system is a #{heatpump_sys}.")
			heatPumps << heatpump_sys

		else
			if coolingSystemType != 'NULL_CST' and cooling_coil_capacity != nil
			cooling_sys = {
				'coolingSystemType' => coolingSystemType,
				'coolingSystemFuel' => coolingSystemFuel,
				'coolingCapacity' => cooling_coil_capacity,
				'annualCoolingEfficiency' => {
					'value' => cooling_coil_eff,
					'unit' => cooling_coil_eff_unit
				}
			}
			else
				cooling_sys = {}
			end
			if heatingSystemType != 'NULL_HST' and heating_coil_capacity != nil
				heating_sys = {
					'heatingSystemType' => heatingSystemType,
					'heatingSystemFuel' => heatingSystemFuel,
					'heatingCapacity' => heating_coil_capacity,
					'annualHeatingEfficiency' => {
						'value' => heating_coil_eff,
						'unit' => 'PERCENT'				#heating_coil_eff_unit is null
					}
				}
			else
				heating_sys = {}
			end
			#runner.registerInfo("HVAC system is not a heat pump.")
			#runner.registerInfo("HVAC system is #{cooling_sys} and #{heating_sys}.")

			coolingSystems << cooling_sys
			heatingSystems << heating_sys
		end
		hvac_sys << {
			'heatPumps' => heatPumps,
			'coolingSystems' => coolingSystems,
			'heatingSystems' => heatingSystems
		}

	end
	#runner.registerInfo("All Heating and Cooling System have been populated: #{hvac_sys}.")
	@heatingSystemType = heatingSystemType
	@heatingSystemFuel = heatingSystemFuel
	#runner.registerInfo("Heating System Fuel: #{heatingSystemFuel}.")
	@heatPumpType = heatPumpType
	zone_unit_sys = []
	zone_unit_sys = get_zone_units(model, runner, idf, userHeatingSystemType, userHeatingSystemFuel, userHeatPumpType, ductwork)
	#runner.registerInfo("Room Heating and Cooling Units populated: #{zone_unit_sys}.")
	if zone_unit_sys != []
		hvac_sys << zone_unit_sys
	end
	return hvac_sys
end

#find the geothermal length given a coil which is either CoilCoolingWater or CoilHeatingWater or WaterToAir in coil/template
def determineGeothermalLength(coil, runner)

	geothermalLength = nil

	if coil.to_CoilHeatingWater.is_initialized
		chw = coil.to_CoilHeatingWater.get
		#runner.registerInfo("CoilHeatingWater found = #{chw}.")

		# get the plant loop used by this coil
		if chw.plantLoop.is_initialized
			plantLoop = chw.plantLoop.get
		else
			runner.registerError("For CoilHeatingWater #{coil.name} plantLoop is not available.")
		end

		#look through the supply components for the heat exchanger
		plantLoop.supplyComponents.each do |sc|
			#runner.registerInfo("supplyComponent = #{sc}.")
			#runner.registerInfo("supplyComponent methods = #{sc.methods.sort}.")

			if sc.to_GroundHeatExchangerVertical.is_initialized
				ghev = sc.to_GroundHeatExchangerVertical.get
				#runner.registerInfo("GroundHeatExchangerVertical = #{ghev}.")
				#runner.registerInfo("GroundHeatExchangerVertical methods = #{ghev.methods.sort}.")

				boreHoleLength = nil
				if ghev.boreHoleLength.is_initialized
					boreHoleLength = ghev.boreHoleLength.get
				else
					runner.registerError("No bore hole length for this heat exchanger.")
				end
				numberofBoreHoles = nil
				if ghev.numberofBoreHoles.is_initialized
					numberofBoreHoles = ghev.numberofBoreHoles.get
				else
					runner.registerError("No number of bore holes for this heat exchanger.")
				end
				#runner.registerInfo("boreHoleLength = #{ghev.boreHoleLength.get}.")
				#runner.registerInfo("numberofBoreHoles = #{ghev.numberofBoreHoles.get}.")
				geothermalLength = boreHoleLength * numberofBoreHoles
				#runner.registerInfo("geothermalLength = #{geothermalLength}.")
			elsif sc.to_GroundHeatExchangerHorizontalTrench.is_initialized
				gheht = sc.to_GroundHeatExchangerHorizontalTrench.get
				#runner.registerInfo("GroundHeatExchangerHorizontalTrench = #{gheht}.")
				#runner.registerInfo("GroundHeatExchangerHorizontalTrench methods = #{gheht.methods.sort}.")

				trenchLength = nil
				if ghev.trenchLengthinPipeAxialDirection.is_initialized
					trenchLength = ghev.trenchLengthinPipeAxialDirection.get
				else
					runner.registerError("No trench length for this heat exchanger.")
				end
				numberofTrenches = nil
				if ghev.numberofTrenches.is_initialized
					numberofTrenches = ghev.numberofTrenches.get
				else
					runner.registerError("No number of trenches for this heat exchanger.")
				end
				#runner.registerInfo("trenchLength = #{trenchLength}.")
				#runner.registerInfo("numberofTrenches = #{numberofTrenches}.")
				geothermalLength = trenchLength * numberofTrenches
				#runner.registerInfo("geothermalLength = #{geothermalLength}.")
			end
		end
	elsif coil.to_CoilCoolingWater.is_initialized
		ccw = coil.to_CoilCoolingWater.get
		#runner.registerInfo("CoilCoolingWater found = #{ccw}.")
		#runner.registerInfo("CoilCoolingWater methods = #{ccw.methods.sort}.")

		# get the plant loop used by this coil
		if ccw.plantLoop.is_initialized
			plantLoop = ccw.plantLoop.get
		else
			runner.registerError("For CoilCoolingWater #{coil.name} plantLoop is not available.")
		end

		#look through the supply components for the heat exchanger
		plantLoop.supplyComponents.each do |sc|
			#runner.registerInfo("supplyComponent = #{sc}.")
			#runner.registerInfo("supplyComponent methods = #{sc.methods.sort}.")

			if sc.to_GroundHeatExchangerVertical.is_initialized
				ghev = sc.to_GroundHeatExchangerVertical.get
				#runner.registerInfo("GroundHeatExchangerVertical = #{ghev}.")
				#runner.registerInfo("GroundHeatExchangerVertical methods = #{ghev.methods.sort}.")

				boreHoleLength = nil
				if ghev.boreHoleLength.is_initialized
					boreHoleLength = ghev.boreHoleLength.get
				else
					runner.registerError("No bore hole length for this heat exchanger.")
				end
				numberofBoreHoles = nil
				if ghev.numberofBoreHoles.is_initialized
					numberofBoreHoles = ghev.numberofBoreHoles.get
				else
					runner.registerError("No number of bore holes for this heat exchanger.")
				end
				#runner.registerInfo("boreHoleLength = #{ghev.boreHoleLength.get}.")
				#runner.registerInfo("numberofBoreHoles = #{ghev.numberofBoreHoles.get}.")
				geothermalLength = boreHoleLength * numberofBoreHoles
				#runner.registerInfo("geothermalLength = #{geothermalLength}.")
			elsif sc.to_GroundHeatExchangerHorizontalTrench.is_initialized
				gheht = sc.to_GroundHeatExchangerHorizontalTrench.get
				#runner.registerInfo("GroundHeatExchangerHorizontalTrench = #{gheht}.")
				#runner.registerInfo("GroundHeatExchangerHorizontalTrench methods = #{gheht.methods.sort}.")

				trenchLength = nil
				if ghev.trenchLengthinPipeAxialDirection.is_initialized
					trenchLength = ghev.trenchLengthinPipeAxialDirection.get
				else
					runner.registerError("No trench length for this heat exchanger.")
				end
				numberofTrenches = nil
				if ghev.numberofTrenches.is_initialized
					numberofTrenches = ghev.numberofTrenches.get
				else
					runner.registerError("No number of trenches for this heat exchanger.")
				end
				#runner.registerInfo("trenchLength = #{trenchLength}.")
				#runner.registerInfo("numberofTrenches = #{numberofTrenches}.")
				geothermalLength = trenchLength * numberofTrenches
				#runner.registerInfo("geothermalLength = #{geothermalLength}.")
			end
		end
	else
		runner.registerError("Not given a water coil when one was expected.")
	end

	return geothermalLength
end

# Capture the zone level equipment. ZoneHVAC equipment and Coils included as zone equipment.
def get_zone_units(model, runner, idf, userHeatingSystemType, userHeatingSystemFuel, userHeatPumpType, ductwork)
	heatPumps = []
	coolingSystems = []
	heatingSystems = []
	zone_unit_sys = []
	ptac_hvac_systems = []

	#runner.registerInfo("model methods = #{model.methods.sort}.")

	# PTHP could be used to represent mini-split systems. Populate heat_pump_sys.
	model.getZoneHVACPackagedTerminalHeatPumps.each do |pTHP|
		#runner.registerInfo("PTHP loop has been entered.")

		if ductwork == 'None'
			pthp_type = 'MINI_SPLIT_NONDUCTED'
		else
			pthp_type = 'MINI_SPLIT_DUCTED'
		end

		cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(pTHP.coolingCoil, runner)
		#runner.registerInfo("Found PTHP Cooling Coil Info: #{cooling_coil_type}, #{cooling_coil_capacity},#{cooling_coil_eff}, and #{cooling_coil_eff_unit}.")

		heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(pTHP.heatingCoil, runner)
		#runner.registerInfo("Found PTHP Heating Coil Info: #{heating_coil_type}, #{heating_coil_capacity},#{heating_coil_eff}, and #{heating_coil_eff_unit}.")

		heatpump_sys = {
			'heatPumpType' => pthp_type,
			'heatPumpFuel' => 'ELECTRICITY_HPF',
			'heatingCapacity' => heating_coil_capacity,
			'coolingCapacity' => cooling_coil_capacity,
			'annualCoolingEfficiency' => {
				'value' => cooling_coil_eff,
				'unit' => cooling_coil_eff_unit
			},
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => heating_coil_eff_unit
			},
			#'geothermalLoopTransfer' => nil,
			'geothermalLoopType' => "NULL_GLT",
			'backupType' => 'NULL_BT',
			'backUpSystemFuel' => 'ELECTRICITY',
			'backUpAfue' => nil,
			'backUpHeatingCapacity' => nil
		}

		#runner.registerInfo("Created PTHP Sys: #{heatpump_sys}.")
		heatPumps << heatpump_sys
	end

	# PTAC systems include a heating coil - treated as a small furnace in BIRDS NEST.
	model.getZoneHVACPackagedTerminalAirConditioners.each do |pTAC|
		#runner.registerInfo("PTAC loop has been entered.")
		cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(pTAC.coolingCoil, runner)
		#runner.registerInfo("Found Cooling Info: #{cooling_coil_type}, #{cooling_coil_capacity},#{cooling_coil_eff}, and #{cooling_coil_eff_unit}.")

		cooling_sys = {
			'coolingSystemType' => 'ROOM_AIR_CONDITIONER',
			'coolingSystemFuel' => 'ELECTRICITY',
			'coolingCapacity' => cooling_coil_capacity,
			'annualCoolingEfficiency' => {
				'value' => cooling_coil_eff,
				'unit' => cooling_coil_eff_unit
			}
		}
		#runner.registerInfo("Created PTAC Cooling Sys: #{cooling_sys}.")
		coolingSystems << cooling_sys

		heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(pTAC.heatingCoil, runner)
		#runner.registerInfo("Found Heating Info: #{heating_coil_type}, #{userHeatingSystemFuel}, #{heating_coil_capacity},#{heating_coil_eff}, and #{heating_coil_eff_unit}.")


		if not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'ELECTRICITY')
			#runner.registerInfo("Room AC+Furnace Electric found")
			heatingSystemType = 'FURNACE'
			heatingSystemFuel = 'ELECTRICITY'
		elsif not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'NATURAL_GAS')
			#runner.registerInfo("Room AC+Furnace Gas found")
			heatingSystemType = 'FURNACE'
			heatingSystemFuel = 'NATURAL_GAS'
		else
			runner.registerError("pTAC unrecognized.")
		end

		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end

		heating_sys = {
			'heatingSystemType' => heatingSystemType,
			'heatingSystemFuel' => heatingSystemFuel,
			'heatingCapacity' => heating_coil_capacity,
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => 'PERCENT'
				}
			}

		#runner.registerInfo("Created PTAC Heating Sys: #{heating_sys}.")
		heatingSystems << heating_sys
	end
	#check IDF for ZoneHVAC:WindowAirConditioner - window AC units do not have a heating coil; this will need to be included as a separate unit.
	#model.getZoneHVACPackagedTerminalAirConditioners
	windowAirConditioners = idf.getObjectsByType("ZoneHVAC:WindowAirConditioner".to_IddObjectType)
	windowAirConditioners.each do |windowAirConditioner|
		coolingCoilName = windowAirConditioner.getString(11).get
		coolingCoilType = windowAirConditioner.getString(10).get
		coolingCoil = idf.getObjectByTypeAndName(coolingCoilType, coolingCoilName)
		if coolingCoilType == "Coil:Cooling:DX:SingleSpeed"
			cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit = get_coolingDXSingleSpeed_info_idf(coil, runner)
		elsif coolingCoilType == "Coil:Cooling:DX:VariableSpeed"

		elsif coolingCoilType == "CoilSystem:Cooling:DX:HeatExchangerAssisted"

		end
		#runner.registerInfo("Window AC found")

		cooling_sys = {
			'coolingSystemType' => 'ROOM_AIR_CONDITIONER',
			'coolingSystemFuel' => 'ELECTRICITY',
			'coolingCapacity' => cooling_coil_capacity,
			'annualCoolingEfficiency' => {
				'value' => cooling_coil_eff,
				'unit' => cooling_coil_eff_unit
			}
		}
		coolingSystems << cooling_sys
	end

	model.getZoneHVACBaseboardConvectiveElectrics.each do |bCE|
		#runner.registerInfo("ZoneHVACBaseboardConvectiveElectric = #{bCE}.")
		#runner.registerInfo("ZoneHVACBaseboardConvectiveElectric methods = #{bCE.methods.sort}.")

		capacity_w = nil
		if bCE.isNominalCapacityAutosized
			if bCE.autosizedNominalCapacity.is_initialized
				capacity_w = bCE.autosizedNominalCapacity.get
			else
				runner.registerError("ZoneHVACBaseboardConvectiveElectric cannot get autosized capacity.")
			end
		else
			if bCE.nominalCapacity.is_initialized
				capacity_w = bCE.nominalCapacity.get
			else
				runner.registerError("ZoneHVACBaseboardConvectiveElectric cannot get capacity.")
			end
		end
		heatingSystemType = 'ELECTRIC_BASEBOARD'
		heatingSystemFuel = 'ELECTRICITY'
		heating_coil_eff = bCE.efficiency

		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end

		heating_sys = {
			'heatingSystemType' => heatingSystemType,
			'heatingSystemFuel' => heatingSystemFuel,
			'heatingCapacity' => capacity_w.round(0),
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => 'PERCENT'
				}
			}

		runner.registerInfo("Created ZoneHVACBaseboardConvectiveElectric Sys: #{heating_sys}.")
		heatingSystems << heating_sys

	end

	model.getZoneHVACBaseboardConvectiveWaters.each do |bCW|
		#runner.registerInfo("ZoneHVACBaseboardConvectiveWater = #{bCW}.")
		#runner.registerInfo("ZoneHVACBaseboardConvectiveWater methods = #{bCW.methods.sort}.")

		# get the plant loop used by this
		if bCW.plantLoop.is_initialized
			plantLoop = bCW.plantLoop.get
		else
			runner.registerError("For ZoneHVACBaseboardConvectiveWater plantLoop is not available.")
		end

		capacity_w, heatingSystemFuel, heating_coil_eff, heating_coil_eff_unit = getBoilerInfo(plantLoop, runner)
		heatingSystemType = 'BOILER'

		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end
		heating_sys = {
			'heatingSystemType' => heatingSystemType,
			'heatingSystemFuel' => heatingSystemFuel,
			'heatingCapacity' => capacity_w,
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => heating_coil_eff_unit
				}
			}

		#runner.registerInfo("Created ZoneHVACBaseboardConvectiveWater Sys: #{heating_sys}.")
		heatingSystems << heating_sys

	end

	model.getZoneHVACBaseboardRadiantConvectiveElectrics.each do |bRCE|
		#runner.registerInfo("ZoneHVACBaseboardRadiantConvectiveElectric = #{bRCE}.")
		#runner.registerInfo("ZoneHVACBaseboardRadiantConvectiveElectric methods = #{bRCE.methods.sort}.")

		capacity_w = nil
		if bRCE.isHeatingDesignCapacityAutosized
			if bRCE.autosizedHeatingDesignCapacity.is_initialized
				capacity_w = bRCE.autosizedHeatingDesignCapacity.get
			else
				runner.registerError("ZoneHVACBaseboardRadiantConvectiveElectric cannot get autosized capacity.")
			end
		else
			if bRCE.heatingDesignCapacity.is_initialized
				capacity_w = bRCE.heatingDesignCapacity.get
			else
				runner.registerError("ZoneHVACBaseboardRadiantConvectiveElectric cannot get capacity.")
			end
		end
		heatingSystemType = 'ELECTRIC_BASEBOARD'
		heatingSystemFuel = 'ELECTRICITY'
		heating_coil_eff = bRCE.efficiency

		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end

		heating_sys = {
			'heatingSystemType' => heatingSystemType,
			'heatingSystemFuel' => heatingSystemFuel,
			'heatingCapacity' => capacity_w.round(0),
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => 'PERCENT'
				}
			}

		#runner.registerInfo("Created ZoneHVACBaseboardRadiantConvectiveElectric Sys: #{heating_sys}.")
		heatingSystems << heating_sys

	end

	model.getZoneHVACBaseboardRadiantConvectiveWaters.each do |bRCW|
		#runner.registerInfo("ZoneHVACBaseboardRadiantConvectiveWater = #{bRCW}.")
		#runner.registerInfo("ZoneHVACBaseboardRadiantConvectiveWater methods = #{bRCW.methods.sort}.")

		# get the plant loop used by this
		if bRCW.plantLoop.is_initialized
			plantLoop = bRCW.plantLoop.get
		else
			runner.registerError("For ZoneHVACBaseboardConvectiveWater plantLoop is not available.")
		end

		capacity_w, heatingSystemFuel, heating_coil_eff, heating_coil_eff_unit = getBoilerInfo(plantLoop, runner)
		heatingSystemType = 'BOILER'

		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end

		heating_sys = {
			'heatingSystemType' => heatingSystemType,
			'heatingSystemFuel' => heatingSystemFuel,
			'heatingCapacity' => capacity_w,
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => heating_coil_eff_unit
				}
			}

		#runner.registerInfo("Created ZoneHVACBaseboardRadiantConvectiveWater Sys: #{heating_sys}.")
		heatingSystems << heating_sys

	end

	model.getZoneHVACUnitHeaters.each do |uH|
		#runner.registerInfo("ZoneHVACUnitHeater = #{uH}.")
		#runner.registerInfo("ZoneHVACUnitHeater methods = #{uH.methods.sort}.")

		heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(uH.heatingCoil, runner)

		if not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'ELECTRICITY')
			#runner.registerInfo("ZoneHVAC Furnace Electric found")
			heatingSystemType = 'FURNACE'
			heatingSystemFuel = 'ELECTRICITY'
		elsif not heating_coil_type.nil? and (heating_coil_type.include? 'Furnace' and heating_coil_fuel == 'NATURAL_GAS')
			#runner.registerInfo("ZoneHVAC Furnace Gas found")
			heatingSystemType = 'FURNACE'
			heatingSystemFuel = 'NATURAL_GAS'
		else
			runner.registerError("ZoneHVAC Unit Heater unrecognized.")
		end

		if userHeatingSystemType != heatingSystemType
			runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
		end
		if userHeatingSystemFuel != heatingSystemFuel
			runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
		end

		heating_sys = {
			'heatingSystemType' => heatingSystemType,
			'heatingSystemFuel' => heatingSystemFuel,
			'heatingCapacity' => heating_coil_capacity,
			'annualHeatingEfficiency' => {
				'value' => heating_coil_eff,
				'unit' => heating_coil_eff_unit
				}
			}

		#runner.registerInfo("Created ZoneHVACUnitHeater Sys: #{heating_sys}.")
		heatingSystems << heating_sys
	end

	if heatPumps != [] || coolingSystems != [] || heatingSystems != []
		zone_unit_sys = {
			'heatPumps' => heatPumps,
			'coolingSystems' => coolingSystems,
			'heatingSystems' => heatingSystems
			}
			#runner.registerInfo("Created PTAC HVAC Array: #{zone_unit_sys}.")
	else
		zone_unit_sys = []
	end

	return zone_unit_sys
end

def get_coolingDXSingleSpeed_info_idf(coil, runner)

	# Get the capacity
	capacity_w = coil.getDouble(0) # Gross Rated Total Cooling Capacity

	# Get the COP
	cop = coil.getDouble(2) # Gross Rated Cooling COP

	#runner.registerInfo("Coil COP = #{cop} for DX Single Speed cooling coil has been found.")

	cooling_coil_type = 'DXSingleSpeed'
	cooling_coil_capacity = capacity_w.round(0)
	cooling_coil_eff = cop
	cooling_coil_eff_unit = 'COP'

	#runner.registerInfo("DX Single Speed Cooling Coil has been found with COP = #{cop}.")

	return cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit

end

def get_cooling_coil_info(coil, runner)

	#runner.registerInfo("coil = #{coil}.")
	#runner.registerInfo("coil methods = #{coil.methods.sort}.")

	cooling_coil_type = nil
	cooling_coil_capacity = nil
	cooling_coil_eff = nil
	cooling_coil_eff_unit = nil
	cooling_coil_fuel = nil

	if coil.to_CoilCoolingDXSingleSpeed.is_initialized
		ccdxss = coil.to_CoilCoolingDXSingleSpeed.get
		#runner.registerInfo("CoilCoolingDXSingleSpeed found = #{ccdxss}.")

		# Get the capacity
		capacity_w = nil
		if ccdxss.ratedTotalCoolingCapacity.is_initialized
			capacity_w = ccdxss.ratedTotalCoolingCapacity.get
		elsif ccdxss.autosizedRatedTotalCoolingCapacity.is_initialized
			capacity_w = ccdxss.autosizedRatedTotalCoolingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil.name} capacity is not available.")
		end

		# Get the COP
		cop = nil
		if ccdxss.ratedCOP.is_initialized
			cop = ccdxss.ratedCOP.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil.name} COP is not available.")
		end

		#runner.registerInfo("Coil COP = #{cop} for DX Single Speed cooling coil has been found.")

		cooling_coil_type = 'DXSingleSpeed'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = cop
		cooling_coil_eff_unit = 'COP'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("DX Single Speed Cooling Coil has been found with COP = #{cop}.")
	end
	if coil.to_CoilCoolingDXTwoSpeed.is_initialized
		ccdxts = coil.to_CoilCoolingDXTwoSpeed.get
		#runner.registerInfo("CoilCoolingDXTwoSpeed found = #{ccdxts}.")
		# Get the capacity
		capacity_w = nil
		if ccdxts.ratedHighSpeedTotalCoolingCapacity.is_initialized
			capacity_w = ccdxts.ratedHighSpeedTotalCoolingCapacity.get
		elsif ccdxts.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
			capacity_w = ccdxts.autosizedRatedHighSpeedTotalCoolingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil.name} capacity is not available.")
		end

		# Get the COP
		cop = nil
		if ccdxts.ratedHighSpeedCOP.is_initialized
			cop = ccdxts.ratedHighSpeedCOP.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil.name} COP is not available.")
		end

		#runner.registerInfo("Coil COP = #{cop} for DX Two Speed cooling coil have been found.")

		cooling_coil_type = 'DXTwoSpeed'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = cop
		cooling_coil_eff_unit = 'COP'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("DX Two Speed Cooling Coil has been found with high speed COP = #{cop}.")
	end
	if coil.to_ChillerElectricEIR.is_initialized
		ceeir = coil.to_ChillerElectricEIR.get
		#runner.registerInfo("CoilCoolingDXSingleSpeed found = #{ceeir}.")

		# Get the capacity
		capacity_w = nil
		if ceeir.referenceCapacity.is_initialized
			capacity_w = ceeir.referenceCapacity.get
		elsif ceeir.autosizedReferenceCapacity.is_initialized
			capacity_w = ceeir.autosizedReferenceCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ChillerElectricEIR", "For #{ceeir.name} capacity is not available.")
		end

		# Get the COP
		cop = ceeir.referenceCOP

		#runner.registerInfo("Coil COP = #{cop} for Chiller have been found.")

		cooling_coil_type = 'Chiller'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = cop
		cooling_coil_eff_unit = 'COP'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("Chiller Coil has been found with high speed COP = #{cop}. BIRDS NEST cannot currently handle chiller systems")
	end
	if coil.to_CoilCoolingDXMultiSpeed.is_initialized
		ccdxms = coil.to_CoilCoolingDXMultiSpeed.get
		#runner.registerInfo("CoilCoolingDXMultiSpeed found = #{ccdxms}.")

	end
	if coil.to_CoilCoolingDXMultiSpeedStageData.is_initialized
		ccdxmssd = coil.to_CoilCoolingDXMultiSpeedStageData.get
		#runner.registerInfo("CoilCoolingDXMultiSpeedStageData found = #{ccdxmssd}.")

	end
	if coil.to_CoilCoolingDXTwoStageWithHumidityControlMode.is_initialized
		ccdxtswhcm = coil.to_CoilCoolingDXTwoStageWithHumidityControlMode.get
		#runner.registerInfo("CoilCoolingDXTwoStageWithHumidityControlMode found = #{ccdxtswhcm}.")

	end
	if coil.to_CoilCoolingDXVariableRefrigerantFlow.is_initialized
		ccdxvrf = coil.to_CoilCoolingDXVariableRefrigerantFlow.get
		#runner.registerInfo("CoilCoolingDXVariableRefrigerantFlow found = #{ccdxvrf}.")

		# Get the capacity
		capacity_w = nil
		if ccdxvrf.ratedTotalCoolingCapacity.is_initialized
			capacity_w = ccdxvrf.ratedTotalCoolingCapacity.get
		elsif ccdxvrf.autosizedRatedTotalCoolingCapacity.is_initialized
			capacity_w = ccdxvrf.autosizedRatedTotalCoolingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilCoolingDXVariableRefrigerantFlow", "For #{ccdxvrf.name} capacity is not available.")
		end

		cooling_coil_type = 'CoilCoolingDXVariableRefrigerantFlow'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = 0
		cooling_coil_eff_unit = 'NULL'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("CoilCoolingDXVariableRefrigerantFlow Coil has been found")
	end
	if coil.to_CoilCoolingDXVariableSpeed.is_initialized
		ccdxvs = coil.to_CoilCoolingDXVariableSpeed.get
		#runner.registerInfo("CoilCoolingDXVariableSpeed found = #{ccdxvs}.")

	end
	if coil.to_CoilCoolingDXVariableSpeedSpeedData.is_initialized
		ccdxvssd = coil.to_CoilCoolingDXVariableSpeedSpeedData.get
		#runner.registerInfo("CoilCoolingDXVariableSpeedSpeedData found = #{ccdxvssd}.")

	end
	if coil.to_CoilCoolingWater.is_initialized
		ccw = coil.to_CoilCoolingWater.get
		#runner.registerInfo("CoilCoolingWater found = #{ccw}.")
		#runner.registerInfo("CoilCoolingWater methods = #{ccw.methods.sort}.")

		# Get the capacity
		capacity_w = 999
		#if ccw.ratedTotalCoolingCapacity.is_initialized
		#	capacity_w = ccw.ratedTotalCoolingCapacity.get
		#else
		#	OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilCoolingWater", "For #{ccw.name} capacity is not available.")
		#end

		cooling_coil_type = 'CoilCoolingWater'
		cooling_coil_capacity = capacity_w #.round(0)
		cooling_coil_eff = 9
		cooling_coil_eff_unit = 'COP'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("CoilCoolingWater Coil has been found")

	end
	if coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
		ccwtahpef = coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
		#runner.registerInfo("CoilCoolingWaterToAirHeatPumpEquationFit found = #{ccwtahpef}.")

		# Get the capacity
		capacity_w = nil
		if ccwtahpef.ratedTotalCoolingCapacity.is_initialized
			capacity_w = ccwtahpef.ratedTotalCoolingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilCoolingWaterToAirHeatPumpEquationFit", "For #{ccwtahpef.name} capacity is not available.")
		end

		cooling_coil_type = 'CoilCoolingWaterToAirHeatPumpEquationFit'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = 0
		cooling_coil_eff_unit = 'NULL'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("CoilCoolingWaterToAirHeatPumpEquationFit Coil has been found")
	end
	if coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized
		ccwtahpvsef = coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.get
		#runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit found = #{ccwtahpvsef}.")

		# Get the capacity
		capacity_w = nil
		if ccwtahpvsef.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
			capacity_w = ccwtahpvsef.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
		elsif ccwtahpvsef.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
			capacity_w = ccwtahpvsef.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
		else
			OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit", "For #{ccwtahpvsef.name} capacity is not available.")
		end

		cooling_coil_type = 'CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = 0
		cooling_coil_eff_unit = 'NULL'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit Coil has been found")
	end
	if coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
		ccwtahpvsefsd = coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.get
		#runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData found = #{ccwtahpvsefsd}.")

		# Get the capacity
		capacity_w = nil
		if ccwtahpvsefsd.referenceUnitGrossRatedTotalCoolingCapacity.is_initialized
			capacity_w = ccwtahpvsefsd.referenceUnitGrossRatedTotalCoolingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData", "For #{ccwtahpvsefsd.name} capacity is not available.")
		end

		cooling_coil_type = 'CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = 0
		cooling_coil_eff_unit = 'NULL'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData Coil has been found")
	end
	if coil.to_CoilPerformanceDXCooling.is_initialized
		cpdxc = coil.to_CoilPerformanceDXCooling.get
		#runner.registerInfo("CoilPerformanceDXCooling found = #{cpdxc}.")

		# Get the capacity
		capacity_w = nil
		if cpdxc.grossRatedTotalCoolingCapacity.is_initialized
			capacity_w = cpdxc.grossRatedTotalCoolingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilPerformanceDXCooling", "For #{cpdxc.name} capacity is not available.")
		end

		cooling_coil_type = 'CoilPerformanceDXCooling'
		cooling_coil_capacity = capacity_w.round(0)
		cooling_coil_eff = 0
		cooling_coil_eff_unit = 'NULL'
		cooling_coil_fuel = 'ELECTRICITY'

		#runner.registerInfo("CoilPerformanceDXCooling Coil has been found")
	end
	if coil.to_CoilSystemCoolingDXHeatExchangerAssisted.is_initialized
		cscdxhea = coil.to_CoilSystemCoolingDXHeatExchangerAssisted.get
		#runner.registerInfo("CoilSystemCoolingDXHeatExchangerAssisted found = #{cscdxhea}.")

		cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(cscdxhea.coolingCoil, runner)
	end

	return cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel

end

def is_cooling_coil(coil)

	if coil.to_CoilCoolingDXSingleSpeed.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXTwoSpeed.is_initialized
		return true
	end
	if coil.to_ChillerElectricEIR.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXMultiSpeed.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXMultiSpeedStageData.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXTwoStageWithHumidityControlMode.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXVariableRefrigerantFlow.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXVariableSpeed.is_initialized
		return true
	end
	if coil.to_CoilCoolingDXVariableSpeedSpeedData.is_initialized
		return true
	end
	if coil.to_CoilCoolingWater.is_initialized
		return true
	end
	if coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
		return true
	end
	if coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized
		return true
	end
	if coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
		return true
	end
	if coil.to_CoilPerformanceDXCooling.is_initialized
		return true
	end
	if coil.to_CoilSystemCoolingDXHeatExchangerAssisted.is_initialized
		return true
	end

	return false

end

def get_heating_coil_info(coil, runner)

	#runner.registerInfo("coil = #{coil}.")
	#runner.registerInfo("coil methods = #{coil.methods.sort}.")

	heating_coil_type = nil
	heating_coil_capacity = nil
	heating_coil_eff = nil
	heating_coil_eff_unit = nil
	heating_coil_fuel = nil

	if coil.to_BoilerHotWater.is_initialized
		bhw = coil.to_BoilerHotWater.get
		#runner.registerInfo("BoilerHotWater found = #{bhw}.")
		# Get the capacity
		capacity_w = nil
		if bhw.nominalCapacity.is_initialized
			capacity_w = bhw.nominalCapacity.get
		elsif bhw.autosizedNominalCapacity.is_initialized
			capacity_w = bhw.autosizedNominalCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{bhw.name} capacity is not available.")
		end

		# Get the efficiency
		eff = bhw.nominalThermalEfficiency

		#runner.registerInfo("Coil efficiency = #{eff} for Boiler has been found.")

		heating_coil_type = 'Boiler'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = eff
		heating_coil_eff_unit = 'PERCENT'
		boiler_fuel_type = 	bhw.fuelType
		if boiler_fuel_type == 'electric'
			heating_coil_fuel = 'ELECTRICITY'
		else
			heating_coil_fuel =  'NULL'
		end
		#runner.registerInfo("Boiler Coil has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingDXSingleSpeed.is_initialized
		chdxss = coil.to_CoilHeatingDXSingleSpeed.get
		#runner.registerInfo("CoilHeatingDXSingleSpeed found = #{chdxss}.")
		# Get the capacity
		capacity_w = nil
		if chdxss.ratedTotalHeatingCapacity.is_initialized
			capacity_w = chdxss.ratedTotalHeatingCapacity.get
		elsif chdxss.autosizedRatedTotalHeatingCapacity.is_initialized
			capacity_w = chdxss.autosizedRatedTotalHeatingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil.name} capacity is not available.")
		end

		# Get the COP
		cop = chdxss.ratedCOP

		#runner.registerInfo("COP = #{cop} for DX Heating Coil have been found.")

		heating_coil_type = 'DX Single Speed'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = cop
		heating_coil_eff_unit = 'COP'

		#runner.registerInfo("Heating DX Single Speed Coil has been found with COP = #{heating_coil_eff} and capacity = #{heating_coil_capacity}.")
	end
	if coil.to_CoilHeatingGas.is_initialized
		chg = coil.to_CoilHeatingGas.get
		#runner.registerInfo("CoilHeatingGas found = #{chg}.")
		# Get the capacity
		capacity_w = nil

		if chg.nominalCapacity.is_initialized
			capacity_w = chg.nominalCapacity.get
		elsif chg.autosizedNominalCapacity.is_initialized
			#runner.registerInfo("CoilHeatingGas has autosized capacity.")
			capacity_w = chg.autosizedNominalCapacity.get
		else
			runner.registerError("For #{coil.name} capacity is not available.")
		end
		#runner.registerInfo("CoilHeatingGas capacity found = #{capacity_w}.")

		# Get the efficiency
		eff = chg.gasBurnerEfficiency

		#runner.registerInfo("Coil efficiency = #{eff} for gas furnace have been found.")

		heating_coil_type = 'Furnace'
		heating_coil_fuel = 'NATURAL_GAS'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = eff
		heating_coil_eff_unit = 'PERCENT'

		#runner.registerInfo("Gas Furnace Coil has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingElectric.is_initialized
		# Skip reheat coils in VAV terminals; ignore this concern for now because we are only focused on residential
		#next unless coil.airLoopHVAC.is_initialized || coil.containingZoneHVACComponent.is_initialized ***Commented out by Josh because it was skipping the back-up coil***
		che = coil.to_CoilHeatingElectric.get
		#runner.registerInfo("CoilHeatingElectric found = #{che}.")
		# Get the capacity
		capacity_w = nil
		if che.nominalCapacity.is_initialized
		  capacity_w = che.nominalCapacity.get
		elsif che.autosizedNominalCapacity.is_initialized
		  capacity_w = che.autosizedNominalCapacity.get
		else
		  OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{che.name} capacity is not available.")
		end
		#runner.registerInfo("CoilHeatingElectric capacity = #{capacity_w}.")

		# Get the efficiency
		eff = che.efficiency

		#runner.registerInfo("Coil efficiency = #{eff} for electric furnace (back-up?) have been found.")

		heating_coil_type = 'Furnace'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = eff
		#runner.registerInfo("Electric furnace coil is the primary coil.")

		#runner.registerInfo("Electric Furnace Coil has been found with Efficiency = #{eff}.")
	end
	if coil.to_ZoneHVACBaseboardConvectiveElectric.is_initialized
		zhbce = coil.to_ZoneHVACBaseboardConvectiveElectric.get
		#runner.registerInfo("ZoneHVACBaseboardConvectiveElectric found = #{zhbce}.")
		# Get the capacity
		capacity_w = nil
		if zhbce.nominalCapacity.is_initialized
			capacity_w = zhbce.nominalCapacity.get
		elsif zhbce.autosizedNominalCapacity.is_initialized
			capacity_w = zhbce.autosizedNominalCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{zhbce.name} capacity is not available.")
		end

		# Get the efficiency
		eff = bb.efficiency

		#runner.registerInfo("Coil efficiency = #{eff} for electric resistance baseboard have been found.")
		heating_coil_type = 'Baseboard'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = eff
		heating_coil_eff_unit = 'PERCENT'

		#runner.registerInfo("Electric Baseboards Coil has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingDXMultiSpeed.is_initialized
		chdxms = coil.to_CoilHeatingDXMultiSpeed.get
		#runner.registerInfo("CoilHeatingDXMultiSpeed found = #{chdxms}.")

	end
	if coil.to_CoilHeatingDXMultiSpeedStageData.is_initialized
		chdxmssd = coil.to_CoilHeatingDXMultiSpeedStageData.get
		#runner.registerInfo("CoilHeatingDXMultiSpeedStageData found = #{chdxmssd}.")

	end

	if coil.to_CoilHeatingDXVariableRefrigerantFlow.is_initialized
		chdxvrf = coil.to_CoilHeatingDXVariableRefrigerantFlow.get
		#runner.registerInfo("CoilHeatingDXVariableRefrigerantFlow found = #{chdxvrf}.")

	end
	if coil.to_CoilHeatingDXVariableSpeed.is_initialized
		chdxvs = coil.to_CoilHeatingDXVariableSpeed.get
		#runner.registerInfo("CoilHeatingDXVariableSpeed found = #{chdxvs}.")

	end
	if coil.to_CoilHeatingDXVariableSpeedSpeedData.is_initialized
		chdxvssd = coil.to_CoilHeatingDXVariableSpeedSpeedData.get
		#runner.registerInfo("CoilHeatingDXVariableSpeedSpeedData found = #{chdxvssd}.")

	end
	if coil.to_CoilHeatingGasMultiStage.is_initialized
		chgms = coil.to_CoilHeatingGasMultiStage.get
		#runner.registerInfo("CoilHeatingGasMultiStage found = #{chgms}.")

	end
	if coil.to_CoilHeatingGasMultiStageStageData.is_initialized
		chgmssd = coil.to_CoilHeatingGasMultiStageStageData.get
		#runner.registerInfo("CoilHeatingGasMultiStageStageData found = #{chgmssd}.")

	end
	if coil.to_CoilHeatingWater.is_initialized
		chw = coil.to_CoilHeatingWater.get
		#runner.registerInfo("CoilHeatingWater found = #{chw}.")

		# Get the capacity
		capacity_w = nil
		if chw.ratedCapacity.is_initialized
			capacity_w = chw.ratedCapacity.get
		elsif not chw.autosizeRatedCapacity.nil? and chw.autosizeRatedCapacity.is_initialized
			capacity_w = chw.autosizeRatedCapacity.get
		else
			runner.registerError("For heating water coil named: #{coil.name} capacity is not available.")
		end

		# get the plant loop used by this coil
		if chw.plantLoop.is_initialized
			plantLoop = chw.plantLoop.get
			#runner.registerInfo("For CoilHeatingWater #{coil.name} plantLoop was found.")
		else
			runner.registerError("For CoilHeatingWater #{coil.name} plantLoop is not available.")
		end

		plantLoop.supplyComponents.each do |sc|
			if sc.to_BoilerHotWater.is_initialized
				capacity_w, heating_coil_fuel, heating_coil_eff, heating_coil_eff_unit = getBoilerInfo(plantLoop, runner)
				heating_coil_type = 'CoilHeatingWater'
				#runner.registerInfo("Boiler specs found: #{heating_coil_type}, #{capacity_w},#{heating_coil_fuel},#{heating_coil_eff},#{heating_coil_eff_unit}.")
			elsif sc.to_GroundHeatExchangerVertical.is_initialized
				ghev = sc.to_GroundHeatExchangerVertical.get
				#runner.registerInfo("Ground HX found.")
				ghev_name = nil
					if ghev.name.is_initialized
						ghev_name = ghev.name.get
						#runner.registerInfo("G HX #{ghev_name} found.")
					else
						runner.registerError("No heat exchanger name found.")
					end
				capacity_w = 9999
				heating_coil_fuel = 'ELECTRICITY'
				heating_coil_eff = 9
				heating_coil_eff_unit = 'COP'
				#runner.registerInfo("Ground HX specs found: #{capacity_w},#{heating_coil_fuel},#{heating_coil_eff},#{heating_coil_eff_unit}.")
				heating_coil_type = 'CoilHeatingWater'
				#runner.registerInfo("CoilHeatingWater capacity = #{capacity_w}.")
			elsif sc.to_GroundHeatExchangerHorizontalTrench.is_initialized
				ghev = sc.to_GroundHeatExchangerHorizontalTrench.get
				#runner.registerInfo("Ground HX found.")
				ghev_name = nil
					if ghev.name.is_initialized
						ghev_name = ghev.name.get
						#runner.registerInfo("G HX #{ghev_name} found.")
					else
						runner.registerError("No heat exchanger name found.")
					end
				capacity_w = 9999
				heating_coil_fuel = 'ELECTRICITY'
				heating_coil_eff = 9
				heating_coil_eff_unit = 'COP'
				#runner.registerInfo("Ground HX specs found: #{capacity_w},#{heating_coil_fuel},#{heating_coil_eff},#{heating_coil_eff_unit}.")
				heating_coil_type = 'CoilHeatingWater'
				#runner.registerInfo("CoilHeatingWater capacity = #{capacity_w}.")
			#else
			#	runner.registerError("For CoilHeatingWater #{coil.name} performance specs are not available.")
			end
		end
		heating_coil_capacity = capacity_w.round(0)
		#runner.registerInfo("CoilHeatingWater Specs: #{heating_coil_type}, #{heating_coil_capacity},#{heating_coil_fuel},#{heating_coil_eff},#{heating_coil_eff_unit}.")
	end
	if coil.to_CoilHeatingWaterBaseboard.is_initialized
		chwb = coil.to_CoilHeatingWaterBaseboard.get
		#runner.registerInfo("CoilHeatingWaterBaseboard found = #{chwb}.")

		# Get the capacity
		capacity_w = nil
		if chwb.heatingDesignCapacity.is_initialized
			capacity_w = chwb.heatingDesignCapacity.get
		elsif chwb.autosizedHeatingDesignCapacity.is_initialized
			capacity_w = chwb.autosizedHeatingDesignCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterBaseboard', "For #{chwb.name} capacity is not available.")
		end

		heating_coil_type = 'CoilHeatingWaterBaseboard'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = 0
		heating_coil_eff_unit = 'NULL'

		#runner.registerInfo("CoilHeatingWaterBaseboard has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingWaterBaseboardRadiant.is_initialized
		chwbr = coil.to_CoilHeatingWaterBaseboardRadiant.get
		#runner.registerInfo("CoilHeatingWaterBaseboardRadiant found = #{chwbr}.")

		# Get the capacity
		capacity_w = nil
		if chwbr.heatingDesignCapacity.is_initialized
			capacity_w = chwbr.heatingDesignCapacity.get
		elsif chwbr.autosizedHeatingDesignCapacity.is_initialized
			capacity_w = chwbr.autosizedHeatingDesignCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterBaseboardRadiant', "For #{chwbr.name} capacity is not available.")
		end

		heating_coil_type = 'CoilHeatingWaterBaseboardRadiant'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = 0
		heating_coil_eff_unit = 'NULL'

		#runner.registerInfo("CoilHeatingWaterBaseboardRadiant has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
		chwtahpef = coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.get
		#runner.registerInfo("CoilHeatingWaterToAirHeatPumpEquationFit found = #{chwtahpef}.")

		# Get the capacity
		capacity_w = nil
		if chwtahpef.ratedHeatingCapacity.is_initialized
			capacity_w = chwtahpef.ratedHeatingCapacity.get
		elsif chwtahpef.autosizedRatedHeatingCapacity.is_initialized
			capacity_w = chwtahpef.autosizedRatedHeatingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{chwtahpef.name} capacity is not available.")
		end

		heating_coil_type = 'CoilHeatingWaterToAirHeatPumpEquationFit'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = 0
		heating_coil_eff_unit = 'NULL'

		#runner.registerInfo("CoilHeatingWaterToAirHeatPumpEquationFit has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized
		chwtahpvsef = coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.get
		#runner.registerInfo("CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit found = #{chwtahpvsef}.")

		# Get the capacity
		capacity_w = nil
		if chwtahpvsef.ratedHeatingCapacityAtSelectedNominalSpeedLevel.is_initialized
			capacity_w = chwtahpvsef.ratedHeatingCapacityAtSelectedNominalSpeedLevel.get
		elsif chwtahpvsef.autosizedRatedHeatingCapacityAtSelectedNominalSpeedLevel.is_initialized
			capacity_w = chwtahpvsef.autosizedRatedHeatingCapacityAtSelectedNominalSpeedLevel.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit', "For #{chwtahpvsef.name} capacity is not available.")
		end

		heating_coil_type = 'CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = 0
		heating_coil_eff_unit = 'NULL'

		#runner.registerInfo("CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit has been found with Efficiency = #{eff}.")
	end
	if coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
		chwtahpvsefsd = coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.get
		#runner.registerInfo("CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData found = #{chwtahpvsefsd}.")

		# Get the capacity
		capacity_w = nil
		if chwtahpvsefsd.referenceUnitGrossRatedHeatingCapacity.is_initialized
			capacity_w = chwtahpvsefsd.referenceUnitGrossRatedHeatingCapacity.get
		else
			OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData', "For #{chwtahpvsefsd.name} capacity is not available.")
		end

		# Get the COP
		cop = chwtahpvsefsd.referenceUnitGrossRatedHeatingCOP

		#runner.registerInfo("COP = #{cop} for CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData have been found.")

		heating_coil_type = 'CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData'
		heating_coil_fuel = 'ELECTRICITY'
		heating_coil_capacity = capacity_w.round(0)
		heating_coil_eff = cop
		heating_coil_eff_unit = 'COP'

		#runner.registerInfo("CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData has been found with COP = #{heating_coil_eff} and capacity = #{heating_coil_capacity}.")
	end

	return heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel

end

def getBoilerInfo(plantLoop, runner)

	capacity_w = nil
	heating_fuel = nil
	heating_eff = nil
	heating_eff_unit = nil

	#look through the supply components for the boiler
	plantLoop.supplyComponents.each do |sc|

		if sc.to_BoilerHotWater.is_initialized
			boiler = sc.to_BoilerHotWater.get
			#runner.registerInfo("boiler = #{boiler}.")
			#runner.registerInfo("boiler methods = #{boiler.methods.sort}.")

			if boiler.nominalCapacity.is_initialized
				capacity_w = boiler.nominalCapacity.get
				#runner.registerInfo("Boiler nominalCapacity = #{capacity_w}.")
			elsif boiler.autosizedNominalCapacity.is_initialized
				capacity_w = boiler.autosizedNominalCapacity.get
				#runner.registerInfo("Boiler autosizedNominalCapacity = #{capacity_w}.")
			else
				runner.registerError("For Boiler capacity is not available.")
			end

			if boiler.fuelType == 'Electricity'
				heating_fuel = 'ELECTRICITY'
			elsif boiler.fuelType == 'NaturalGas'
				heating_fuel = 'NATURAL_GAS'
			elsif boiler.fuelType == 'Propane'
				heating_fuel = 'PROPANE'
			elsif boiler.fuelType == 'FuelOilNo1' or boiler.fuelType == 'FuelOilNo2'
				heating_fuel = 'FUEL_OIL'
			else
				heating_fuel = 'NULL'
			end

			heating_eff = boiler.nominalThermalEfficiency
			heating_eff_unit = 'PERCENT'
			#runner.registerInfo("Boiler Efficiency = #{heating_eff}.")
		end
	end

	return 	capacity_w, heating_fuel, heating_eff, heating_eff_unit

end

def is_heating_coil(coil)

	if coil.to_BoilerHotWater.is_initialized
		return true
	end
	if coil.to_CoilHeatingDXSingleSpeed.is_initialized
		return true
	end
	if coil.to_CoilHeatingGas.is_initialized
		return true
	end
	if coil.to_CoilHeatingElectric.is_initialized
		return true
	end
	if coil.to_ZoneHVACBaseboardConvectiveElectric.is_initialized
		return true
	end
	if coil.to_CoilHeatingDXMultiSpeed.is_initialized
		return true
	end
	if coil.to_CoilHeatingDXMultiSpeedStageData.is_initialized
		return true
	end

	if coil.to_CoilHeatingDXVariableRefrigerantFlow.is_initialized
		return true
	end
	if coil.to_CoilHeatingDXVariableSpeed.is_initialized
		return true
	end
	if coil.to_CoilHeatingDXVariableSpeedSpeedData.is_initialized
		return true
	end
	if coil.to_CoilHeatingGasMultiStage.is_initialized
		return true
	end
	if coil.to_CoilHeatingGasMultiStageStageData.is_initialized
		return true
	end
	if coil.to_CoilHeatingWater.is_initialized
		return true
	end
	if coil.to_CoilHeatingWaterBaseboard.is_initialized
		return true
	end
	if coil.to_CoilHeatingWaterBaseboardRadiant.is_initialized
		return true
	end
	if coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
		return true
	end
	if coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized
		return true
	end
	if coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
		return true
	end

	return false

end

#######################################################################
# HVAC Ventilation
# systems found in the model, and determine whether ERV or HRV
# based on latent effectiveness.
# ####################################################################

# @return [Array] returns an array of JSON objects, where
# each object represents an ERV/HRV.
def get_hvac_ventilation(model,runner)
  #runner.registerInfo("Starting search for Mechanical Ventilation equipment.")
  mech_vent_sys = []

  # ERV/HRV
  model.getHeatExchangerAirToAirSensibleAndLatents.each do |erv|
	#runner.registerInfo("Found zone heat exchangers.")
    # Determine if HRV or ERV based on latent effectiveness
    # HRV stands for Heat Recovery Ventilator, which
    # does not do latent heat exchange
    vent_type = 'HEAT_RECOVERY_VENTILATOR'
	#runner.registerInfo("Defaulted Mechanical Ventilation equipment to HRV.")
    if erv.latentEffectivenessat100CoolingAirFlow > 0 || erv.latentEffectivenessat100HeatingAirFlow > 0
      vent_type = 'ENERGY_RECOVERY_VENTILATOR'
    end
	#runner.registerInfo("Mechanical Ventilation equipment type found: #{vent_type}.")

	sensible_eff_cool = 0
	if erv.respond_to?('getSensibleEffectivenessat100CoolingAirFlow')
		sensible_eff_cool = erv.getSensibleEffectivenessat100CoolingAirFlow
	elsif erv.respond_to?('sensibleEffectivenessat100CoolingAirFlow')
		sensible_eff_cool = erv.sensibleEffectivenessat100CoolingAirFlow
	end
	#runner.registerInfo("Sensible efficiency cooling at 100% air flow is #{sensible_eff_cool}.")

	sensible_eff_heat = 0
	if erv.respond_to?('getSensibleEffectivenessat100HeatingAirFlow')
		sensible_eff_heat = erv.getSensibleEffectivenessat100HeatingAirFlow
	elsif erv.respond_to?('sensibleEffectivenessat100HeatingAirFlow')
		sensible_eff_heat = erv.sensibleEffectivenessat100HeatingAirFlow
	end
	#runner.registerInfo("Sensible efficiency heating at 100% air flow is #{sensible_eff_heat}.")
	sensible_eff = (sensible_eff_cool + sensible_eff_heat) / 2
	latent_eff_cool = 0
	if erv.respond_to?('getLatentEffectivenessat100CoolingAirFlow')
		latent_eff_cool = erv.getLatentEffectivenessat100CoolingAirFlow
	elsif erv.respond_to?('latentEffectivenessat100CoolingAirFlow')
		latent_eff_cool = erv.latentEffectivenessat100CoolingAirFlow
	end
	#runner.registerInfo("Latent efficiency cooling at 100% air flow is #{latent_eff_cool}.")

	latent_eff_heat = 0
	if erv.respond_to?('getLatentEffectivenessat100HeatingAirFlow')
		latent_eff_heat = erv.getLatentEffectivenessat100HeatingAirFlow
	elsif erv.respond_to?('latentEffectivenessat100HeatingAirFlow')
		latent_eff_heat = erv.latentEffectivenessat100HeatingAirFlow
	end
	#runner.registerInfo("Latent efficiency heating at 100% air flow is #{latent_eff_heat}.")

	latent_eff = (latent_eff_cool + latent_eff_heat) / 2
	total_eff_cool = sensible_eff_cool + latent_eff_cool
	total_eff_heat = sensible_eff_heat + latent_eff_heat
	total_eff = (total_eff_cool + total_eff_heat) / 2
	#runner.registerInfo("Total efficiency at 100% air flow is #{total_eff} while sensible efficiency is #{sensible_eff}.")

    sys = {
      'fanType' => vent_type,
	  'thirdPartyCertification' => 'OTHER',				# Defaulted to None because there is no way to know.
	  'usedForWholeBuildingVentilation' => false,		# Since these are zone level equipment, no way to know if its for the whole house.
	  'sensibleRecoveryEfficiency' => sensible_eff,		# a simple average of heating and cooling
	  'totalRecoveryEfficiency' => total_eff			# a simple average of heating and cooling
    }
    mech_vent_sys << sys
  	#runner.registerInfo("System was added to the Mechanical Ventilation Object.")
  end
  return mech_vent_sys
end


#######################################################################
#DHW - Water Heaters
# Current issues - cannot match to HPWH with wrapped condenser for some reason.
#####################################################################

def get_water_heaters(model,runner)

  all_whs = []
  mixed_tanks = []
  stratified_tanks = []

  runner.registerInfo("Getting all water heaters.")
  # Heat pump - single speed
  # variable speed code is provided but not tested because cannot currently add variable speed HPWH in OS.
  model.getWaterHeaterHeatPumps.each do |wh|
    runner.registerInfo("Found WaterHeaterHeatPump (single or variable speed).")
    # Get the cop
    cop = nil
    hp_coil = wh.dXCoil
    if hp_coil.to_CoilWaterHeatingAirToWaterHeatPump.is_initialized
      hp_coil = hp_coil.to_CoilWaterHeatingAirToWaterHeatPump.get
      cop = hp_coil.ratedCOP
    end
	# NOT TESTED - variable speed coil COP
	# Could be a few different calls: 
	# CoilWaterHeatingAirToWaterHeatPumpVariableSpeedSpeedDataVector
	# CoilWaterHeatingAirToWaterHeatPumpVariableSpeedSpeedData 
	# Do we need to loop through and find highest COP value across multiple speeds?
	if hp_coil.to_CoilWaterHeatingAirToWaterHeatPumpVariableSpeed.is_initialized
      hp_coil = hp_coil.to_CoilWaterHeatingAirToWaterHeatPumpVariableSpeed.get
		hp_coil_speed_data = hp_coil.to_CoilWaterHeatingAirToWaterHeatPumpVariableSpeedSpeedData.get
		speed_1_cop = hp_coil_speed_data.ratedWaterHeatingCOP
      cop = hp_coil.ratedWaterHeatingCOP 
	end

    # Get the volume
    vol_gal = nil
    tank = wh.tank
    # Currently OS requires mixed tank
	if tank.to_WaterHeaterMixed.is_initialized
      tank = tank.to_WaterHeaterMixed.get
      mixed_tanks << tank
      if tank.tankVolume.is_initialized
        vol_m3 = tank.tankVolume.get
        vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
		capacity_w = tank.heaterMaximumCapacity.get
      end
    end
    # Eventually OS will include heat pump water heaters with stratified tanks.
	if tank.to_WaterHeaterStratified.is_initialized
       tank = tank.to_WaterHeaterStratified.get
       stratified_tanks << tank
       if tank.tankVolume.is_initialized
       vol_m3 = tank.tankVolume.get
       vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
	   capacity_w_1 = tank.heater1Capacity.to_f
	   runner.registerInfo("Heat 1 capacity = #{capacity_w_1}.")
	   capacity_w_2 = tank.heater2Capacity.to_f
	   runner.registerInfo("Heat 2 capacity = #{capacity_w_2}.") 
	   capacity_w = capacity_w_1 + capacity_w_2
	   runner.registerInfo("Combined heater capacity = #{capacity_w}.")
       end
    end

    wh = {
      'waterHeaterType' => 'HEAT_PUMP_WATER_HEATER',
      'fuelType' => 'ELECTRICITY',
      'tankVolume' => vol_gal.round(1),
	  'heatingCapacity' => capacity_w.round(1),
	  'energyFactor' => 0,
	  'uniformEnergyFactor' => cop.round(2),
      'thermalEfficiency' => nil,
	  'waterHeaterInsulationJacketRValue' => nil		# defaulted to nil
    }
    runner.registerInfo("Compiled heat pump water heater information for single and variable speed.")

    all_whs << wh
  end

  # Heat pump wrapped condenser
  model.getWaterHeaterHeatPumpWrappedCondensers.each do |whwc|
    runner.registerInfo("Found WaterHeaterHeatPumpWrappedCondenser.")
    # Get the cop
    cop = nil
    hp_coil = whwc.dXCoil
    if hp_coil.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.is_initialized
      hp_coil = hp_coil.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.get
      cop = hp_coil.ratedCOP
	  runner.registerInfo("Rated COP of HPWH = #{cop}.")
    end

    # Get the volume
    vol_gal = nil
    tank = whwc.tank
    # Currently OS requires mixed tank
	if tank.to_WaterHeaterMixed.is_initialized
      tank = tank.to_WaterHeaterMixed.get
      mixed_tanks << tank
      if tank.tankVolume.is_initialized
        vol_m3 = tank.tankVolume.get
        vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
		capacity_w = tank.heaterMaximumCapacity.get
      end
    end
    # Eventually OS will include heat pump water heaters with stratified tanks.
	if tank.to_WaterHeaterStratified.is_initialized
       tank = tank.to_WaterHeaterStratified.get
       stratified_tanks << tank
       if tank.tankVolume.is_initialized
       vol_m3 = tank.tankVolume.get
       vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
	   capacity_w_1 = tank.heater1Capacity.to_f
	   runner.registerInfo("Heat 1 capacity = #{capacity_w_1}.")
	   capacity_w_2 = tank.heater2Capacity.to_f
	   runner.registerInfo("Heat 2 capacity = #{capacity_w_2}.") 
	   capacity_w = capacity_w_1 + capacity_w_2
	   runner.registerInfo("Combined heater capacity = #{capacity_w}.")
       end
     end

    whwc = {
      'waterHeaterType' => 'HEAT_PUMP_WATER_HEATER',
      'fuelType' => 'ELECTRICITY',
      'tankVolume' => vol_gal.round(1),
	  'heatingCapacity' => capacity_w.round(1),
	  'energyFactor' => 0,
	  'uniformEnergyFactor' => cop.round(2),
      'thermalEfficiency' => nil,
	  'waterHeaterInsulationJacketRValue' => nil		# defaulted to nil
    }
    runner.registerInfo("Compiled heat pump water heater information for wrapped condensers.")

    all_whs << whwc
  end

  # Water heaters as storage on the demand side
  model.getPlantLoops.each do |loop|
  loop.demandComponents.each do |dc|
    next unless dc.to_WaterHeaterMixed.is_initialized
    solar_wh_tank_mixed = dc.to_WaterHeaterMixed.get
    #runner.registerInfo("solar thermal tank = #{solar_wh_tank_mixed} was found.")
	mixed_tanks << solar_wh_tank_mixed
	end
  end

  # Storage and Instantaneous
  model.getWaterHeaterMixeds.each do |wh|
	next if mixed_tanks.include?(wh)
	###TO DO
	### Exclude any tanks that are on the demand side of a plant loop because they will be associated with a solar thermal system.
	### Water heaters as storage on the demand side will have zero wattage under our indirect solar thermal system.
    # TODO
    # Determine if storage or instantaneous
    # based on presence/absence of recirculation pump.
    #runner.registerInfo("Found a mixed water heater.")
	# Get the capacity (single heating element).
	capacity_w = wh.heaterMaximumCapacity.get

    # Get the efficiency
    eff = nil
    if wh.heaterThermalEfficiency.is_initialized
      eff = wh.heaterThermalEfficiency.get
    end

	# Get the fuel
	if wh.heaterFuelType == "Electricity"
		fuel = "ELECTRICITY"
	elsif wh.heaterFuelType == "NaturalGas"
		fuel = "NATURAL_GAS"
	elsif wh.heaterFuelType == "FuelOilNo1" or wh.heaterFuelType == "FuelOilNo2"
		fuel = "FUEL_OIL"
	elsif wh.heaterFuelType == "Propane"
		fuel = "PROPANE"
	else
		fuel = "NULL"
	end

    # Get the volume
    vol_gal = nil
    if wh.tankVolume.is_initialized
      vol_m3 = wh.tankVolume.get
      vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
    end

	#Check if the water heater is "tankless" (less than 10 gallons)
	if vol_gal <  10
		type = 'INSTANTANEOUS_WATER_HEATER'
	else
		type = 'STORAGE_WATER_HEATER'
	end
    wh = {
      'waterHeaterType' => type,
      'fuelType' => fuel,
      'tankVolume' => vol_gal.round(1),
	  'heatingCapacity' => capacity_w,
	  'energyFactor' => 0,
	  'uniformEnergyFactor' => 0,
      'thermalEfficiency' => eff,
	  'waterHeaterInsulationJacketRValue' => 0		# defaulted to nil
    }
    runner.registerInfo("Compiled mixed water heater information.")
	all_whs << wh

  end

  # Stratified
  # Water heaters as storage on the demand side
  model.getPlantLoops.each do |loop|
	loop.demandComponents.each do |dc|
		next unless dc.to_WaterHeaterStratified.is_initialized
		solar_wh_tank_stratified = dc.to_WaterHeaterStratified.get
		#runner.registerInfo("solar thermal tank = #{solar_wh_tank_stratified} was found.")
		stratified_tanks << solar_wh_tank_stratified
		end
  end

  model.getWaterHeaterStratifieds.each do |wh|
    # Skip stratified tanks that were already accounted for because they were attached to heat pumps
    next if stratified_tanks.include?(wh)
    #runner.registerInfo("Found a stratified water heater.")
	# Get the fuel
	if wh.heaterFuelType == "Electricity"
		fuel = "ELECTRICITY"
	elsif wh.heaterFuelType == "NaturalGas"
		fuel = "NATURAL_GAS"
	elsif wh.heaterFuelType == "FuelOilNo1" or wh.heaterFuelType == "FuelOilNo2"
		fuel = "FUEL_OIL"
	elsif wh.heaterFuelType == "Propane"
		fuel = "PROPANE"
	else
		fuel = "NULL"
	end
	#runner.registerInfo("Found a stratified water heater fuel type: #{fuel}.")
	# Get the capacity (up to 2 heating elements).
	if wh.heater1Capacity.is_initialized
		#runner.registerInfo("Heater 1 Capacity (#{wh.heater1Capacity}) is initialized.")
		capacity_heater1_w = wh.heater1Capacity.get
	else
		capacity_heater1_w = 0
	end
	#runner.registerInfo("Found a stratified water heater capacity 1 value: #{capacity_heater1_w}.")
	#runner.registerInfo("Heater 2 Capacity (#{wh.heater2Capacity}) is initialized.")
	# Adding a zero value to the total capacity was creating an issue. So now we check if its zero or nil.
	if (wh.heater2Capacity != 0) && (wh.heater2Capacity != nil)
		#runner.registerInfo("Capacity 2 has a value.")
		capacity_heater2_w = wh.heater2Capacity.get
	else
		#runner.registerInfo("Capacity 2 does not have a value.")
		capacity_heater2_w = 0
	end
	#runner.registerInfo("Found a stratified water heater capacity 2 value: #{capacity_heater2_w}.")
	capacity_w = capacity_heater1_w + capacity_heater2_w
	#runner.registerInfo("Found a stratified water heater total capacity value: #{capacity_w}.")
	# Get the volume
    vol_gal = nil
    if wh.tankVolume.is_initialized
      vol_m3 = wh.tankVolume.get
      vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
    end

	#Check if the water heater is "tankless" (less than 10 gallons)
	if vol_gal <  10
		type = 'INSTANTANEOUS_WATER_HEATER'
	else
		type = 'STORAGE_WATER_HEATER'
	end
    # Get the efficiency
    eff = wh.heaterThermalEfficiency

	#Create the water heater array.
    wh = {
      'waterHeaterType' => type,
      'fuelType' => fuel,
      'tankVolume' => vol_gal.round(1),
	  'heatingCapacity' => capacity_w,
	  'energyFactor' => nil,
	  'uniformEnergyFactor' => nil,
      'thermalEfficiency' => eff,
	  'waterHeaterInsulationJacketRValue' => nil		# defaulted to nil
    }
    runner.registerInfo("Compiled stratified water heater information.")
    all_whs << wh
  end

  return all_whs
	#runner.registerInfo("Compiled all water heaters.")
end

#######################################################################
#DHW - Water Distributions
#
#####################################################################
def get_water_distributions(runner, conditioned_floor_area, num_bathrooms)
	# Could add user inputs for pipe insulation fraction and r-value and pipe material (PEX vs copper).
    water_distributions = []
	insulation_r_value = 2	# hard coded to R-2
	fraction_insulated = 0.5 # hard coded to 50%. Assume all hot and no cold water pipes are insulated.
	pipe_length = 366 + 0.1322 * (conditioned_floor_area - 2432) + 86 * (num_bathrooms - 2.85)
	pipe_length_insulated = pipe_length * fraction_insulated

	hotWaterDistribution = {
	    'hwdPipeRValue' => insulation_r_value.round(1),
	    'hwdPipeLengthInsulated' => pipe_length_insulated.round(1),
	    'hwdFractionPipeInsulated' => fraction_insulated,
	    'pipingLength' => pipe_length.round(1),
	    'pipeMaterial' => 'COPPER'
	  }

    water_distributions << hotWaterDistribution
	#runner.registerInfo("Successfully created DHW Distribution Object: #{hotWaterDistribution}.")

	return water_distributions
end

#######################################################################
#HVAC - Dehumidifier
#
#####################################################################
def get_moisture_controls(runner, model)

	moistureControls = []
	#runner.registerInfo("getting dehumidifiers")

	model.getZoneHVACDehumidifierDXs.each do |dehumidifier|
		#runner.registerInfo("Found ZoneHVAC:Dehumidifier:DX named: #{dehumidifier.name}.")
		#runner.registerInfo("Rated Energy Factor: #{dehumidifier.ratedEnergyFactor}.") #L/kWh

	  moistureControl = {
		'dehumidifierType' => 'STANDALONE',
	    'efficiency' => dehumidifier.ratedEnergyFactor,
	  }
	  moistureControls << moistureControl
	end

	return moistureControls
end
