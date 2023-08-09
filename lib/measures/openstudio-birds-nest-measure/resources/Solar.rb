# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#This file includes Solar PV and Solar Thermal Systems.

#################################
#Solar PV########################
#################################

# Get all the PV systems in the model
# @return [Array] returns an array of JSON objects, where
# each object represents a PV system.
def get_solar_pvs(idf, model, runner, user_arguments, sql,
    panel_type, inverter_type, panel_country)  

	pvt_systems = []  
	pv_watts = 0
	pv_performance_efficiency = 0
	totalcollectorarea = 0
	numerator = 0
	avg_pv_eff = 0
	sumMaxPowerOutput = 0
	inverter_perf_eff = nil
	
	# loop through distribution systems
	distSystems = idf.getObjectsByType("ElectricLoadCenter:Distribution".to_IddObjectType)
	distSystems.each do |distSystem|
		# get the name of the generator list
		#runner.registerInfo("Dist System is #{distSystem}.")
		genListName = distSystem.getString(1).get
		#runner.registerInfo("genListName = #{genListName}.")
		# get the generator list object
		genList = idf.getObjectByTypeAndName("ElectricLoadCenter:Generators", genListName)
		#runner.registerInfo("genList = #{genList}.")
		if genList.empty?
			runner.registerInfo("Could not find generator list called #{genListName}.")
			next
		end
		genList = genList.get
		#runner.registerInfo("genList = #{genList}.")

		#loop through list of generators
		for i in 0..50	# Assumes no more than 50 generators
			#if there is no generator name then exit the loop
			break if not genList.getString(1 + i * 5).is_initialized
			#get the name and type of the generator
			genName = genList.getString(1 + i * 5).get
			#runner.registerInfo("genName = #{genName}.")
			genType = genList.getString(2 + i * 5).get
			#runner.registerInfo("genType = #{genType}.")

			#if there is no generator name then exit the loop
			break if genName.length == 0
			
			#get the generator object
			gen = idf.getObjectByTypeAndName(genType, genName)
			#runner.registerInfo("gen = #{gen}.")
			if gen.empty?
				runner.registerInfo("Could not find generator called #{genName}.")
				next
			end
			gen = gen.get
			#runner.registerInfo("gen = #{gen}.")
			
			#depending on generator type determine pv_watts, surface area and numerator
			if genType == "Generator:Photovoltaic"
				#runner.registerInfo('genType = Generator:Photovoltaic.')
				pv_performance_type = gen.getString(2).get 
				# get the performance specifications for each PV panel
				pv_performance_name = gen.getString(3).get ### if does not initialize, then its not finding a value.
				if pv_performance_type == "PhotovoltaicPerformance:Simple"
					surface_name = gen.getString(1).get
					surface = model.getShadingSurfaceByName(surface_name)
					if surface.empty?
						runner.registerInfo("Could not find surface called #{surface_name}.")
						next
					end
					surface = surface.get
					surfacearea = surface.grossArea #### in m2

					pv_performance = idf.getObjectByTypeAndName("PhotovoltaicPerformance:Simple".to_IddObjectType,pv_performance_name).get 	
					pv_performance_efficiency =  pv_performance.getDouble(3).get

					#Use the performance specs and the surface area for the panel to estimate wattage.
					pv_watts += surfacearea * pv_performance_efficiency * 1000 # estimates wattage
					totalcollectorarea += surfacearea
					numerator += surfacearea * pv_performance_efficiency
					
				elsif pv_performance_type == "PhotovoltaicPerformance:Sandia"
					pv_performance = idf.getObjectByTypeAndName("PhotovoltaicPerformance:Sandia".to_IddObjectType,pv_performance_name).get 	
					pv_performance_active_area =  pv_performance.getDouble(1).get
					pv_performance_current_at_max_power =  pv_performance.getDouble(6).get
					pv_performance_voltage_at_max_power =  pv_performance.getDouble(7).get
					
					pv_performance_efficiency = [pv_performance_current_at_max_power * pv_performance_voltage_at_max_power]/(pv_performance_active_area * 1000)
					
					pv_watts += pv_performance_active_area * 1000
				
					totalcollectorarea += pv_performance_active_area
					numerator += pv_performance_active_area * pv_performance_efficiency
				elsif pv_performance_type == "PhotovoltaicPerformance:EquivalentOne-Diode"
					pv_performance = idf.getObjectByTypeAndName("PhotovoltaicPerformance:EquivalentOne-Diode".to_IddObjectType,pv_performance_name).get 	
					pv_performance_active_area =  pv_performance.getDouble(3).get
					pv_performance_current_at_max_power =  pv_performance.getDouble(11).get
					pv_performance_voltage_at_max_power =  pv_performance.getDouble(12).get
					pv_performance_reference_isolation =  pv_performance.getDouble(10).get

					pv_performance_efficiency = [pv_performance_current_at_max_power * pv_performance_voltage_at_max_power]/(pv_performance_active_area * pv_performance_reference_isolation)

					pv_watts += pv_performance_active_area * pv_performance_reference_isolation
				
					totalcollectorarea += pv_performance_active_area
					numerator += pv_performance_active_area * pv_performance_efficiency
				end

			elsif genType == "Generator:PVWatts"
				surface_name = gen.getString(9).get
				surface = model.getShadingSurfaceByName(surface_name)
				if surface.empty?
					runner.registerInfo("Could not find surface called #{surface_name}.")
					next
				end
				surface = surface.get
				surfacearea = surface.grossArea #### in m2

				module_type = gen.getString(3).get
				if module_type == "Standard"
					pv_performance_efficiency = 0.15
				elsif module_type == "Premium"
					pv_performance_efficiency = 0.19
				elsif module_type == "ThinFilm"
					pv_performance_efficiency = 0.10
				end
				
				pv_watts += gen.getDouble(2).get 

				totalcollectorarea += surfacearea
				numerator += surfacearea * pv_performance_efficiency
			end
		end
		
		# determine average efficiency of system
		if totalcollectorarea > 0 
			avg_pv_eff = numerator / totalcollectorarea
			#runner.registerInfo("Variable avg_pv_eff = #{avg_pv_eff} was calculated.")
		end

		# get inverter name for the dist system
		inverter_name = distSystem.getString(7).get
		# get inverter object (assume only one with the name given)
		inverter = idf.getObjectsByName(inverter_name)[0]
		#runner.registerInfo("inverter = #{inverter}.")
		# Find the inverter efficiency based on the type of E+ inverter object
		if inverter.getDouble(12).is_initialized			# PVWatts or LookUpTable
			inverter_perf_eff = inverter.getDouble(12).get
		elsif inverter.getDouble(7).is_initialized			# ElectricLoadCenterInverterFunctionOfPower
			inverter_perf_eff = inverter.getDouble(7).get
		elsif inverter.getDouble(4).is_initialized			# Simple
			inverter_perf_eff = inverter.getDouble(4).get
		end
		#runner.registerInfo("inverter efficiency = #{inverter_perf_eff}.")

		# sum max power output of systems
		sumMaxPowerOutput += pv_watts.round(0)
		
		if panel_country == 'Other'
			panel_country = 'China'
		end
		
		#create pv system object
		if panel_type != 'None'
		sys = {
			'panelType' => panel_type,						# User must provide. OpenStudio does not have enumerations for Solar PV
			'maxPowerOutput' => pv_watts.round(0),			# Watts based on efficiency function above
			'collectorArea' => totalcollectorarea.round(2),	# m2 - Calculated above using surfacearea for each surface with Solar PV
			'inverterType' => inverter_type.upcase ,		# User must provide. OpenStudio does not have enumerations for Solar PV
			'inverterEfficiency' => inverter_perf_eff,		# Defaulted to 0.98 - Can get from the inverter E+ objects.
			'annualOutput' => 0,							# kWh - taken from the LEED Summary Report (see above)
			'calculatedEfficiency' => avg_pv_eff.round(3),	# Calculated above from the weighted average of the area and performance efficiency
			'panelSourceCountry' => panel_country.upcase	# User must provide. OpenStudio does not have enumerations for Solar PV
		}
		end
		#add system to array
		pvt_systems << sys
	end
	
	# Solar PV Production
	total_energy_g = 0.0
	net_energy_g = 0.0
	pv_prod_gj = 0.0
	
	# Previously pulled from LEED Summary, but it does not account for PV system losses.
	# Instead use total site and net site values to determine the reduction of site energy by PV.
	# Value aligns with what the meter reading will be, which is how to determine the electricity reduction.
	
	# query = "SELECT Value
		# FROM tabulardatawithstrings
		# WHERE ReportName='LEEDsummary'
		# AND ReportForString='Entire Facility'
		# AND TableName='L-1. Renewable Energy Source Summary'
		# AND ColumnName='Annual Energy Generated'
		# AND RowName='Photovoltaic'"       

	#pv_prod_gj = sql.execAndReturnFirstDouble(query)
	#runner.registerInfo("pv_prod_gj = #{pv_prod_gj}.")
	
	if sql.totalSiteEnergy.is_initialized
		total_energy_gj = sql.totalSiteEnergy.get
	else
		total_energy_gj = 0
	end
	
	if sql.netSiteEnergy.is_initialized
		net_energy_gj = sql.netSiteEnergy.get
	else
		net_energy_gj = 0
	end
	
	pv_prod_gj = total_energy_gj - net_energy_gj
	#runner.registerInfo("pv_prod_gj was calculated. Equals #{pv_prod_gj}")

	pv_prod_kwh = OpenStudio.convert(pv_prod_gj,'GJ','kWh').get
	runner.registerInfo("pv_prod_kwh was calculated = #{pv_prod_kwh}.")

	#calculate part of total solar production for each system
	# based on each system's max power output
	pvt_systems.each do |pvt_system|
		maxPowerOutput = pvt_system.fetch("maxPowerOutput")
		annualOutput = pv_prod_kwh * maxPowerOutput / sumMaxPowerOutput
		pvt_system.store("annualOutput", annualOutput.round(0))
	end

	return pvt_systems

	#runner.registerInfo("Solar PV Object has been created.")


	# Get the sqlFile attached to the model
	def sql()

		sql = self.model.sqlFile

		if sql.is_initialized
			sql = sql.get
		else
			sql = nil
		end

		return sql

	end
  
end


#####################################
#Solar Thermal Systems
#####################################

def get_hw_solar_thermals(model,runner,user_arguments,sql, solar_thermal_sys_type, solar_thermal_collector_type,
solar_thermal_loop_type)

  pvt_systems = []

  # Each plantloop will be treated as a separate system
  model.getPlantLoops.each do |loop|
  
    total_area_m2 = 0.0
    total_volume_m3 = 0.0
    #runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
    
	# Flat plate PVT on supply side
	### The code was written for a different solar collector then what is in OS. Need to generalize as OS adds options. See code below.
	loop.supplyComponents.each do |sc|

		if sc.to_SolarCollectorFlatPlateWater.is_initialized
			pvt = sc.to_SolarCollectorFlatPlateWater.get
			#runner.registerInfo("Object FlatPlateWater = #{pvt} was found.")
			  
			# Get the surface area and add to total
			if pvt.surface.is_initialized
				surf = pvt.surface.get
				area_m2 = surf.grossArea
				total_area_m2 += area_m2
				#runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
			end
		end
		if sc.to_SolarCollectorFlatPlatePhotovoltaicThermal.is_initialized
			pvt = sc.to_SolarCollectorPerformancePhotovoltaicThermalSimple.get
			#runner.registerInfo("Object FlatPlatePhotovoltaicThermal = #{pvt} was found.")
			  
			# Get the surface area and add to total
			if pvt.surface.is_initialized
				surf = pvt.surface.get
				area_m2 = surf.grossArea
				total_area_m2 += area_m2
				#runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
			end
		end
		if sc.to_SolarCollectorIntegralCollectorStorage.is_initialized
			pvt = sc.to_SolarCollectorIntegralCollectorStorage.get
			#runner.registerInfo("Object IntegralCollectorStorage = #{pvt} was found.")
			  
			# Get the performance object
			perf = pvt.solarCollectorPerformance
			#add the area
			area_m2 = perf.grossArea
			total_area_m2 += area_m2
			#runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
			#add the volume
			vol_m3 = perf.collectorWaterVolume 
			total_volume_m3 += vol_m3
		end
	end
		  
	# loop.supplyComponents.each do |sc|
      # next unless sc.to_SolarCollectorFlatPlatePhotovoltaicThermal.is_initialized
      # pvt = sc.to_SolarCollectorFlatPlatePhotovoltaicThermal.get
      # runner.registerInfo("Object pvt = #{pvt} was found.")
      	  
      # # Get the surface area and add to total
      # next unless pvt.surface.is_initialized
      # surf = pvt.surface.get
      # area_m2 = surf.grossArea
      # total_area_m2 += area_m2
      # runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
    #end
	
     # Water heaters as storage on the demand side
    loop.demandComponents.each do |dc|
      next unless dc.to_WaterHeaterMixed.is_initialized
      wh = dc.to_WaterHeaterMixed.get
      #runner.registerInfo("solar thermal tank = #{wh} was found.")

      # Get the volume and add to total
      vol_m3 = 0.0
      if wh.tankVolume.is_initialized
        vol_m3 = wh.tankVolume.get
        #runner.registerInfo("solar thermal tank volume = #{vol_m3} was found.")

      end
      total_volume_m3 += vol_m3

    end 

    # Only a PVT system if it has both PVT and storage
    next unless total_area_m2 > 0 && total_volume_m3 > 0
    
    # Convert units
    total_area_ft2 = OpenStudio.convert(total_area_m2, 'm^2', 'ft^2').get
    total_volume_gal = OpenStudio.convert(total_volume_m3, 'm^3', 'gal').get 
	
	system_type_enum = ""
	if solar_thermal_sys_type == 'None'
		runner.registerInfo("Solar thermal system skipped due to system type 'None' selected.")
		next
	elsif solar_thermal_sys_type == 'Hot Water'
		system_type_enum = 'HOT_WATER'
	elsif solar_thermal_sys_type == 'Space Heating'
		system_type_enum = 'SPACE_HEATING'
	elsif solar_thermal_sys_type == 'Hot Water and Space Heating'
		system_type_enum = 'HOT_WATER_AND_SPACE_HEATING'
	elsif solar_thermal_sys_type == 'Hybrid'
		system_type_enum = 'HYBRID_SYSTEM'
	end
	
	collector_type_enum = ""
	if solar_thermal_collector_type == 'None'
		runner.registerInfo("Solar thermal system skipped due to collector type 'None' selected.")
		next
	elsif solar_thermal_collector_type == 'Integrated Collector Storage'
		collector_type_enum = 'INTEGRATED_COLLECTOR_STORAGE'
	elsif solar_thermal_collector_type == 'Evacuated Tube'
		collector_type_enum = 'EVACUATED_TUBE'
	elsif solar_thermal_collector_type == 'Double Glazing Selective'
		collector_type_enum = 'DOUBLE_GLAZING_SELECTIVE'
	elsif solar_thermal_collector_type == 'Double Glazing Black'
		collector_type_enum = 'DOUBLE_GLAZING_BLACK'
	elsif solar_thermal_collector_type == 'Single Glazing Selective'
		collector_type_enum = 'SINGLE_GLAZING_SELECTIVE'
	elsif solar_thermal_collector_type == 'Single Glazing Black'
		collector_type_enum = 'SINGLE_GLAZING_BLACK'
	end
	
	solar_thermal_loop_type_enum = ''
	if solar_thermal_loop_type ==  'None'
		runner.registerInfo("Solar thermal system skipped due to thermal loop type 'None' selected.")
		next
	elsif solar_thermal_loop_type == 'Passive Thermosyphon'
		solar_thermal_loop_type_enum = 'PASSIVE_THERMOSYPHON'
	elsif solar_thermal_loop_type == 'Liquid Indirect'
		solar_thermal_loop_type_enum = 'LIQUID_INDIRECT'
	elsif solar_thermal_loop_type == 'Liquid Direct'
		solar_thermal_loop_type_enum = 'LIQUID_DIRECT'
	elsif solar_thermal_loop_type == 'Air Indirect'
		solar_thermal_loop_type_enum = 'AIR_INDIRECT'
	elsif solar_thermal_loop_type == 'Air Direct'
		solar_thermal_loop_type_enum = 'AIR_DIRECT'
	end

	### Currently assumes a flat plate collector
    sys = {
      'systemType' => system_type_enum,     
      'collectorType' => collector_type_enum,
	  'collectorLoopType' => solar_thermal_loop_type_enum,
	  'storageVolume' => total_volume_gal.round(0),
      'collectorArea' => total_area_ft2.round(2)
    }
    pvt_systems << sys
    #runner.registerInfo("solar thermal system = #{pvt_systems} was found.")
  end

  return pvt_systems
  
end
