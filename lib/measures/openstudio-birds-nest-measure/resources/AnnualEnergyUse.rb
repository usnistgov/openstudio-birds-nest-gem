# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

###################################################
# Resource Use - Currently Annual Energy Use - Pulls from the SQL results file.
###################################################
# Includes energy use and water use, but can be expanded in the future to include other resources if appropriate.

def energy_use(sql, fuel_type_method, name, unit: 'GJ', convert: ->(v) { v }, round: 0, default: false)
  value = fuel_type_method.map { |type| sql.send(type).get }
                          .map { |v| convert.call(v) }
                          .compact

  return nil if value.empty? && !default

  {
    'fuelType' => name,
    'consumption' => value.sum.round(round),
    'unitOfMeasure' => unit
  }
end

def check_other_energy(sql, fuel_type_methods, runner)
  fuel_type_methods.each do |fuel_type|
    if sql.send(fuel_type).get != 0
      runner.registerError("Fuel type #{fuel_type} is not included in the LCA calculations. Included fuel types are Electricity, Fuel Oil, Propane, and Natural Gas.")
    end
  end
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

  check_other_energy(sql, %i[gasolineTotalEndUses dieselTotalEndUses coalTotalEndUses otherFuel1TotalEndUses otherFuel2TotalEndUses districtCoolingTotalEndUses districtHeatingTotalEndUses], runner)

  [
    energy_use(sql, %i[electricityTotalEndUses], 'ELECTRICITY', unit: 'KWH', convert: ->(v) { OpenStudio.convert(v, 'GJ', 'kWh').get }, default: true),
    energy_use(sql, %i[naturalGasTotalEndUses], 'NATURAL_GAS', round: 6),
    energy_use(sql, %i[propaneTotalEndUses], 'PROPANE'),
    energy_use(sql, %i[fuelOilNo1TotalEndUses fuelOilNo2TotalEndUses], 'FUEL_OIL'),
  ].compact
end

def annual_water_usage(sql)
  ###################################################
  # Annual Water Use - Pulls from the SQL results file.
  ###################################################
  value = sql.waterTotalEndUses.get
  value = 0 if value.nil?

  [
    {
      'waterType' => 'INDOOR_AND_OUTDOOR_WATER',
      'consumption' => value * 264.1721,
      'unitOfMeasure' => 'GAL'
    }
  ]
end
