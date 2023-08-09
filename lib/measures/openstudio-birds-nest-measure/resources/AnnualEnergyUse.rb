# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

###################################################
# Resource Use - Currenlty Annual Energy Use - Pulls from the SQL results file.
###################################################
# Includes energy use and water use, but can be expanded in the future to include other resources if appropriate.

def get_annual_energyuse(birds, runner, sql, user_arguments)

	# Sets primary heating fuel; assumed to be the "other fuel" if there is some.
	pri_hvac = runner.getStringArgumentValue('pri_hvac',user_arguments)

	# May not be for future multifamily capabilities.
	hvac_string = pri_hvac.gsub('Com: ','').gsub('Res: ','').strip
	detail1, detail2, detail3, detail4 = pri_hvac.split('_')
    runner.registerInfo("Heating Fuel is #{detail4}.")
	
	###################################################
	# Annual Energy Use - Pulls from the SQL results file.
	###################################################

	birds['annualEnergyUses'] =[]
    
	# Electricity
	elec_gj = 0.0
    if sql.electricityTotalEndUses.is_initialized
		elec_gj = sql.electricityTotalEndUses.get
    else
		elec_gj = 0.0		
	end
    #runner.registerInfo("Successfully found Electricity (GJ) = #{elec_gj}.")  
    elec_kwh = OpenStudio.convert(elec_gj,'GJ','kWh').get
    runner.registerInfo("Successfully converted Electricity to kWh = #{elec_kwh}.")  
	annual_electricity_use = {
	'fuelType' => 'ELECTRICITY',
	'consumption' => elec_kwh.round(0),
	'unitOfMeasure' => 'KWH'
	}
	birds['annualEnergyUses'] << annual_electricity_use
    
	#Natural Gas
    gas_gj = 0.0
    if sql.naturalGasTotalEndUses.is_initialized
		gas_gj = sql.naturalGasTotalEndUses.get
    end
    #gas_kwh = OpenStudio.convert(gas_gj,'GJ','kWh').get
    ### Convert to 1000 ft3 of natural gas because BIRDS NEST API source data is in flow per 1000 ft3 (1 kft3 = 293.07 kWh)
	#gas_kft3 = gas_kwh / 293.07
    annual_nat_gas_use = {
	'fuelType' => 'NATURAL_GAS',
	'consumption' => gas_gj.round(6),
	'unitOfMeasure' => 'GJ'
	}
	birds['annualEnergyUses'] << annual_nat_gas_use
	
	# Other Fuels
	# If other fuel, user input heating fuel is the fuel type.
	other_fuel_type = nil
	other_gj = 0.0
    if sql.otherFuelTotalEndUses.is_initialized
		other_gj = sql.otherFuelTotalEndUses.get
		if detail4 == 'Oil'
			other_fuel_type = 'FUEL_OIL'
		elsif detail4 == 'Propane'
			other_fuel_type = 'PROPANE'
		else
			other_fuel_type = 'NULL'
		end
    end
	if other_gj > 0.0
		annual_other_energy_use = {
		'fuelType' => other_fuel_type,
		'consumption' => other_gj,
		'unitOfMeasure' => 'GJ'
		}
		birds['annualEnergyUses'] << annual_other_energy_use
	end

	###################################################
	# Annual Water Use - Pulls from the SQL results file.
	###################################################

	birds['annualWaterUses'] =[]
    
	# Water
	water_m3 = 0.0
    if sql.waterTotalEndUses.is_initialized
		water_m3 = sql.waterTotalEndUses.get
    else
		water_m3 = 0.0		
	end
    #runner.registerInfo("Successfully found total water usage (m3) = #{water_m3}.")  
    water_gal = water_m3 * 264.1721
    runner.registerInfo("Successfully converted water to Gal = #{water_gal}.")  
	annual_water_use = {
	'waterType' => 'INDOOR_AND_OUTDOOR_WATER',
	'consumption' => water_gal.round(0),
	'unitOfMeasure' => 'GAL'
	}
	#runner.registerInfo("Successfully created water use array = #{annual_water_use}.")  
	birds['annualWaterUses'] << annual_water_use
	#runner.registerInfo("Completed Water Use Object.")  

end