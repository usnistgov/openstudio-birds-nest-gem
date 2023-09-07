# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#############################################################
# Appliances - user inputs required because no way to identify appliances from the model
#############################################################
# Initialize Appliance Object, which will be an object of objects for each appliance.
# TO DO - Currently there will only be 1 appliance for each type selected, but this should be expanded in the future.
# TO DO - the current json format is not consistent with the example output file because the arrays are reported.
# But there is no heading for the type of appliances.

def freezer_type_enum(app_freezer_type)
  case app_freezer_type
  when 'Chest'
    'CASE'
  when 'Upright'
    'UNCATEGORIZED'
  else
    'UNCATEGORIZED'
  end
end

def freezers(appliance_freezer)
  # Create Freezer
  return [{}] if appliance_freezer == 'No_Freezer'

  app_freezer_type, _, app_freezer_eff = appliance_freezer.split('_')

  [
    {
      'volume' => 0,
      'ef' => app_freezer_eff.to_f,
      'numberOfUnits' => 1,
      'configuration' => freezer_type_enum(app_freezer_type),
      'thirdPartyCertification' => 'NULL'
    }
  ]
end

def dishwashers(appliance_dishwasher)
  # Create Dishwasher
  # Assumes only one dishwasher. Could create a do loop if more than one is available.
  return [{}] if appliance_dishwasher == 'No Dishwasher'

  [
    {
      'energyFactor' => 0,
      'ratedWaterPerCycle' => 0,
      'placeSettingCapacity' => 0,
      'numberOfUnits' => 1,
      'type' => 'BUILT_IN_UNDER_COUNTER',
      'fuelType' => 'ELECTRICITY',
      'thirdPartyCertification' => 'NULL',
    }
  ]
end

def frig_type_enum(app_frig_type)
  case app_frig_type
  when 'BottomFreezer'
    'BOTTOM_FREEZER'
  when 'SideFreezer'
    'SIDE_BY_SIDE'
  when 'TopFreezer'
    'TOP_FREEZER'
  else
    'TOP_FREEZER'
  end
end

def frig_cert_enum(app_frig_cert)
  if app_frig_cert == 'EnergyStar'
    'ENERGY_STAR'
  else
    ''
  end
end

def refrigerators(appliance_frig)
  # Create Refrigerator object.
  # Assumes only one frig. Could create a do loop if more than one is available.
  app_frig_type, _, app_frig_eff, _, app_frig_vol, app_frig_cert = appliance_frig.split('_')

  return [{}] if app_frig_type == 'None'

  # Need the cert amd  type for clothes washer.
  # Assume only 1 clothes washer. Should add option for more with multifaimly.
  # Hard code values that are not currently needed for BIRDS NEST.
  # Currently does not provide the type of appliance object, just an array. Need to match the proto format
  [
    {
      'type' => frig_type_enum(app_frig_type),
      'thirdPartyCertification' => frig_cert_enum(app_frig_cert),
      'volume' => app_frig_vol.to_f,
      'numberOfUnits' => 1,
      'ef' => app_frig_eff.to_f
    }
  ]
end

def cooking_range_fuel_type(appliance_cooking_range)
  case appliance_cooking_range
  when 'Electric', 'Electric Induction'
    'ELECTRICITY'
  when 'Gas'
    'NATURAL_GAS'
  when 'Propane'
    'PROPANE'
  else
    'NULL'
  end
end

def cooking_ranges(appliance_cooking_range)
  # Create Cooking Range object and add to appliance object.
  # Assumes only one cooking range. Could create a do loop if more than one is available.
  return [{}] if appliance_cooking_range == 'No Cooking Range'

  [
    {
      'isInduction' => appliance_cooking_range == 'Electric Induction',
      'numberOfUnits' => 1,
      'fuelType' => cooking_range_fuel_type(appliance_cooking_range),
      'thirdPartyCertification' => 'NULL'
    }
  ]
end

def clothes_dryer_fuel_type(appliance_clothes_dryer)
  case appliance_clothes_dryer
  when 'Electric', 'Electric Heat Pump', 'Electric Premium'
    'ELECTRICITY'
  when 'Gas', 'Gas Premium'
    'NATURAL_GAS'
  when 'Propane'
    'PROPANE'
  else
    ''
  end
end

def clothes_dryers(appliance_clothes_dryer)
  # Create Clothes Dryer object and add to appliance object.
  # Assumes only one clothes dryer. Could create a do loop if more than one is available.
  return [{}] if appliance_clothes_dryer == 'No Clothes Dryer'

  [
    {
      'efficiencyFactor' => 0,
      'numberOfUnits' => 1,
      'type' => 'DRYER',
      'fuelType' => clothes_dryer_fuel_type(appliance_clothes_dryer),
      'thirdPartyCertification' => 'NULL',
    }
  ]
end

def clothes_washer_cert(appliance_clothes_washer)
  if appliance_clothes_washer == 'EnergyStar'
    'ENERGY_STAR'
  else
    'NULL'
  end
end

def clothes_washers(appliance_clothes_washer)
  # Create Clothes Washer object and add to appliance object.
  # Assumes only one clothes washer. Could create a do loop if more than one is available.
  return [{}] if appliance_clothes_washer == 'No Clothes Washer'

  # Only need the certification type for clothes washer.
  # Assume only 1 clothes washer. Should add option for more with multifaimly.
  # Hard code values that are not currently needed for BIRDS NEST.
  # runner.registerInfo("Clothes Washer Type is #{app_clothes_washer_type}.")

  [
    {
      'type' => 'FRONT_LOADER',
      'thirdPartyCertification' => clothes_washer_cert(appliance_clothes_washer),
      'modifiedEnergyFactor' => 0,
      'waterFactor' => 0,
      'capacity' => 0,
      'numberOfUnits' => 1
    }
  ]
end

def get_appliances(clothes_washer, clothes_dryer, cooking_range, frig, dishwasher, freezer)
  {
    'clothesWashers' => clothes_washers(clothes_washer),
    'clothesDryers' => clothes_dryers(clothes_dryer),
    'cookingRanges' => cooking_ranges(cooking_range),
    'refrigerators' => refrigerators(frig),
    'dishWashers' => dishwashers(dishwasher),
    'freezers' => freezers(freezer)
  }
end
