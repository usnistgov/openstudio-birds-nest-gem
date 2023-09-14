# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

###################################################
# Resource Use - Currently Annual Energy Use - Pulls from the SQL results file.
###################################################
# Includes energy use and water use, but can be expanded in the future to include other resources if appropriate.

def energy_use(sql, fuel_type_method, name, unit: 'GJ', convert: nil, round: 0, default: false)
  value = fuel_type_method.map { |type| sql.send(type).get }
                          .map { |v| convert(v) unless convert.nil? }
                          .compact
                          .sum

  return nil if value.empty? && !default

  {
    'fuelType' => name,
    'consumption' => value.round(round),
    'unitOfMeasure' => unit
  }
end

def get_annual_energyuse(runner, sql, user_arguments)
  ###################################################
  # Annual Energy Use - Pulls from the SQL results file.
  ###################################################

  # Sets primary heating fuel; assumed to be the "other fuel" if there is some.
  pri_hvac = runner.getStringArgumentValue('pri_hvac', user_arguments)

  # May not be for future multifamily capabilities.
  _, _, _, detail4 = pri_hvac.split('_')
  runner.registerInfo("Heating Fuel is #{detail4}.")

  [
    energy_use(sql, %i[electricityTotalEndUses], 'ELECTRICITY', unit: 'KWH', convert: ->(v) { OpenStudio.convert(v, 'GJ', 'kWh').get }, default: true),
    energy_use(sql, %i[naturalGasTotalEndUses], 'NATURAL_GAS', round: 6),
    energy_use(sql, %i[propaneTotalEndUses], 'PROPANE'),
    energy_use(sql, %i[fuelOilNo1TotalEndUses fuelOilNo2TotalEndUses], 'FUEL_OIL'),
    energy_use(sql, %i[gasolineTotalEndUses dieselTotalEndUses coalTotalEndUses otherFuel1TotalEndUses otherFuel2TotalEndUses districtCoolingTotalEndUses districtHeatingTotalEndUses], 'NULL')
  ].compact
end

def annual_water_usage(sql)
  ###################################################
  # Annual Water Use - Pulls from the SQL results file.
  ###################################################
  [energy_use(sql, %i[waterTotalEndUses], 'INDOOR_AND_OUTDOOR_WATER', unit: 'GAL', convert: ->(water) { water * 264.1721 }), defautl: true]
end
