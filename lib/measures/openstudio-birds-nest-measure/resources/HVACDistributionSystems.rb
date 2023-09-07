# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

######################################
# HVAC Distribution Systems - user defined values
######################################

def get_hvac_dist_sys(runner, pct_ductwork_inside, ductwork, numberOfStoriesAboveGrade, conditionedFloorArea, model)

  # Find the perimeter (copied from foundation.rb)
  perimeter_ft_SDHV_main = 0
  perimeter_ft_SDHV_branch = 0
  model.getSurfaces.each do |surf|
    # Skip surfaces that aren't floors
    next unless surf.surfaceType == 'Floor' && surf.outsideBoundaryCondition == 'Ground'

    # find foundation floor width and length
    floor_x_max = -1_000_000_000
    floor_x_min = 1_000_000_000
    floor_y_max = -1_000_000_000
    floor_y_min = 1_000_000_000

    vertices = surf.vertices
    vertices.each do |vertex|
      x = vertex.x
      if x < floor_x_min
        floor_x_min = x
      else
        next
      end
      floor_x_max = x if x > floor_x_max
      y = vertex.y
      if y < floor_y_min
        floor_y_min = y
      else
        next
      end
      floor_y_max = y if y > floor_y_max
    end
    floor_length_m = floor_x_max - floor_x_min
    # runner.registerInfo("floor length = #{floor_length_m}.")
    # Convert to IP
    found_floor_length_ft = OpenStudio.convert(floor_length_m, 'm', 'ft').get

    floor_width_m = floor_y_max - floor_y_min
    # runner.registerInfo("floor width = #{floor_width_m}.")
    # Convert to IP
    found_floor_width_ft = OpenStudio.convert(floor_width_m, 'm', 'ft').get

    perimeter_ft_SDHV_main = found_floor_length_ft * 0.8 * 2 + found_floor_width_ft * 0.8 * 2
    perimeter_ft_SDHV_branch = found_floor_length_ft * 0.2 * 2 + found_floor_width_ft * 0.2 * 2
  end

  # runner.registerInfo("Moving on to HVAC distribution system objects.")
  # Determine fraction of the ductwork that is insulated
  frac_duct_insulated = 1 - (pct_ductwork_inside / 100)
  frac_duct_uninsulated = pct_ductwork_inside / 100

  # initialize distn system variables
  dist_sys = []
  duct_surface_area_supply = 0
  duct_surface_area_return = 0
  duct_surface_area_main = 0
  duct_surface_area_branch = 0

  # Calculations are made using user inputs and the benchmark functions from the 2014 Building American Simulation Protocols
  # runner.registerInfo("Determining the type of distribution system and calculating parameter values.")

  case ductwork
  when 'Small Duct High Velocity Ductwork'
    air_dist_type = 'HIGH_VELOCITY'
    hydronic_dist_type = 'OTHER'
    # SDHV ductwork LCA data is based on linear feet of ductwork, which is a function of the perimeter value in foundations.
    # Not sure what the parameter name is for perimeter or how to access it from foundation rb.
    case numberOfStoriesAboveGrade
    when 1
      duct_length_supply_main = perimeter_ft_SDHV_main + 10 # Assumes the main branch runs 80% of the perimeter and return is 10 ft/floor
      duct_length_supply_branch = perimeter_ft_SDHV_branch # Assumes the main branch runs the remaining 20% of the perimeter
    when 2
      duct_length_supply_main = perimeter_ft_SDHV_main * 2 + 10 * 2 # Assumes the main branch runs 80% of the perimeter and return is 10 ft/floor
      duct_length_supply_branch = perimeter_ft_SDHV_branch * 2 # Assumes the main branch runs the remaining 20% of the perimeter	
    else
      runner.registerInfo("Building has no stories.")
    end
    duct_surface_area_main = duct_length_supply_main * (3.14159 / 6) # Assumes 2in branch diameter
    duct_surface_area_branch = duct_length_supply_branch * (3.14159 * 7 / 12) # Assumes 7in main diameter
    duct_leakage_value_return = 0.01 * 0 # Value is in CFM but the benchmark is a % of air flow. Need to take % * total air flow from HVAC.
    duct_material = 'FLEXIBLE'
  when 'Standard Ductwork'
    air_dist_type = 'REGULAR_VELOCITY'
    hydronic_dist_type = 'OTHER'
    case numberOfStoriesAboveGrade
    when 1
      duct_surface_area_supply = 0.27 * conditionedFloorArea
      duct_surface_area_return = 0.05 * (1 + numberOfStoriesAboveGrade) * conditionedFloorArea
    when 2
      duct_surface_area_supply = 0.2 * conditionedFloorArea
      duct_surface_area_return = 0.04 * (1 + numberOfStoriesAboveGrade) * conditionedFloorArea
    else
      runner.registerInfo("Building has no stories.")
    end
    duct_surface_area = duct_surface_area_supply + duct_surface_area_return
    duct_leakage_value_supply = 0.1 * 0 # Value is in CFM but the benchmark is a % of air flow. Need to take % * total air flow from HVAC.
    duct_leakage_value_return = 0.01 * 0 # Value is in CFM but the benchmark is a % of air flow. Need to take % * total air flow from HVAC.
    duct_material = 'SHEET_METAL'
  when 'Hydronic Distribution'
    air_dist_type = 'NULL'
    hydronic_dist_type = 'BASEBOARD'
  else
    ### None option for ductwork and provides zeros for ductwork area.
    air_dist_type = 'NULL'
    hydronic_dist_type = 'OTHER'
    duct_surface_area_supply = 0
    duct_surface_area_return = 0
    duct_surface_area_main = 0
    duct_surface_area_branch = 0
    duct_leakage_value_return = 0
  end

  hydronic_sys = if ductwork == 'Hydronic Distribution'
                   {
                     'hydronicDistributionType' => hydronic_dist_type,
                     'pipeRValue' => 0, # Defaulted to zero.
                     'lengthOfPipe' => 0 # Defaulted to zero. Need a function to calculate plumbing.
                   }
                 else
                   {}
                 end

  ducts = []

  if ductwork == 'Standard Ductwork'
    duct_supply_insulated = {
      'ductType' => 'SUPPLY',
      'ductMaterial' => duct_material,
      'ductInsulationThickness' => 1.5, # Defaulted to 1.5 inches, consistent with R-8.
      'ductInsulationRValue' => 8, # Defaulted to R-8 if insulated.
      'ductSurfaceArea' => (duct_surface_area_supply * frac_duct_insulated).round(1)
    }
    ducts << duct_supply_insulated

    duct_supply_uninsulated = {
      'ductType' => 'SUPPLY',
      'ductMaterial' => duct_material,
      'ductInsulationThickness' => 0,
      'ductInsulationRValue' => 0, # Assume all ductwork is internal to conditioned space.
      'ductSurfaceArea' => (duct_surface_area_supply * frac_duct_uninsulated).round(1)
    }
    ducts << duct_supply_uninsulated

    duct_return_insulated = {
      'ductType' => 'RETURN',
      'ductMaterial' => duct_material,
      'ductInsulationThickness' => 1.5, # Defaulted to 1.5 inches, consistent with R-8.
      'ductInsulationRValue' => 8, # Defaulted to R-8 if insulated.
      'ductSurfaceArea' => (duct_surface_area_return * frac_duct_insulated).round(1)
    }
    ducts << duct_return_insulated

    duct_return_uninsulated = {
      'ductType' => 'RETURN',
      'ductMaterial' => duct_material,
      'ductInsulationThickness' => 0, # Assume all ductwork is internal to conditioned space.
      'ductInsulationRValue' => 0, # Assume all ductwork is internal to conditioned space.
      'ductSurfaceArea' => (duct_surface_area_return * frac_duct_uninsulated).round(1)
    }
    ducts << duct_return_uninsulated
  end

  if ductwork == 'Small Duct High Velocity Ductwork'
    duct_main = {
      'ductType' => 'MAIN',
      'ductMaterial' => duct_material,
      'ductInsulationThickness' => 1.5, # Defaulted to 1.5 inches, consistent with R-8.
      'ductInsulationRValue' => 8, # Defaulted to R-8 if insulated.
      'ductSurfaceArea' => duct_surface_area_main.round(1)
    }
    ducts << duct_main

    duct_branch = {
      'ductType' => 'BRANCH',
      'ductMaterial' => duct_material,
      'ductInsulationThickness' => 1.5, # Defaulted to 1.5 inches, consistent with R-8.
      'ductInsulationRValue' => 8, # Defaulted to R-8 if insulated.
      'ductSurfaceArea' => duct_surface_area_branch.round(1)
    }
    ducts << duct_branch
  end

  air_sys = {
    'airDistributionType' => air_dist_type,
    'ducts' => ducts,
    'ductLeakage' => {
      'ductLeakageUnits' => 'CFM50',
      'ductLeakageValue' => duct_leakage_value_return # duct leakage is defaulted to zero; not used in LCIA calculations
    }
  }
  dist_sys << {
    'hydronicDistribution' => hydronic_sys,
    'airDistribution' => air_sys
  }

  dist_sys
end
