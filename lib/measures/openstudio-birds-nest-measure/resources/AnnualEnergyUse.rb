# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

###################################################
# Resource Use - Currently Annual Energy Use - Pulls from the SQL results file.
###################################################
# Includes energy use and water use, but can be expanded in the future to include other resources if appropriate.

def get_annual_energyuse(birds, runner, sql, user_arguments)

  # Sets primary heating fuel; assumed to be the "other fuel" if there is some.
  pri_hvac = runner.getStringArgumentValue('pri_hvac', user_arguments)

  # May not be for future multifamily capabilities.
  _, _, _, detail4 = pri_hvac.split('_')
  runner.registerInfo("Heating Fuel is #{detail4}.")

  ###################################################
  # Annual Energy Use - Pulls from the SQL results file.
  ###################################################

  birds['annualEnergyUses'] = []

  # Electricity
  elec_gj = if sql.electricityTotalEndUses.is_initialized
              sql.electricityTotalEndUses.get
            else
              0.0
            end

  elec_kwh = OpenStudio.convert(elec_gj, 'GJ', 'kWh').get
  runner.registerInfo("Successfully converted Electricity to kWh = #{elec_kwh}.")
  annual_electricity_use = {
    'fuelType' => 'ELECTRICITY',
    'consumption' => elec_kwh.round(0),
    'unitOfMeasure' => 'KWH'
  }
  birds['annualEnergyUses'] << annual_electricity_use

  # Natural Gas
  gas_gj = 0.0
  gas_gj = sql.naturalGasTotalEndUses.get if sql.naturalGasTotalEndUses.is_initialized
  # gas_kwh = OpenStudio.convert(gas_gj,'GJ','kWh').get
  ### Convert to 1000 ft3 of natural gas because BIRDS NEST API source data is in flow per 1000 ft3 (1 kft3 = 293.07 kWh)
  # gas_kft3 = gas_kwh / 293.07
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
    other_fuel_type = case detail4
                      when 'Oil'
                        'FUEL_OIL'
                      when 'Propane'
                        'PROPANE'
                      else
                        'NULL'
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
end

def annual_water_usage(sql)
  ###################################################
  # Annual Water Use - Pulls from the SQL results file.
  ###################################################

  # Water
  water_m3 = if sql.waterTotalEndUses.is_initialized
               sql.waterTotalEndUses.get
             else
               0.0
             end

  [
    {
      'waterType' => 'INDOOR_AND_OUTDOOR_WATER',
      'consumption' => (water_m3 * 264.1721).round(0),
      'unitOfMeasure' => 'GAL'
    }
  ]
end
