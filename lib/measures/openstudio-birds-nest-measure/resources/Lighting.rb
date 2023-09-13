# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#################################################################################################
# Lighting
# The code could be cleaned up to be more concise.
################################################################################################

def num_people(light_zone, light_zone_area, people, people_zone)
  0 unless people_zone == light_zone

  case people.getString(3).get
  when 'People'
    people.getString(5).get
  when 'People/Area'
    people_per_area = people.getString(6).get

    people_per_area * light_zone_area
  when 'Area/Person'
    area_per_person = people.getString(7).get

    light_zone_area / area_per_person
  else
    0
  end
end

def wattage_calc_method(idf, light, light_calc_method, light_name, light_zone, light_zone_area, runner)
  case light_calc_method
  when 'LightingLevel'
    light.getDouble(4).get
  when 'Watts/Area'
    watts_per_area = light.getString(5).get.to_f
    watts_per_area * light_zone_area
  when 'Watts/Person'
    watts_per_person = light.getDouble(6).get
    people = idf.getObjectsByType('People'.to_IddObjectType)

    people.map { |person| watts_per_person * num_people(light_zone, light_zone_area, people, person.getString(1).get) }
          .sum
  else
    runner.registerWarning("'#{light_name}' not used.")
    0
  end
end

def light_wattage(light, idf, model)
  light_name = light.getString(0).get
  light_zone = light.getString(1).get
  light_zone_area = model.getThermalZones
                         .select { |zone| zone.name.get.match(light_zone) }
                         .last
                         .floorArea
  light_zone_area = light_zone_area.nil? ? 0 : light_zone_area

  # get light calculation method and make wattage calculation
  wattage_calc_method(idf, light, light.getString(3).get, light_name, light_zone, light_zone_area, runner)
end

def total_wattage(idf, model)
  # Calculate Total Lighting Wattage using the 3 different methods of including lighting in E+
  # This includes lighting level, watts per person, and watts per floor area, each require different calculations.
  idf.getObjectsByType('Lights'.to_IddObjectType)
     .map { |light| light_wattage(light, idf, model) }
     .sum
     .round(1)
end

def get_lighting(idf, pct_inc_lts, pct_mh_lts, pcf_cfl_lf_lts, pct_led_lts, model)
  # Create Lighting Object. Only need the lighting group OR the lighting fraction with total wattage for BIRDS NEST.
  {
    'lightingGroups' => [], # would be populated with lighting_groups
    'lightingFractions' => {
      'fracIncandescent' => pct_inc_lts.to_f / 100.0, # pct_inc_lts / 100.0,
      'fracMetalHalide' => pct_mh_lts.to_f / 100.0, # pct_mh_lts / 100.0,
      'fracCflLf' => pcf_cfl_lf_lts.to_f / 100.0, # pct_cfl_lf_lts / 100.0,
      'fracLed' => pct_led_lts.to_f / 100.0 # pct_led_lts / 100.0
    }, # Comes from user inputs.
    'totalWattage' => total_wattage(idf, model), # Aggregate wattage for all lighting objects in the OSM, currently defaulted to 999
    'ceilingFans' => [
      {
        'thirdPartyCertification' => 'NULL'
      }
    ] # Defaulted to an array of one EnergyStar for testing
  }
end
