# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# This file includes Solar PV and Solar Thermal Systems.

#################################
# Solar PV########################
#################################

def inverter_efficiency(inverter)
  # Find the inverter efficiency based on the type of E+ inverter object
  if inverter.getDouble(12).is_initialized # PVWatts or LookUpTable
    inverter.getDouble(12).get
  elsif inverter.getDouble(7).is_initialized # ElectricLoadCenterInverterFunctionOfPower
    inverter.getDouble(7).get
  elsif inverter.getDouble(4).is_initialized # Simple
    inverter.getDouble(4).get
  else
    nil
  end
end

def module_pv_perf_efficiency(module_type)
  case module_type
  when 'Standard'
    0.15
  when 'Premium'
    0.19
  when 'ThinFilm'
    0.10
  else
    0.0
  end
end

def skip_no_generators(dist_system, idf)
  # get the name of the generator list
  genListName = dist_system.getString(1).get
  # get the generator list object
  genList = idf.getObjectByTypeAndName('ElectricLoadCenter:Generators', genListName)

  if genList.empty?
    runner.registerInfo("Could not find generator list called #{genListName}.")
    nil
  else
    genList.get
  end
end

class Generator
  def initialize(name, type, gen)
    @@name = name
    @@type = type
    @@gen = gen
  end
end

def get_generator_list(gen_list, idf)
  result = []
  i = 0

  while gen_list.getString(1 + i * 5).is_initialized
    gen_name = gen_list.getString(1 + i * 5).get
    gen_type = gen_list.getString(2 + i * 5).get

    # if there is no generator name then exit the loop
    next if gen_name.length.zero?

    # get the generator object
    gen = idf.getObjectByTypeAndName(gen_type, gen_name)
    if gen.empty?
      runner.registerInfo("Could not find generator called #{gen_name}.")
      next
    end
    gen = gen.get

    # get the name and type of the generator
    result << Generator(gen_name, gen_type, gen)

    i += 1
  end

  result
end

def pv_generator_numerator(generator, idf, model)
  case generator.gen.getString(2).get
  when 'PhotovoltaicPerformance:Simple'
    surface_name = generator.gen.getString(1).get
    surface = model.getShadingSurfaceByName(surface_name)
    if surface.empty?
      runner.registerInfo("Could not find surface called #{surface_name}.")
      return 0
    end
    surface = surface.get
    surfacearea = surface.grossArea #### in m2

    pv_performance = idf.getObjectByTypeAndName('PhotovoltaicPerformance:Simple'.to_IddObjectType, pv_performance_name).get
    pv_performance_efficiency = pv_performance.getDouble(3).get

    surfacearea * pv_performance_efficiency
  when 'PhotovoltaicPerformance:Sandia'
    pv_performance = idf.getObjectByTypeAndName('PhotovoltaicPerformance:Sandia'.to_IddObjectType, pv_performance_name).get
    pv_performance_active_area = pv_performance.getDouble(1).get
    pv_performance_current_at_max_power = pv_performance.getDouble(6).get
    pv_performance_voltage_at_max_power = pv_performance.getDouble(7).get

    pv_performance_efficiency = (pv_performance_current_at_max_power * pv_performance_voltage_at_max_power) / (pv_performance_active_area * 1000)

    pv_performance_active_area * pv_performance_efficiency
  when 'PhotovoltaicPerformance:EquivalentOne-Diode'
    pv_performance = idf.getObjectByTypeAndName('PhotovoltaicPerformance:EquivalentOne-Diode'.to_IddObjectType, pv_performance_name).get
    pv_performance_active_area = pv_performance.getDouble(3).get
    pv_performance_current_at_max_power = pv_performance.getDouble(11).get
    pv_performance_voltage_at_max_power = pv_performance.getDouble(12).get
    pv_performance_reference_isolation = pv_performance.getDouble(10).get

    pv_performance_efficiency = (pv_performance_current_at_max_power * pv_performance_voltage_at_max_power) / (pv_performance_active_area * pv_performance_reference_isolation)

    pv_performance_active_area * pv_performance_efficiency
  end
end

def numerator(generator, idf, model)
  case generator.type
  when 'Generator:Photovoltaic'
    pv_generator_numerator(generator, idf, model)
  when 'Generator:PVWatts'
    surfacearea * module_pv_perf_efficiency(module_type)
  end
end

# Get all the PV systems in the model
# @return [Array] returns an array of JSON objects, where
# each object represents a PV system.
def get_solar_pvs(idf, model, runner, sql, panel_type, inverter_type, panel_country)
  # loop through distribution systems
  distSystems = idf.getObjectsByType('ElectricLoadCenter:Distribution'.to_IddObjectType)

  pvt_systems = []
  pv_watts = 0
  pv_performance_efficiency = 0
  totalcollectorarea = 0
  avg_pv_eff = 0
  sumMaxPowerOutput = 0

  generators = distSystems.map { |dist_system| skip_no_generators(dist_system, idf) }
                          .compact
                          .map { |list| get_generator_list(list, idf) }
  numerator = generators.map { |generator| numerator(generator, idf, model) }.sum

  distSystems.each do |distSystem|
    # get the name of the generator list
    genListName = distSystem.getString(1).get
    # get the generator list object
    genList = idf.getObjectByTypeAndName('ElectricLoadCenter:Generators', genListName)
    # runner.registerInfo("genList = #{genList}.")
    if genList.empty?
      runner.registerInfo("Could not find generator list called #{genListName}.")
      next
    end
    genList = genList.get
    # runner.registerInfo("genList = #{genList}.")

    # loop through list of generators
    (0..50).each do |i|
      # Assumes no more than 50 generators
      # if there is no generator name then exit the loop
      break unless genList.getString(1 + i * 5).is_initialized

      # get the name and type of the generator
      genName = genList.getString(1 + i * 5).get
      genType = genList.getString(2 + i * 5).get

      # if there is no generator name then exit the loop
      break if genName.length.zero?

      # get the generator object
      gen = idf.getObjectByTypeAndName(genType, genName)
      if gen.empty?
        runner.registerInfo("Could not find generator called #{genName}.")
        next
      end
      gen = gen.get

      # depending on generator type determine pv_watts, surface area and numerator
      case genType
      when 'Generator:Photovoltaic'
        # runner.registerInfo('genType = Generator:Photovoltaic.')
        pv_performance_type = gen.getString(2).get
        # get the performance specifications for each PV panel
        pv_performance_name = gen.getString(3).get ### if does not initialize, then its not finding a value.
        case pv_performance_type
        when 'PhotovoltaicPerformance:Simple'
          surface_name = gen.getString(1).get
          surface = model.getShadingSurfaceByName(surface_name)
          if surface.empty?
            runner.registerInfo("Could not find surface called #{surface_name}.")
            next
          end
          surface = surface.get
          surfacearea = surface.grossArea #### in m2

          pv_performance = idf.getObjectByTypeAndName('PhotovoltaicPerformance:Simple'.to_IddObjectType, pv_performance_name).get
          pv_performance_efficiency = pv_performance.getDouble(3).get

          # Use the performance specs and the surface area for the panel to estimate wattage.
          pv_watts += surfacearea * pv_performance_efficiency * 1000 # estimates wattage
          totalcollectorarea += surfacearea

        when 'PhotovoltaicPerformance:Sandia'
          pv_performance = idf.getObjectByTypeAndName('PhotovoltaicPerformance:Sandia'.to_IddObjectType, pv_performance_name).get
          pv_performance_active_area = pv_performance.getDouble(1).get
          pv_performance_current_at_max_power = pv_performance.getDouble(6).get
          pv_performance_voltage_at_max_power = pv_performance.getDouble(7).get

          pv_performance_efficiency = (pv_performance_current_at_max_power * pv_performance_voltage_at_max_power) / (pv_performance_active_area * 1000)

          pv_watts += pv_performance_active_area * 1000

          totalcollectorarea += pv_performance_active_area
        when 'PhotovoltaicPerformance:EquivalentOne-Diode'
          pv_performance = idf.getObjectByTypeAndName('PhotovoltaicPerformance:EquivalentOne-Diode'.to_IddObjectType, pv_performance_name).get
          pv_performance_active_area = pv_performance.getDouble(3).get
          pv_performance_current_at_max_power = pv_performance.getDouble(11).get
          pv_performance_voltage_at_max_power = pv_performance.getDouble(12).get
          pv_performance_reference_isolation = pv_performance.getDouble(10).get

          pv_performance_efficiency = (pv_performance_current_at_max_power * pv_performance_voltage_at_max_power) / (pv_performance_active_area * pv_performance_reference_isolation)

          pv_watts += pv_performance_active_area * pv_performance_reference_isolation

          totalcollectorarea += pv_performance_active_area
        end

      when 'Generator:PVWatts'
        surface_name = gen.getString(9).get
        surface = model.getShadingSurfaceByName(surface_name)
        if surface.empty?
          runner.registerInfo("Could not find surface called #{surface_name}.")
          next
        end
        surface = surface.get
        surfacearea = surface.grossArea #### in m2

        module_type = gen.getString(3).get
        pv_watts += gen.getDouble(2).get

        totalcollectorarea += surfacearea
      end
    end

    # determine average efficiency of system
    if totalcollectorarea.positive?
      avg_pv_eff = numerator / totalcollectorarea
      # runner.registerInfo("Variable avg_pv_eff = #{avg_pv_eff} was calculated.")
    end

    # get inverter name for the dist system
    inverter_name = distSystem.getString(7).get
    # get inverter object (assume only one with the name given)
    inverter = idf.getObjectsByName(inverter_name)[0]

    # sum max power output of systems
    sumMaxPowerOutput += pv_watts.round(0)

    # create pv system object
    next if panel_type == 'None'

    pvt_systems << {
      'panelType' => panel_type, # User must provide. OpenStudio does not have enumerations for Solar PV
      'maxPowerOutput' => pv_watts.round(0), # Watts based on efficiency function above
      # m2 - Calculated above using surfacearea for each surface with Solar PV
      'collectorArea' => totalcollectorarea.round(2),
      'inverterType' => inverter_type.upcase, # User must provide. OpenStudio does not have enumerations for Solar PV
      # Defaulted to 0.98 - Can get from the inverter E+ objects.
      'inverterEfficiency' => inverter_efficiency(inverter),
      'annualOutput' => 0, # kWh - taken from the LEED Summary Report (see above)
      # Calculated above from the weighted average of the area and performance efficiency
      'calculatedEfficiency' => avg_pv_eff.round(3),
      # User must provide. OpenStudio does not have enumerations for Solar PV
      'panelSourceCountry' => ('China' if panel_country == 'Other').upcase
    }
  end

  total_energy_gj = if sql.totalSiteEnergy.is_initialized
                      sql.totalSiteEnergy.get
                    else
                      0
                    end

  net_energy_gj = if sql.netSiteEnergy.is_initialized
                    sql.netSiteEnergy.get
                  else
                    0
                  end

  pv_prod_gj = total_energy_gj - net_energy_gj
  # runner.registerInfo("pv_prod_gj was calculated. Equals #{pv_prod_gj}")

  pv_prod_kwh = OpenStudio.convert(pv_prod_gj, 'GJ', 'kWh').get
  runner.registerInfo("pv_prod_kwh was calculated = #{pv_prod_kwh}.")

  # calculate part of total solar production for each system
  # based on each system's max power output
  pvt_systems.each do |pvt_system|
    maxPowerOutput = pvt_system.fetch('maxPowerOutput')
    annualOutput = pv_prod_kwh * maxPowerOutput / sumMaxPowerOutput
    pvt_system.store('annualOutput', annualOutput.round(0))
  end

  pvt_systems
end

#####################################
# Solar Thermal Systems
#####################################

def water_heater_tank_volume(component)
  wh = component.to_WaterHeaterMixed.get
  if wh.tankVolume.is_initialized
    wh.tankVolume.get
  else
    0.0
  end
end

def get_hw_solar_thermals(model, runner, user_arguments, sql, solar_thermal_sys_type, solar_thermal_collector_type, solar_thermal_loop_type)

  pvt_systems = []

  # Each plantloop will be treated as a separate system
  model.getPlantLoops.each do |loop|

    total_area_m2 = 0.0
    total_volume_m3 = 0.0

    # Flat plate PVT on supply side
    ### The code was written for a different solar collector then what is in OS. Need to generalize as OS adds options. See code below.
    loop.supplyComponents.each do |sc|

      if sc.to_SolarCollectorFlatPlateWater.is_initialized
        pvt = sc.to_SolarCollectorFlatPlateWater.get
        # runner.registerInfo("Object FlatPlateWater = #{pvt} was found.")

        # Get the surface area and add to total
        if pvt.surface.is_initialized
          surf = pvt.surface.get
          area_m2 = surf.grossArea
          total_area_m2 += area_m2
          # runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
        end
      end

      if sc.to_SolarCollectorFlatPlatePhotovoltaicThermal.is_initialized
        pvt = sc.to_SolarCollectorPerformancePhotovoltaicThermalSimple.get
        # runner.registerInfo("Object FlatPlatePhotovoltaicThermal = #{pvt} was found.")

        # Get the surface area and add to total
        if pvt.surface.is_initialized
          surf = pvt.surface.get
          area_m2 = surf.grossArea
          total_area_m2 += area_m2
          # runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
        end
      end

      next unless sc.to_SolarCollectorIntegralCollectorStorage.is_initialized

      pvt = sc.to_SolarCollectorIntegralCollectorStorage.get
      # runner.registerInfo("Object IntegralCollectorStorage = #{pvt} was found.")

      # Get the performance object
      perf = pvt.solarCollectorPerformance
      # add the area
      area_m2 = perf.grossArea
      total_area_m2 += area_m2
      # runner.registerInfo("total_area_m2 = #{total_area_m2} was found.")
      # add the volume
      vol_m3 = perf.collectorWaterVolume
      total_volume_m3 += vol_m3
    end

    total_volume_m3 += loop.demandComponents
                           .select { |component| component.to_WaterHeaterMixed.is_initialized }
                           .map(&method(:water_heater_tank_volume))
                           .sum

    # Only a PVT system if it has both PVT and storage
    next unless total_area_m2.positive? && total_volume_m3.positive?

    # Convert units
    total_area_ft2 = OpenStudio.convert(total_area_m2, 'm^2', 'ft^2').get
    total_volume_gal = OpenStudio.convert(total_volume_m3, 'm^3', 'gal').get

    system_type_enum = type_to_enum(solar_thermal_sys_type, runner, 'system', { 'Hybrid' => 'HYBRID_SYSTEM' })
    next if system_type_enum.nil?

    collector_type_enum = type_to_enum(solar_thermal_collector_type, runner, 'collector')
    next if system_type_enum.nil?

    solar_thermal_loop_type_enum = type_to_enum(solar_thermal_loop_type, runner, 'thermal')
    next if system_type_enum.nil?

    ### Currently assumes a flat plate collector
    pvt_systems << {
      'systemType' => system_type_enum,
      'collectorType' => collector_type_enum,
      'collectorLoopType' => solar_thermal_loop_type_enum,
      'storageVolume' => total_volume_gal.round(0),
      'collectorArea' => total_area_ft2.round(2)
    }
  end

  pvt_systems
end

def type_to_enum(value, runner, error_name = '', replacements = {})
  if value == 'None'
    runner.registerInfo("Solar thermal system system skipped due to #{error_name} type 'None' selected.")
    nil
  elsif replacements.key? value
    replacements[value]
  else
    value.gsub(' ', '_').upcase
  end
end
