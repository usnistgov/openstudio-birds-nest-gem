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
# Currently uses the last coil of a given type as the only coil of that type. This works for systems with only one heating and cooling coil,
# but homes with more than one system (e.g., room AC units) or with multiple coils that were included accidentally.

def get_hvac_heat_cool(model, runner, user_arguments, idf)

  pri_hvac = runner.getStringArgumentValue('pri_hvac', user_arguments)
  # sec_hvac = runner.getStringArgumentValue('sec_hvac',user_arguments)
  # Define the ductwork type to use for PTHP determination.
  ductwork = runner.getStringArgumentValue('ductwork', user_arguments)

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

  # sec_hvac = 'NULL' #if sec_hvac == 'None'

  hvac_string = pri_hvac.gsub('Com: ', '').gsub('Res: ', '').strip
  # runner.registerInfo("HVAC Type is #{hvac_string}.")
  detail1, detail2, detail3, detail4 = pri_hvac.split('_')
  # runner.registerInfo("HVAC Details are: #{detail1}, #{detail2}, #{detail3}, #{detail4}.")

  # The System Details is provided by the user because the model cannot completely provide that information for all systems.
  # Currently assumes that there is both heating and cooling in the building. Could add options for no AC or no heating.
  # Determine if there is a heat pump object to populate.
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
  case detail2
  when 'CentralAC'
    userCoolingSystemType = 'CENTRAL_AIR_CONDITIONING'
    userCoolingSystemFuel = 'ELECTRICITY'
  when 'RoomAC'
    userCoolingSystemType = 'ROOM_AIR_CONDITIONER'
    userCoolingSystemFuel = 'ELECTRICITY'
  else
    userCoolingSystemType = 'NULL_CST'
    userCoolingSystemFuel = 'NULL'
  end

  # Determine if there is a heating system object to populate.
  case detail3
  when 'Furnace'
    userHeatingSystemType = 'FURNACE'
    case detail4
    when 'Gas'
      userHeatingSystemFuel = 'NATURAL_GAS'
    when 'Oil'
      userHeatingSystemFuel = 'FUEL_OIL'
    when 'Propane'
      userHeatingSystemFuel = 'PROPANE'
    when 'Electric'
      userHeatingSystemFuel = 'ELECTRICITY'
    end
  when 'Boiler'
    userHeatingSystemType = 'BOILER'
    case detail4
    when 'Gas'
      userHeatingSystemFuel = 'NATURAL_GAS'
    when 'Oil'
      userHeatingSystemFuel = 'FUEL_OIL'
    when 'Propane'
      userHeatingSystemFuel = 'PROPANE'
    when 'Electric'
      userHeatingSystemFuel = 'ELECTRICITY'
    end
  when 'Baseboard'
    # TODO: Current code creates two hvac objects. One for central systems (AC/furnace/boiler) and one for zone level systems (e.g., baseboards)
    userHeatingSystemType = 'ELECTRIC_BASEBOARD'
    userHeatingSystemFuel = 'ELECTRICITY'
  when 'NoHeat'
    userHeatingSystemType = 'NULL_HST'
    userHeatingSystemFuel = 'NULL'
  else
    userHeatingSystemType = 'NULL_HST'
    userHeatingSystemFuel = 'NULL'
  end

  # runner.registerInfo("User Heating System = #{detail3}, #{detail4}, #{userHeatingSystemType}, #{userHeatingSystemFuel}.")

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

  # loop through air loops
  airLoops = model.getAirLoopHVACs
  airLoops.each do |airLoop|

    isHeatPump = false
    isTemplateSystem = false
    heating_coil_1_found = false
    heating_coil_2_found = false
    # loop through supply components
    airLoop.supplyComponents.each do |sc|
      # runner.registerInfo("supply component = #{sc}.")
      # runner.registerInfo("supply component methods = #{sc.methods.sort}.")

      # check if this supply component is a system
      if sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
        # get info from unitary heatpump air to air
        uhpata = sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        isHeatPump = true
        isTemplateSystem = true
        # runner.registerInfo("template unitary A2A system found = #{uhpata}.")

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
        heatPumpType = if detail4 == 'Std'
                         'AIR_TO_AIR_STD'
                       else
                         'AIR_TO_AIR_SDHV'
                       end
        heatPumpFuel = if heating_coil_type == 'DX Single Speed'
                         'ELECTRICITY_HPF'
                       else
                         'NULL_HPF'
                       end
        geothermalLoopTransfer = 'NULL'
        geothermalLoopType = 'NULL_GLT'
        backUpType = if backup_coil_type != nil
                       'INTEGRATED'
                     else
                       'NULL_BT'
                     end
        backUpSystemFuel = if backup_coil_type == 'DX Single Speed'
                             'ELECTRICITY'
                           else
                             'NULL'
                           end
        coolingSystemType = 'NULL_CST'
        coolingSystemFuel = 'NULL'
        heatingSystemType = 'NULL_HST'
        heatingSystemFuel = 'NULL'
      end
      if sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
        # get info from unitary heat pump air to air MS
        uhpatams = sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        isHeatPump = true
        isTemplateSystem = true
        # runner.registerInfo("template unitary A2A MS system found = #{uhpatams}.")

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
        heatPumpType = if detail4 == 'Std'
                         'AIR_TO_AIR_STD'
                       else
                         'AIR_TO_AIR_SDHV'
                       end
        heatPumpFuel = if heating_coil_type == 'DX Multi Speed'
                         'ELECTRICITY_HPF'
                       else
                         'NULL_HPF'
                       end
        geothermalLoopTransfer = 'NULL'
        geothermalLoopType = 'NULL_GLT'
        backUpType = if backup_coil_type != nil
                       'INTEGRATED'
                     else
                       'NULL_BT'
                     end
        backUpSystemFuel = if backup_coil_type == 'DX Multi Speed'
                             'ELECTRICITY'
                           else
                             'NULL'
                           end
        coolingSystemType = 'NULL_CST'
        coolingSystemFuel = 'NULL'
        heatingSystemType = 'NULL_HST'
        heatingSystemFuel = 'NULL'
      end
      if sc.to_AirLoopHVACUnitarySystem.is_initialized
        # get info from unitary system
        us = sc.to_AirLoopHVACUnitarySystem.get
        # runner.registerInfo("template unitary system found = #{us}.")
        # runner.registerInfo("unitary system methods = #{us.methods.sort}.")
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
        runner.registerInfo("heating_coil_type = #{heating_coil_type}.")
        runner.registerInfo("backup_coil_type = #{backup_coil_type}.")

        if (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (!heating_coil_type.nil? && heating_coil_type.include?('DX'))
          isHeatPump = true
          heatPumpType = case detail4
                         when 'Std'
                           'AIR_TO_AIR_STD'
                         when 'SDHV'
                           'AIR_TO_AIR_SDHV'
                         else
                           'AIR_TO_AIR_OTHER'
                         end
          heatPumpFuel = 'ELECTRICITY_HPF'
          geothermalLoopTransfer = 'NULL'
          geothermalLoopType = 'NULL_GLT'
          backUpType = if backup_coil_type != nil
                         'INTEGRATED'
                       else
                         'NULL_BT'
                       end
          backUpSystemFuel = 'ELECTRICITY'
          coolingSystemType = 'NULL_CST'
          coolingSystemFuel = 'NULL'
          heatingSystemType = 'NULL_HST'
          heatingSystemFuel = 'NULL'
        elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (!heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'ELECTRICITY')))
          isHeatPump = false
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
        elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (!heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'NATURAL_GAS')))
          isHeatPump = false
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
        elsif !cooling_coil_type.nil? && heating_coil_type.nil?
          isHeatPump = false
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
        elsif cooling_coil_type.nil? && (!heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'NATURAL_GAS')))
          isHeatPump = false
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
        elsif cooling_coil_type.nil? && (!heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'ELECTRICITY')))
          isHeatPump = false
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
        elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('CoilCoolingWater')) && (!heating_coil_type.nil? && heating_coil_type.include?('CoilHeatingWater'))
          isHeatPump = true
          heatPumpType = 'WATER_TO_AIR'
          heatPumpFuel = 'ELECTRICITY_HPF'
          geothermalLoopTransfer = 'CLOSED' # defaulted to closed
          case detail4
          when 'Horizontal'
            geothermalLoopType = 'HORIZONTAL'
          when 'Vertical'
            geothermalLoopType = 'VERTICAL'
          when 'Slinky'
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
          runner.registerError('Unitary HVAC System is not recognized.')
        end
      end
      # TODO: add CentralHeatPumpSystem, water-to-air heat pump templates ?
      # search heat loop for heating coils
      # search cooling loop for cooling coils
      # TODO: more systems to add ? (horizontal geothermal, hot water baseboard?)

      # check for coils directly in the supply component list
      # not sure what to do if there are more than one
      if is_heating_coil(sc)
        if !heating_coil_1_found
          heating_coil_type_1, heating_coil_capacity_1, heating_coil_eff_1, heating_coil_eff_unit_1, heating_coil_fuel_1 = get_heating_coil_info(sc, runner)
          geothermalLoopLength = determineGeothermalLength(sc, runner) if heating_coil_type_1 == 'CoilHeatingWater'
          heating_coil_1_found = true
        else
          heating_coil_type_2, heating_coil_capacity_2, heating_coil_eff_2, heating_coil_eff_unit_2, heating_coil_fuel_2 = get_heating_coil_info(sc, runner)
          geothermalLoopLength = determineGeothermalLength(sc, runner) if heating_coil_type_2 == 'CoilHeatingWater'
          heating_coil_2_found = true
        end
      end
      if is_cooling_coil(sc)
        cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(sc, runner)
      end
    end
    # if not a template system then try to determine the system based on the coils. This is where central ac + baseboards need to be addressed.
    unless isTemplateSystem
      # if two heating coils are found then determine primary vs secondary coil
      if heating_coil_1_found && heating_coil_2_found
        if heating_coil_type_1.include? 'DX'
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
        elsif (heating_coil_fuel_1 == 'NATURAL_GAS') && (heating_coil_fuel_2 != 'NATURAL_GAS')
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
        elsif (heating_coil_fuel_2 == 'NATURAL_GAS') && (heating_coil_fuel_1 != 'NATURAL_GAS')
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

        backup_coil_type = nil
        backup_coil_capacity = nil
        backup_coil_eff = nil
        backup_coil_eff_unit = nil
        backup_coil_fuel = nil
      end

      runner.registerInfo("cooling_coil_type = #{cooling_coil_type}.")
      runner.registerInfo("heating_coil_type = #{heating_coil_type}.")
      runner.registerInfo("backup_coil_type = #{backup_coil_type}.")

      # don't proceed if no heating coil and no cooling coil is found
      if cooling_coil_type.nil? && heating_coil_type.nil?
        runner.registerError('No heating and cooling coils found in an air loop.')
        return
      end
      # check for different combinations of coils.
      # DX heating and cooling coils
      if (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (!heating_coil_type.nil? && heating_coil_type.include?('DX'))
        isHeatPump = true
        heatPumpType = if detail4 == 'Std'
                         'AIR_TO_AIR_STD'
                       else
                         'AIR_TO_AIR_SDHV'
                       end
        heatPumpFuel = 'ELECTRICITY_HPF'
        geothermalLoopTransfer = 'NULL'
        geothermalLoopType = 'NULL_GLT'
        coolingSystemType = 'NULL_CST'
        coolingSystemFuel = 'NULL'
        heatingSystemType = 'NULL_HST'
        heatingSystemFuel = 'NULL'
        # DX cooling coil (central AC) and furnace
      elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (!heating_coil_type.nil? && heating_coil_type.include?('Furnace'))
        isHeatPump = false
        # runner.registerInfo("AC+Furnace found")
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
      elsif cooling_coil_type.nil? && (!heating_coil_type.nil? && heating_coil_type.include?('Furnace'))
        isHeatPump = false
        # runner.registerInfo("No AC + Furnace found")
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
      elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (!heating_coil_type.nil? && heating_coil_type.include?('CoilHeatingWater'))
        isHeatPump = false
        coolingSystemType = 'CENTRAL_AIR_CONDITIONING'
        coolingSystemFuel = 'ELECTRICITY'
        heatingSystemType = 'BOILER'
        # TODO: determine fuel type via boiler:hotwater
        heatingSystemFuel = heating_coil_fuel

        heatPumpType = 'NULL_HPT'
        heatPumpFuel = 'NULL_HPF'
        geothermalLoopTransfer = 'NULL'
        geothermalLoopType = 'NULL_GLT'
        backUpType = 'NULL_BT'
        backUpSystemFuel = 'NULL'
        # no AC and Water heated coil (boiler)
      elsif cooling_coil_type.nil? && (!heating_coil_type.nil? && heating_coil_type.include?('CoilHeatingWater'))
        isHeatPump = false
        coolingSystemType = 'NULL_CST'
        coolingSystemFuel = 'NULL'
        heatingSystemType = 'BOILER'
        # TODO: determine fuel type via boiler:hotwater
        heatingSystemFuel = heating_coil_fuel

        heatPumpType = 'NULL_HPT'
        heatPumpFuel = 'NULL_HPF'
        geothermalLoopTransfer = 'NULL'
        geothermalLoopType = 'NULL_GLT'
        backUpType = 'NULL_BT'
        backUpSystemFuel = 'NULL'
        # DX cooling coil (central AC) and user specified electric baseboard heating
      elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (heating_coil_type.nil? && userHeatingSystemType.include?('ELECTRIC_BASEBOARD'))
        isHeatPump = false
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
      elsif cooling_coil_type.nil? && (heating_coil_type.nil? && userHeatingSystemType.include?('ELECTRIC_BASEBOARD'))
        isHeatPump = false
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
      elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('DX')) && (heating_coil_type.nil? && (!userHeatingSystemType.include? 'ELECTRIC_BASEBOARD'))
        isHeatPump = false
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
      elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('WaterToAir')) && (!heating_coil_type.nil? && heating_coil_type.include?('WaterToAir'))
        isHeatPump = true
        heatPumpType = 'WATER_TO_AIR'
        heatPumpFuel = 'ELECTRICITY_HPF'
        geothermalLoopTransfer = 'CLOSED' # defaulted to closed
        case detail4
        when 'Horizontal'
          geothermalLoopType = 'HORIZONTAL'
        when 'Vertical'
          geothermalLoopType = 'VERTICAL'
        when 'Slinky'
          geothermalLoopType = 'SLINKY'
        end
        backUpType = 'INTEGRATED'
        backUpSystemFuel = 'ELECTRICITY'

        coolingSystemType = 'NULL_CST'
        coolingSystemFuel = 'NULL'
        heatingSystemType = 'NULL_HST'
        heatingSystemFuel = 'NULL'
        # Water heating and water cooling coils (water-to-air heat pump with geothermal) - ignoring district heating/cooling in houses
      elsif (!cooling_coil_type.nil? && cooling_coil_type.include?('CoilCoolingWater')) && (!heating_coil_type.nil? && heating_coil_type.include?('CoilHeatingWater'))
        isHeatPump = true
        heatPumpType = 'WATER_TO_AIR'
        heatPumpFuel = 'ELECTRICITY_HPF'
        geothermalLoopTransfer = 'CLOSED' # defaulted to closed
        case detail4
        when 'Horizontal'
          geothermalLoopType = 'HORIZONTAL'
        when 'Vertical'
          geothermalLoopType = 'VERTICAL'
        when 'Slinky'
          geothermalLoopType = 'SLINKY'
        end
        backUpType = 'INTEGRATED'
        backUpSystemFuel = 'ELECTRICITY'

        coolingSystemType = 'NULL_CST'
        coolingSystemFuel = 'NULL'
        heatingSystemType = 'NULL_HST'
        heatingSystemFuel = 'NULL'
      end
    end

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
    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)
    if userGeothermalLoopTransfer != geothermalLoopTransfer
      runner.registerError("User geothermal loop transfer does not match model. User: #{userGeothermalLoopTransfer}, Model: #{geothermalLoopTransfer}")
    end
    if userGeothermalLoopType != geothermalLoopType
      runner.registerError("User geothermal loop type does not match model. User: #{userGeothermalLoopType}, Model: #{geothermalLoopType}")
    end

    if isHeatPump
      heatPumps << if heatPumpType != 'NULL_HPT'
                     {
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
                     {}
                   end

    else
      coolingSystems << if (coolingSystemType != 'NULL_CST') && (cooling_coil_capacity != nil)
                          {
                            'coolingSystemType' => coolingSystemType,
                            'coolingSystemFuel' => coolingSystemFuel,
                            'coolingCapacity' => cooling_coil_capacity,
                            'annualCoolingEfficiency' => {
                              'value' => cooling_coil_eff,
                              'unit' => cooling_coil_eff_unit
                            }
                          }
                        else
                          {}
                        end
      heatingSystems << if (heatingSystemType != 'NULL_HST') && (heating_coil_capacity != nil)
                          {
                            'heatingSystemType' => heatingSystemType,
                            'heatingSystemFuel' => heatingSystemFuel,
                            'heatingCapacity' => heating_coil_capacity,
                            'annualHeatingEfficiency' => {
                              'value' => heating_coil_eff,
                              'unit' => 'PERCENT' # heating_coil_eff_unit is null
                            }
                          }
                        else
                          {}
                        end
    end

    hvac_sys << {
      'heatPumps' => heatPumps,
      'coolingSystems' => coolingSystems,
      'heatingSystems' => heatingSystems
    }

  end
  # runner.registerInfo("All Heating and Cooling System have been populated: #{hvac_sys}.")
  @heatingSystemType = heatingSystemType
  @heatingSystemFuel = heatingSystemFuel
  # runner.registerInfo("Heating System Fuel: #{heatingSystemFuel}.")
  @heatPumpType = heatPumpType
  zone_unit_sys = []
  zone_unit_sys = get_zone_units(model, runner, idf, userHeatingSystemType, userHeatingSystemFuel, userHeatPumpType, ductwork)
  # runner.registerInfo("Room Heating and Cooling Units populated: #{zone_unit_sys}.")
  hvac_sys << zone_unit_sys if zone_unit_sys != []

  hvac_sys
end

# find the geothermal length given a coil which is either CoilCoolingWater or CoilHeatingWater or WaterToAir in coil/template
def determineGeothermalLength(coil, runner)

  geothermalLength = nil

  if coil.to_CoilHeatingWater.is_initialized
    chw = coil.to_CoilHeatingWater.get
    # runner.registerInfo("CoilHeatingWater found = #{chw}.")

    # get the plant loop used by this coil
    if chw.plantLoop.is_initialized
      plantLoop = chw.plantLoop.get
    else
      runner.registerError("For CoilHeatingWater #{coil.name} plantLoop is not available.")
    end

    # look through the supply components for the heat exchanger
    plantLoop.supplyComponents.each do |sc|
      # runner.registerInfo("supplyComponent = #{sc}.")
      # runner.registerInfo("supplyComponent methods = #{sc.methods.sort}.")

      if sc.to_GroundHeatExchangerVertical.is_initialized
        ghev = sc.to_GroundHeatExchangerVertical.get
        # runner.registerInfo("GroundHeatExchangerVertical = #{ghev}.")
        # runner.registerInfo("GroundHeatExchangerVertical methods = #{ghev.methods.sort}.")

        boreHoleLength = nil
        if ghev.boreHoleLength.is_initialized
          boreHoleLength = ghev.boreHoleLength.get
        else
          runner.registerError('No bore hole length for this heat exchanger.')
        end
        numberofBoreHoles = nil
        if ghev.numberofBoreHoles.is_initialized
          numberofBoreHoles = ghev.numberofBoreHoles.get
        else
          runner.registerError('No number of bore holes for this heat exchanger.')
        end
        # runner.registerInfo("boreHoleLength = #{ghev.boreHoleLength.get}.")
        # runner.registerInfo("numberofBoreHoles = #{ghev.numberofBoreHoles.get}.")
        geothermalLength = boreHoleLength * numberofBoreHoles
        # runner.registerInfo("geothermalLength = #{geothermalLength}.")
      elsif sc.to_GroundHeatExchangerHorizontalTrench.is_initialized
        gheht = sc.to_GroundHeatExchangerHorizontalTrench.get
        # runner.registerInfo("GroundHeatExchangerHorizontalTrench = #{gheht}.")
        # runner.registerInfo("GroundHeatExchangerHorizontalTrench methods = #{gheht.methods.sort}.")

        trenchLength = nil
        if ghev.trenchLengthinPipeAxialDirection.is_initialized
          trenchLength = ghev.trenchLengthinPipeAxialDirection.get
        else
          runner.registerError('No trench length for this heat exchanger.')
        end
        numberofTrenches = nil
        if ghev.numberofTrenches.is_initialized
          numberofTrenches = ghev.numberofTrenches.get
        else
          runner.registerError('No number of trenches for this heat exchanger.')
        end
        # runner.registerInfo("trenchLength = #{trenchLength}.")
        # runner.registerInfo("numberofTrenches = #{numberofTrenches}.")
        geothermalLength = trenchLength * numberofTrenches
        # runner.registerInfo("geothermalLength = #{geothermalLength}.")
      end
    end
  elsif coil.to_CoilCoolingWater.is_initialized
    ccw = coil.to_CoilCoolingWater.get
    # runner.registerInfo("CoilCoolingWater found = #{ccw}.")
    # runner.registerInfo("CoilCoolingWater methods = #{ccw.methods.sort}.")

    # get the plant loop used by this coil
    if ccw.plantLoop.is_initialized
      plantLoop = ccw.plantLoop.get
    else
      runner.registerError("For CoilCoolingWater #{coil.name} plantLoop is not available.")
    end

    # look through the supply components for the heat exchanger
    plantLoop.supplyComponents.each do |sc|
      # runner.registerInfo("supplyComponent = #{sc}.")
      # runner.registerInfo("supplyComponent methods = #{sc.methods.sort}.")

      if sc.to_GroundHeatExchangerVertical.is_initialized
        ghev = sc.to_GroundHeatExchangerVertical.get
        # runner.registerInfo("GroundHeatExchangerVertical = #{ghev}.")
        # runner.registerInfo("GroundHeatExchangerVertical methods = #{ghev.methods.sort}.")

        boreHoleLength = nil
        if ghev.boreHoleLength.is_initialized
          boreHoleLength = ghev.boreHoleLength.get
        else
          runner.registerError('No bore hole length for this heat exchanger.')
        end
        numberofBoreHoles = nil
        if ghev.numberofBoreHoles.is_initialized
          numberofBoreHoles = ghev.numberofBoreHoles.get
        else
          runner.registerError('No number of bore holes for this heat exchanger.')
        end
        # runner.registerInfo("boreHoleLength = #{ghev.boreHoleLength.get}.")
        # runner.registerInfo("numberofBoreHoles = #{ghev.numberofBoreHoles.get}.")
        geothermalLength = boreHoleLength * numberofBoreHoles
        # runner.registerInfo("geothermalLength = #{geothermalLength}.")
      elsif sc.to_GroundHeatExchangerHorizontalTrench.is_initialized
        gheht = sc.to_GroundHeatExchangerHorizontalTrench.get
        # runner.registerInfo("GroundHeatExchangerHorizontalTrench = #{gheht}.")
        # runner.registerInfo("GroundHeatExchangerHorizontalTrench methods = #{gheht.methods.sort}.")

        trenchLength = nil
        if ghev.trenchLengthinPipeAxialDirection.is_initialized
          trenchLength = ghev.trenchLengthinPipeAxialDirection.get
        else
          runner.registerError('No trench length for this heat exchanger.')
        end
        numberofTrenches = nil
        if ghev.numberofTrenches.is_initialized
          numberofTrenches = ghev.numberofTrenches.get
        else
          runner.registerError('No number of trenches for this heat exchanger.')
        end
        # runner.registerInfo("trenchLength = #{trenchLength}.")
        # runner.registerInfo("numberofTrenches = #{numberofTrenches}.")
        geothermalLength = trenchLength * numberofTrenches
        # runner.registerInfo("geothermalLength = #{geothermalLength}.")
      end
    end
  else
    runner.registerError('Not given a water coil when one was expected.')
  end

  geothermalLength
end

def pthp_type(ductwork)
  if ductwork == 'None'
    'MINI_SPLIT_NONDUCTED'
  else
    'MINI_SPLIT_DUCTED'
  end
end

def check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)
  if userHeatingSystemType != heatingSystemType
    runner.registerError("User heating system type does not match model. User: #{userHeatingSystemType}, Model: #{heatingSystemType}")
  end
  if userHeatingSystemFuel != heatingSystemFuel
    runner.registerError("User heating system fuel type does not match model. User: #{userHeatingSystemFuel}, Model: #{heatingSystemFuel}")
  end
end

# Capture the zone level equipment. ZoneHVAC equipment and Coils included as zone equipment.
def get_zone_units(model, runner, idf, userHeatingSystemType, userHeatingSystemFuel, userHeatPumpType, ductwork)
  heatPumps = []
  coolingSystems = []
  heatingSystems = []
  zone_unit_sys = []
  ptac_hvac_systems = []

  # runner.registerInfo("model methods = #{model.methods.sort}.")

  # PTHP could be used to represent mini-split systems. Populate heat_pump_sys.
  model.getZoneHVACPackagedTerminalHeatPumps.each do |pTHP|
    cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(pTHP.coolingCoil, runner)

    heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(pTHP.heatingCoil, runner)

    heatPumps << {
      'heatPumpType' => pthp_type(ductwork),
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
      'geothermalLoopType' => 'NULL_GLT',
      'backupType' => 'NULL_BT',
      'backUpSystemFuel' => 'ELECTRICITY',
      'backUpAfue' => nil,
      'backUpHeatingCapacity' => nil
    }
  end

  # PTAC systems include a heating coil - treated as a small furnace in BIRDS NEST.
  model.getZoneHVACPackagedTerminalAirConditioners.each do |pTAC|
    # runner.registerInfo("PTAC loop has been entered.")
    cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(pTAC.coolingCoil, runner)
    # runner.registerInfo("Found Cooling Info: #{cooling_coil_type}, #{cooling_coil_capacity},#{cooling_coil_eff}, and #{cooling_coil_eff_unit}.")

    coolingSystems << {
      'coolingSystemType' => 'ROOM_AIR_CONDITIONER',
      'coolingSystemFuel' => 'ELECTRICITY',
      'coolingCapacity' => cooling_coil_capacity,
      'annualCoolingEfficiency' => {
        'value' => cooling_coil_eff,
        'unit' => cooling_coil_eff_unit
      }
    }

    heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(pTAC.heatingCoil, runner)
    # runner.registerInfo("Found Heating Info: #{heating_coil_type}, #{userHeatingSystemFuel}, #{heating_coil_capacity},#{heating_coil_eff}, and #{heating_coil_eff_unit}.")

    if !heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'ELECTRICITY'))
      # runner.registerInfo("Room AC+Furnace Electric found")
      heatingSystemType = 'FURNACE'
      heatingSystemFuel = 'ELECTRICITY'
    elsif !heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'NATURAL_GAS'))
      # runner.registerInfo("Room AC+Furnace Gas found")
      heatingSystemType = 'FURNACE'
      heatingSystemFuel = 'NATURAL_GAS'
    else
      runner.registerError('pTAC unrecognized.')
    end

    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)

    heatingSystems << {
      'heatingSystemType' => heatingSystemType,
      'heatingSystemFuel' => heatingSystemFuel,
      'heatingCapacity' => heating_coil_capacity,
      'annualHeatingEfficiency' => {
        'value' => heating_coil_eff,
        'unit' => 'PERCENT'
      }
    }
  end
  # check IDF for ZoneHVAC:WindowAirConditioner - window AC units do not have a heating coil; this will need to be included as a separate unit.
  # model.getZoneHVACPackagedTerminalAirConditioners
  windowAirConditioners = idf.getObjectsByType('ZoneHVAC:WindowAirConditioner'.to_IddObjectType)
  windowAirConditioners.each do |windowAirConditioner|
    coolingCoilName = windowAirConditioner.getString(11).get
    coolingCoilType = windowAirConditioner.getString(10).get
    coolingCoil = idf.getObjectByTypeAndName(coolingCoilType, coolingCoilName)
    case coolingCoilType
    when 'Coil:Cooling:DX:SingleSpeed'
      cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit = get_coolingDXSingleSpeed_info_idf(coil, runner)
    when 'Coil:Cooling:DX:VariableSpeed'

    when 'CoilSystem:Cooling:DX:HeatExchangerAssisted'

    end
    # runner.registerInfo("Window AC found")

    coolingSystems << {
      'coolingSystemType' => 'ROOM_AIR_CONDITIONER',
      'coolingSystemFuel' => 'ELECTRICITY',
      'coolingCapacity' => cooling_coil_capacity,
      'annualCoolingEfficiency' => {
        'value' => cooling_coil_eff,
        'unit' => cooling_coil_eff_unit
      }
    }
  end

  model.getZoneHVACBaseboardConvectiveElectrics.each do |bCE|
    # runner.registerInfo("ZoneHVACBaseboardConvectiveElectric = #{bCE}.")
    # runner.registerInfo("ZoneHVACBaseboardConvectiveElectric methods = #{bCE.methods.sort}.")

    capacity_w = nil
    if bCE.isNominalCapacityAutosized
      if bCE.autosizedNominalCapacity.is_initialized
        capacity_w = bCE.autosizedNominalCapacity.get
      else
        runner.registerError('ZoneHVACBaseboardConvectiveElectric cannot get autosized capacity.')
      end
    else
      if bCE.nominalCapacity.is_initialized
        capacity_w = bCE.nominalCapacity.get
      else
        runner.registerError('ZoneHVACBaseboardConvectiveElectric cannot get capacity.')
      end
    end
    heatingSystemType = 'ELECTRIC_BASEBOARD'
    heatingSystemFuel = 'ELECTRICITY'
    heating_coil_eff = bCE.efficiency

    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)

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
    # get the plant loop used by this
    if bCW.plantLoop.is_initialized
      plantLoop = bCW.plantLoop.get
    else
      runner.registerError('For ZoneHVACBaseboardConvectiveWater plantLoop is not available.')
    end

    capacity_w, heatingSystemFuel, heating_coil_eff, heating_coil_eff_unit = getBoilerInfo(plantLoop, runner)
    heatingSystemType = 'BOILER'

    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)

    heatingSystems << {
      'heatingSystemType' => heatingSystemType,
      'heatingSystemFuel' => heatingSystemFuel,
      'heatingCapacity' => capacity_w,
      'annualHeatingEfficiency' => {
        'value' => heating_coil_eff,
        'unit' => heating_coil_eff_unit
      }
    }
  end

  model.getZoneHVACBaseboardRadiantConvectiveElectrics.each do |bRCE|
    capacity_w = nil
    if bRCE.isHeatingDesignCapacityAutosized
      if bRCE.autosizedHeatingDesignCapacity.is_initialized
        capacity_w = bRCE.autosizedHeatingDesignCapacity.get
      else
        runner.registerError('ZoneHVACBaseboardRadiantConvectiveElectric cannot get autosized capacity.')
      end
    else
      if bRCE.heatingDesignCapacity.is_initialized
        capacity_w = bRCE.heatingDesignCapacity.get
      else
        runner.registerError('ZoneHVACBaseboardRadiantConvectiveElectric cannot get capacity.')
      end
    end
    heatingSystemType = 'ELECTRIC_BASEBOARD'
    heatingSystemFuel = 'ELECTRICITY'
    heating_coil_eff = bRCE.efficiency

    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)

    heatingSystems << {
      'heatingSystemType' => heatingSystemType,
      'heatingSystemFuel' => heatingSystemFuel,
      'heatingCapacity' => capacity_w.round(0),
      'annualHeatingEfficiency' => {
        'value' => heating_coil_eff,
        'unit' => 'PERCENT'
      }
    }
  end

  model.getZoneHVACBaseboardRadiantConvectiveWaters.each do |bRCW|
    # get the plant loop used by this
    if bRCW.plantLoop.is_initialized
      plantLoop = bRCW.plantLoop.get
    else
      runner.registerError('For ZoneHVACBaseboardConvectiveWater plantLoop is not available.')
    end

    capacity_w, heatingSystemFuel, heating_coil_eff, heating_coil_eff_unit = getBoilerInfo(plantLoop, runner)
    heatingSystemType = 'BOILER'

    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)

    heatingSystems << {
      'heatingSystemType' => heatingSystemType,
      'heatingSystemFuel' => heatingSystemFuel,
      'heatingCapacity' => capacity_w,
      'annualHeatingEfficiency' => {
        'value' => heating_coil_eff,
        'unit' => heating_coil_eff_unit
      }
    }
  end

  model.getZoneHVACUnitHeaters.each do |uH|
    heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel = get_heating_coil_info(uH.heatingCoil, runner)

    if !heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'ELECTRICITY'))
      # runner.registerInfo("ZoneHVAC Furnace Electric found")
      heatingSystemType = 'FURNACE'
      heatingSystemFuel = 'ELECTRICITY'
    elsif !heating_coil_type.nil? && (heating_coil_type.include?('Furnace') && (heating_coil_fuel == 'NATURAL_GAS'))
      # runner.registerInfo("ZoneHVAC Furnace Gas found")
      heatingSystemType = 'FURNACE'
      heatingSystemFuel = 'NATURAL_GAS'
    else
      runner.registerError('ZoneHVAC Unit Heater unrecognized.')
    end

    check_heating_system_error(heatingSystemFuel, heatingSystemType, runner, userHeatingSystemFuel, userHeatingSystemType)

    heatingSystems << {
      'heatingSystemType' => heatingSystemType,
      'heatingSystemFuel' => heatingSystemFuel,
      'heatingCapacity' => heating_coil_capacity,
      'annualHeatingEfficiency' => {
        'value' => heating_coil_eff,
        'unit' => heating_coil_eff_unit
      }
    }
  end

  if heatPumps != [] || coolingSystems != [] || heatingSystems != []
    {
      'heatPumps' => heatPumps,
      'coolingSystems' => coolingSystems,
      'heatingSystems' => heatingSystems
    }
  else
    []
  end
end

def get_coolingDXSingleSpeed_info_idf(coil, runner)

  # Get the capacity
  capacity_w = coil.getDouble(0) # Gross Rated Total Cooling Capacity

  # Get the COP
  cop = coil.getDouble(2) # Gross Rated Cooling COP

  # runner.registerInfo("Coil COP = #{cop} for DX Single Speed cooling coil has been found.")

  cooling_coil_type = 'DXSingleSpeed'
  cooling_coil_capacity = capacity_w.round(0)
  cooling_coil_eff = cop
  cooling_coil_eff_unit = 'COP'

  # runner.registerInfo("DX Single Speed Cooling Coil has been found with COP = #{cop}.")

  return cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit

end

def get_cooling_coil_info(coil, runner)

  # runner.registerInfo("coil = #{coil}.")
  # runner.registerInfo("coil methods = #{coil.methods.sort}.")

  cooling_coil_type = nil
  cooling_coil_capacity = nil
  cooling_coil_eff = nil
  cooling_coil_eff_unit = nil
  cooling_coil_fuel = nil

  if coil.to_CoilCoolingDXSingleSpeed.is_initialized
    ccdxss = coil.to_CoilCoolingDXSingleSpeed.get
    # runner.registerInfo("CoilCoolingDXSingleSpeed found = #{ccdxss}.")

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

    # runner.registerInfo("Coil COP = #{cop} for DX Single Speed cooling coil has been found.")

    cooling_coil_type = 'DXSingleSpeed'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = cop
    cooling_coil_eff_unit = 'COP'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("DX Single Speed Cooling Coil has been found with COP = #{cop}.")
  end
  if coil.to_CoilCoolingDXTwoSpeed.is_initialized
    ccdxts = coil.to_CoilCoolingDXTwoSpeed.get
    # runner.registerInfo("CoilCoolingDXTwoSpeed found = #{ccdxts}.")
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

    # runner.registerInfo("Coil COP = #{cop} for DX Two Speed cooling coil have been found.")

    cooling_coil_type = 'DXTwoSpeed'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = cop
    cooling_coil_eff_unit = 'COP'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("DX Two Speed Cooling Coil has been found with high speed COP = #{cop}.")
  end
  if coil.to_ChillerElectricEIR.is_initialized
    ceeir = coil.to_ChillerElectricEIR.get
    # runner.registerInfo("CoilCoolingDXSingleSpeed found = #{ceeir}.")

    # Get the capacity
    capacity_w = nil
    if ceeir.referenceCapacity.is_initialized
      capacity_w = ceeir.referenceCapacity.get
    elsif ceeir.autosizedReferenceCapacity.is_initialized
      capacity_w = ceeir.autosizedReferenceCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{ceeir.name} capacity is not available.")
    end

    # Get the COP
    cop = ceeir.referenceCOP

    # runner.registerInfo("Coil COP = #{cop} for Chiller have been found.")

    cooling_coil_type = 'Chiller'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = cop
    cooling_coil_eff_unit = 'COP'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("Chiller Coil has been found with high speed COP = #{cop}. BIRDS NEST cannot currently handle chiller systems")
  end
  if coil.to_CoilCoolingDXMultiSpeed.is_initialized
    ccdxms = coil.to_CoilCoolingDXMultiSpeed.get
    # runner.registerInfo("CoilCoolingDXMultiSpeed found = #{ccdxms}.")

  end
  if coil.to_CoilCoolingDXMultiSpeedStageData.is_initialized
    ccdxmssd = coil.to_CoilCoolingDXMultiSpeedStageData.get
    # runner.registerInfo("CoilCoolingDXMultiSpeedStageData found = #{ccdxmssd}.")

  end
  if coil.to_CoilCoolingDXTwoStageWithHumidityControlMode.is_initialized
    ccdxtswhcm = coil.to_CoilCoolingDXTwoStageWithHumidityControlMode.get
    # runner.registerInfo("CoilCoolingDXTwoStageWithHumidityControlMode found = #{ccdxtswhcm}.")

  end
  if coil.to_CoilCoolingDXVariableRefrigerantFlow.is_initialized
    ccdxvrf = coil.to_CoilCoolingDXVariableRefrigerantFlow.get
    # runner.registerInfo("CoilCoolingDXVariableRefrigerantFlow found = #{ccdxvrf}.")

    # Get the capacity
    capacity_w = nil
    if ccdxvrf.ratedTotalCoolingCapacity.is_initialized
      capacity_w = ccdxvrf.ratedTotalCoolingCapacity.get
    elsif ccdxvrf.autosizedRatedTotalCoolingCapacity.is_initialized
      capacity_w = ccdxvrf.autosizedRatedTotalCoolingCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXVariableRefrigerantFlow', "For #{ccdxvrf.name} capacity is not available.")
    end

    cooling_coil_type = 'CoilCoolingDXVariableRefrigerantFlow'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = 0
    cooling_coil_eff_unit = 'NULL'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("CoilCoolingDXVariableRefrigerantFlow Coil has been found")
  end
  if coil.to_CoilCoolingDXVariableSpeed.is_initialized
    ccdxvs = coil.to_CoilCoolingDXVariableSpeed.get
    # runner.registerInfo("CoilCoolingDXVariableSpeed found = #{ccdxvs}.")

  end
  if coil.to_CoilCoolingDXVariableSpeedSpeedData.is_initialized
    ccdxvssd = coil.to_CoilCoolingDXVariableSpeedSpeedData.get
    # runner.registerInfo("CoilCoolingDXVariableSpeedSpeedData found = #{ccdxvssd}.")

  end
  if coil.to_CoilCoolingWater.is_initialized
    ccw = coil.to_CoilCoolingWater.get
    # runner.registerInfo("CoilCoolingWater found = #{ccw}.")
    # runner.registerInfo("CoilCoolingWater methods = #{ccw.methods.sort}.")

    # Get the capacity
    capacity_w = 999
    # if ccw.ratedTotalCoolingCapacity.is_initialized
    #	capacity_w = ccw.ratedTotalCoolingCapacity.get
    # else
    #	OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.CoilCoolingWater", "For #{ccw.name} capacity is not available.")
    # end

    cooling_coil_type = 'CoilCoolingWater'
    cooling_coil_capacity = capacity_w #.round(0)
    cooling_coil_eff = 9
    cooling_coil_eff_unit = 'COP'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("CoilCoolingWater Coil has been found")

  end
  if coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
    ccwtahpef = coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
    # runner.registerInfo("CoilCoolingWaterToAirHeatPumpEquationFit found = #{ccwtahpef}.")

    # Get the capacity
    capacity_w = nil
    if ccwtahpef.ratedTotalCoolingCapacity.is_initialized
      capacity_w = ccwtahpef.ratedTotalCoolingCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingWaterToAirHeatPumpEquationFit', "For #{ccwtahpef.name} capacity is not available.")
    end

    cooling_coil_type = 'CoilCoolingWaterToAirHeatPumpEquationFit'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = 0
    cooling_coil_eff_unit = 'NULL'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("CoilCoolingWaterToAirHeatPumpEquationFit Coil has been found")
  end
  if coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized
    ccwtahpvsef = coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.get
    # runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit found = #{ccwtahpvsef}.")

    # Get the capacity
    capacity_w = nil
    if ccwtahpvsef.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
      capacity_w = ccwtahpvsef.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
    elsif ccwtahpvsef.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
      capacity_w = ccwtahpvsef.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit', "For #{ccwtahpvsef.name} capacity is not available.")
    end

    cooling_coil_type = 'CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = 0
    cooling_coil_eff_unit = 'NULL'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit Coil has been found")
  end
  if coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
    ccwtahpvsefsd = coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.get
    # runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData found = #{ccwtahpvsefsd}.")

    # Get the capacity
    capacity_w = nil
    if ccwtahpvsefsd.referenceUnitGrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = ccwtahpvsefsd.referenceUnitGrossRatedTotalCoolingCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData', "For #{ccwtahpvsefsd.name} capacity is not available.")
    end

    cooling_coil_type = 'CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = 0
    cooling_coil_eff_unit = 'NULL'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData Coil has been found")
  end
  if coil.to_CoilPerformanceDXCooling.is_initialized
    cpdxc = coil.to_CoilPerformanceDXCooling.get
    # runner.registerInfo("CoilPerformanceDXCooling found = #{cpdxc}.")

    # Get the capacity
    capacity_w = nil
    if cpdxc.grossRatedTotalCoolingCapacity.is_initialized
      capacity_w = cpdxc.grossRatedTotalCoolingCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilPerformanceDXCooling', "For #{cpdxc.name} capacity is not available.")
    end

    cooling_coil_type = 'CoilPerformanceDXCooling'
    cooling_coil_capacity = capacity_w.round(0)
    cooling_coil_eff = 0
    cooling_coil_eff_unit = 'NULL'
    cooling_coil_fuel = 'ELECTRICITY'

    # runner.registerInfo("CoilPerformanceDXCooling Coil has been found")
  end
  if coil.to_CoilSystemCoolingDXHeatExchangerAssisted.is_initialized
    cscdxhea = coil.to_CoilSystemCoolingDXHeatExchangerAssisted.get
    # runner.registerInfo("CoilSystemCoolingDXHeatExchangerAssisted found = #{cscdxhea}.")

    cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel = get_cooling_coil_info(cscdxhea.coolingCoil, runner)
  end

  return cooling_coil_type, cooling_coil_capacity, cooling_coil_eff, cooling_coil_eff_unit, cooling_coil_fuel

end

def is_cooling_coil(coil)
  coil.to_CoilCoolingDXSingleSpeed.is_initialized ||
    coil.to_CoilCoolingDXTwoSpeed.is_initialized ||
    coil.to_ChillerElectricEIR.is_initialized ||
    coil.to_CoilCoolingDXMultiSpeed.is_initialized ||
    coil.to_CoilCoolingDXMultiSpeedStageData.is_initialized ||
    coil.to_CoilCoolingDXTwoStageWithHumidityControlMode.is_initialized ||
    coil.to_CoilCoolingDXVariableRefrigerantFlow.is_initialized ||
    coil.to_CoilCoolingDXVariableSpeed.is_initialized ||
    coil.to_CoilCoolingDXVariableSpeedSpeedData.is_initialized ||
    coil.to_CoilCoolingWater.is_initialized ||
    coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized ||
    coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized ||
    coil.to_CoilCoolingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized ||
    coil.to_CoilPerformanceDXCooling.is_initialized ||
    coil.to_CoilSystemCoolingDXHeatExchangerAssisted.is_initialized
end

def get_heating_coil_info(coil, runner)
  heating_coil_type = nil
  heating_coil_capacity = nil
  heating_coil_eff = nil
  heating_coil_eff_unit = nil
  heating_coil_fuel = nil

  if coil.to_BoilerHotWater.is_initialized
    bhw = coil.to_BoilerHotWater.get
    # runner.registerInfo("BoilerHotWater found = #{bhw}.")
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

    # runner.registerInfo("Coil efficiency = #{eff} for Boiler has been found.")

    heating_coil_type = 'Boiler'
    heating_coil_capacity = capacity_w.round(0)
    heating_coil_eff = eff
    heating_coil_eff_unit = 'PERCENT'
    boiler_fuel_type = bhw.fuelType
    heating_coil_fuel = if boiler_fuel_type == 'electric'
                          'ELECTRICITY'
                        else
                          'NULL'
                        end
  end
  if coil.to_CoilHeatingDXSingleSpeed.is_initialized
    chdxss = coil.to_CoilHeatingDXSingleSpeed.get
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

    heating_coil_type = 'DX Single Speed'
    heating_coil_fuel = 'ELECTRICITY'
    heating_coil_capacity = capacity_w.round(0)
    heating_coil_eff = cop
    heating_coil_eff_unit = 'COP'
  end
  if coil.to_CoilHeatingGas.is_initialized
    chg = coil.to_CoilHeatingGas.get
    # Get the capacity
    capacity_w = nil

    if chg.nominalCapacity.is_initialized
      capacity_w = chg.nominalCapacity.get
    elsif chg.autosizedNominalCapacity.is_initialized
      capacity_w = chg.autosizedNominalCapacity.get
    else
      runner.registerError("For #{coil.name} capacity is not available.")
    end

    # Get the efficiency
    eff = chg.gasBurnerEfficiency

    heating_coil_type = 'Furnace'
    heating_coil_fuel = 'NATURAL_GAS'
    heating_coil_capacity = capacity_w.round(0)
    heating_coil_eff = eff
    heating_coil_eff_unit = 'PERCENT'
  end
  if coil.to_CoilHeatingElectric.is_initialized
    # Skip reheat coils in VAV terminals; ignore this concern for now because we are only focused on residential
    # next unless coil.airLoopHVAC.is_initialized || coil.containingZoneHVACComponent.is_initialized ***Commented out by Josh because it was skipping the back-up coil***
    che = coil.to_CoilHeatingElectric.get
    # runner.registerInfo("CoilHeatingElectric found = #{che}.")
    # Get the capacity
    capacity_w = nil
    if che.nominalCapacity.is_initialized
      capacity_w = che.nominalCapacity.get
    elsif che.autosizedNominalCapacity.is_initialized
      capacity_w = che.autosizedNominalCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{che.name} capacity is not available.")
    end

    # Get the efficiency
    eff = che.efficiency

    # runner.registerInfo("Coil efficiency = #{eff} for electric furnace (back-up?) have been found.")

    heating_coil_type = 'Furnace'
    heating_coil_fuel = 'ELECTRICITY'
    heating_coil_capacity = capacity_w.round(0)
    heating_coil_eff = eff
    # runner.registerInfo("Electric furnace coil is the primary coil.")

    # runner.registerInfo("Electric Furnace Coil has been found with Efficiency = #{eff}.")
  end
  if coil.to_ZoneHVACBaseboardConvectiveElectric.is_initialized
    zhbce = coil.to_ZoneHVACBaseboardConvectiveElectric.get
    # runner.registerInfo("ZoneHVACBaseboardConvectiveElectric found = #{zhbce}.")
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

    # runner.registerInfo("Coil efficiency = #{eff} for electric resistance baseboard have been found.")
    heating_coil_type = 'Baseboard'
    heating_coil_fuel = 'ELECTRICITY'
    heating_coil_capacity = capacity_w.round(0)
    heating_coil_eff = eff
    heating_coil_eff_unit = 'PERCENT'

    # runner.registerInfo("Electric Baseboards Coil has been found with Efficiency = #{eff}.")
  end
  if coil.to_CoilHeatingDXMultiSpeed.is_initialized
    chdxms = coil.to_CoilHeatingDXMultiSpeed.get
  end
  if coil.to_CoilHeatingDXMultiSpeedStageData.is_initialized
    chdxmssd = coil.to_CoilHeatingDXMultiSpeedStageData.get
  end

  if coil.to_CoilHeatingDXVariableRefrigerantFlow.is_initialized
    chdxvrf = coil.to_CoilHeatingDXVariableRefrigerantFlow.get
  end
  if coil.to_CoilHeatingDXVariableSpeed.is_initialized
    chdxvs = coil.to_CoilHeatingDXVariableSpeed.get
  end
  if coil.to_CoilHeatingDXVariableSpeedSpeedData.is_initialized
    chdxvssd = coil.to_CoilHeatingDXVariableSpeedSpeedData.get
  end
  if coil.to_CoilHeatingGasMultiStage.is_initialized
    chgms = coil.to_CoilHeatingGasMultiStage.get
  end
  if coil.to_CoilHeatingGasMultiStageStageData.is_initialized
    chgmssd = coil.to_CoilHeatingGasMultiStageStageData.get
  end
  if coil.to_CoilHeatingWater.is_initialized
    chw = coil.to_CoilHeatingWater.get

    # Get the capacity
    capacity_w = nil
    if chw.ratedCapacity.is_initialized
      capacity_w = chw.ratedCapacity.get
    elsif !chw.autosizeRatedCapacity.nil? && chw.autosizeRatedCapacity.is_initialized
      capacity_w = chw.autosizeRatedCapacity.get
    else
      runner.registerError("For heating water coil named: #{coil.name} capacity is not available.")
    end

    # get the plant loop used by this coil
    if chw.plantLoop.is_initialized
      plantLoop = chw.plantLoop.get
    else
      runner.registerError("For CoilHeatingWater #{coil.name} plantLoop is not available.")
    end

    plantLoop.supplyComponents.each do |sc|
      if sc.to_BoilerHotWater.is_initialized
        capacity_w, heating_coil_fuel, heating_coil_eff, heating_coil_eff_unit = getBoilerInfo(plantLoop, runner)
        heating_coil_type = 'CoilHeatingWater'
      elsif sc.to_GroundHeatExchangerVertical.is_initialized
        ghev = sc.to_GroundHeatExchangerVertical.get
        ghev_name = nil
        if ghev.name.is_initialized
          ghev_name = ghev.name.get
        else
          runner.registerError('No heat exchanger name found.')
        end
        capacity_w = 9999
        heating_coil_fuel = 'ELECTRICITY'
        heating_coil_eff = 9
        heating_coil_eff_unit = 'COP'
        heating_coil_type = 'CoilHeatingWater'
      elsif sc.to_GroundHeatExchangerHorizontalTrench.is_initialized
        ghev = sc.to_GroundHeatExchangerHorizontalTrench.get
        ghev_name = nil
        if ghev.name.is_initialized
          ghev_name = ghev.name.get
        else
          runner.registerError('No heat exchanger name found.')
        end
        capacity_w = 9999
        heating_coil_fuel = 'ELECTRICITY'
        heating_coil_eff = 9
        heating_coil_eff_unit = 'COP'
        heating_coil_type = 'CoilHeatingWater'
      end
    end
    heating_coil_capacity = capacity_w.round(0)
  end
  if coil.to_CoilHeatingWaterBaseboard.is_initialized
    chwb = coil.to_CoilHeatingWaterBaseboard.get

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
  end
  if coil.to_CoilHeatingWaterBaseboardRadiant.is_initialized
    chwbr = coil.to_CoilHeatingWaterBaseboardRadiant.get

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
  end
  if coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized
    chwtahpef = coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.get

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
  end
  if coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized
    chwtahpvsef = coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.get

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
  end
  if coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
    chwtahpvsefsd = coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.get

    # Get the capacity
    capacity_w = nil
    if chwtahpvsefsd.referenceUnitGrossRatedHeatingCapacity.is_initialized
      capacity_w = chwtahpvsefsd.referenceUnitGrossRatedHeatingCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData', "For #{chwtahpvsefsd.name} capacity is not available.")
    end

    # Get the COP
    cop = chwtahpvsefsd.referenceUnitGrossRatedHeatingCOP

    heating_coil_type = 'CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData'
    heating_coil_fuel = 'ELECTRICITY'
    heating_coil_capacity = capacity_w.round(0)
    heating_coil_eff = cop
    heating_coil_eff_unit = 'COP'
  end

  return heating_coil_type, heating_coil_capacity, heating_coil_eff, heating_coil_eff_unit, heating_coil_fuel

end

def getBoilerInfo(plantLoop, runner)

  capacity_w = nil
  heating_fuel = nil
  heating_eff = nil
  heating_eff_unit = nil

  # look through the supply components for the boiler
  plantLoop.supplyComponents.each do |sc|

    if sc.to_BoilerHotWater.is_initialized
      boiler = sc.to_BoilerHotWater.get

      if boiler.nominalCapacity.is_initialized
        capacity_w = boiler.nominalCapacity.get
      elsif boiler.autosizedNominalCapacity.is_initialized
        capacity_w = boiler.autosizedNominalCapacity.get
      else
        runner.registerError('For Boiler capacity is not available.')
      end

      case boiler.fuelType
      when 'Electricity'
        heating_fuel = 'ELECTRICITY'
      when 'NaturalGas'
        heating_fuel = 'NATURAL_GAS'
      when 'Propane'
        heating_fuel = 'PROPANE'
      when 'FuelOilNo1', 'FuelOilNo2'
        heating_fuel = 'FUEL_OIL'
      else
        heating_fuel = 'NULL'
      end

      heating_eff = boiler.nominalThermalEfficiency
      heating_eff_unit = 'PERCENT'
    end
  end

  return capacity_w, heating_fuel, heating_eff, heating_eff_unit

end

def is_heating_coil(coil)
  coil.to_BoilerHotWater.is_initialized ||
    coil.to_CoilHeatingDXSingleSpeed.is_initialized ||
    coil.to_CoilHeatingGas.is_initialized ||
    coil.to_CoilHeatingElectric.is_initialized ||
    coil.to_ZoneHVACBaseboardConvectiveElectric.is_initialized ||
    coil.to_CoilHeatingDXMultiSpeed.is_initialized ||
    coil.to_CoilHeatingDXMultiSpeedStageData.is_initialized ||
    coil.to_CoilHeatingDXVariableRefrigerantFlow.is_initialized ||
    coil.to_CoilHeatingDXVariableSpeed.is_initialized ||
    coil.to_CoilHeatingDXVariableSpeedSpeedData.is_initialized ||
    coil.to_CoilHeatingGasMultiStage.is_initialized ||
    coil.to_CoilHeatingGasMultiStageStageData.is_initialized ||
    coil.to_CoilHeatingWater.is_initialized ||
    coil.to_CoilHeatingWaterBaseboard.is_initialized ||
    coil.to_CoilHeatingWaterBaseboardRadiant.is_initialized ||
    coil.to_CoilHeatingWaterToAirHeatPumpEquationFit.is_initialized ||
    coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFit.is_initialized ||
    coil.to_CoilHeatingWaterToAirHeatPumpVariableSpeedEquationFitSpeedData.is_initialized
end

#######################################################################
# HVAC Ventilation
# systems found in the model, and determine whether ERV or HRV
# based on latent effectiveness.
# ####################################################################

# @return [Array] returns an array of JSON objects, where
# each object represents an ERV/HRV.
def get_hvac_ventilation(model, runner)
  # runner.registerInfo("Starting search for Mechanical Ventilation equipment.")
  mech_vent_sys = []

  # ERV/HRV
  model.getHeatExchangerAirToAirSensibleAndLatents.each do |erv|
    # runner.registerInfo("Found zone heat exchangers.")
    # Determine if HRV or ERV based on latent effectiveness
    # HRV stands for Heat Recovery Ventilator, which
    # does not do latent heat exchange
    vent_type = 'HEAT_RECOVERY_VENTILATOR'
    if erv.latentEffectivenessat100CoolingAirFlow > 0 || erv.latentEffectivenessat100HeatingAirFlow > 0
      vent_type = 'ENERGY_RECOVERY_VENTILATOR'
    end

    sensible_eff_cool = 0
    if erv.respond_to?('getSensibleEffectivenessat100CoolingAirFlow')
      sensible_eff_cool = erv.getSensibleEffectivenessat100CoolingAirFlow
    elsif erv.respond_to?('sensibleEffectivenessat100CoolingAirFlow')
      sensible_eff_cool = erv.sensibleEffectivenessat100CoolingAirFlow
    end

    sensible_eff_heat = 0
    if erv.respond_to?('getSensibleEffectivenessat100HeatingAirFlow')
      sensible_eff_heat = erv.getSensibleEffectivenessat100HeatingAirFlow
    elsif erv.respond_to?('sensibleEffectivenessat100HeatingAirFlow')
      sensible_eff_heat = erv.sensibleEffectivenessat100HeatingAirFlow
    end
    sensible_eff = (sensible_eff_cool + sensible_eff_heat) / 2
    latent_eff_cool = 0
    if erv.respond_to?('getLatentEffectivenessat100CoolingAirFlow')
      latent_eff_cool = erv.getLatentEffectivenessat100CoolingAirFlow
    elsif erv.respond_to?('latentEffectivenessat100CoolingAirFlow')
      latent_eff_cool = erv.latentEffectivenessat100CoolingAirFlow
    end

    latent_eff_heat = 0
    if erv.respond_to?('getLatentEffectivenessat100HeatingAirFlow')
      latent_eff_heat = erv.getLatentEffectivenessat100HeatingAirFlow
    elsif erv.respond_to?('latentEffectivenessat100HeatingAirFlow')
      latent_eff_heat = erv.latentEffectivenessat100HeatingAirFlow
    end

    mech_vent_sys << {
      'fanType' => vent_type,
      'thirdPartyCertification' => 'OTHER', # Defaulted to None because there is no way to know.
      # Since these are zone level equipment, no way to know if its for the whole house.
      'usedForWholeBuildingVentilation' => false,
      'sensibleRecoveryEfficiency' => sensible_eff, # a simple average of heating and cooling
      # a simple average of heating and cooling
      'totalRecoveryEfficiency' => ((sensible_eff_cool + latent_eff_cool) + (sensible_eff_heat + latent_eff_heat)) / 2
    }
  end

  mech_vent_sys
end

#######################################################################
# DHW - Water Heaters
# Current issues - cannot match to HPWH with wrapped condenser for some reason.
#####################################################################

def get_water_heaters(model, runner)

  all_whs = []
  mixed_tanks = []
  stratified_tanks = []

  runner.registerInfo('Getting all water heaters.')
  # Heat pump - single speed
  # variable speed code is provided but not tested because cannot currently add variable speed HPWH in OS.
  model.getWaterHeaterHeatPumps.each do |wh|
    runner.registerInfo('Found WaterHeaterHeatPump (single or variable speed).')
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

    all_whs << {
      'waterHeaterType' => 'HEAT_PUMP_WATER_HEATER',
      'fuelType' => 'ELECTRICITY',
      'tankVolume' => vol_gal.round(1),
      'heatingCapacity' => capacity_w.round(1),
      'energyFactor' => 0,
      'uniformEnergyFactor' => cop.round(2),
      'thermalEfficiency' => nil,
      'waterHeaterInsulationJacketRValue' => nil # defaulted to nil
    }
    runner.registerInfo('Compiled heat pump water heater information for single and variable speed.')
  end

  # Heat pump wrapped condenser
  model.getWaterHeaterHeatPumpWrappedCondensers.each do |whwc|
    runner.registerInfo('Found WaterHeaterHeatPumpWrappedCondenser.')
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

    all_whs << {
      'waterHeaterType' => 'HEAT_PUMP_WATER_HEATER',
      'fuelType' => 'ELECTRICITY',
      'tankVolume' => vol_gal.round(1),
      'heatingCapacity' => capacity_w.round(1),
      'energyFactor' => 0,
      'uniformEnergyFactor' => cop.round(2),
      'thermalEfficiency' => nil,
      'waterHeaterInsulationJacketRValue' => nil # defaulted to nil
    }
    runner.registerInfo('Compiled heat pump water heater information for wrapped condensers.')
  end

  # Water heaters as storage on the demand side
  model.getPlantLoops.each do |loop|
    loop.demandComponents.each do |dc|
      next unless dc.to_WaterHeaterMixed.is_initialized

      solar_wh_tank_mixed = dc.to_WaterHeaterMixed.get
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
    # runner.registerInfo("Found a mixed water heater.")
    # Get the capacity (single heating element).
    capacity_w = wh.heaterMaximumCapacity.get

    # Get the efficiency
    eff = nil
    eff = wh.heaterThermalEfficiency.get if wh.heaterThermalEfficiency.is_initialized

    # Get the fuel
    case wh.heaterFuelType
    when 'Electricity'
      fuel = 'ELECTRICITY'
    when 'NaturalGas'
      fuel = 'NATURAL_GAS'
    when 'FuelOilNo1', 'FuelOilNo2'
      fuel = 'FUEL_OIL'
    when 'Propane'
      fuel = 'PROPANE'
    else
      fuel = 'NULL'
    end

    # Get the volume
    vol_gal = nil
    if wh.tankVolume.is_initialized
      vol_m3 = wh.tankVolume.get
      vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
    end

    # Check if the water heater is "tankless" (less than 10 gallons)
    type = if vol_gal < 10
             'INSTANTANEOUS_WATER_HEATER'
           else
             'STORAGE_WATER_HEATER'
           end
    all_whs << {
      'waterHeaterType' => type,
      'fuelType' => fuel,
      'tankVolume' => vol_gal.round(1),
      'heatingCapacity' => capacity_w,
      'energyFactor' => 0,
      'uniformEnergyFactor' => 0,
      'thermalEfficiency' => eff,
      'waterHeaterInsulationJacketRValue' => 0 # defaulted to nil
    }
    runner.registerInfo('Compiled mixed water heater information.')
  end

  # Stratified
  # Water heaters as storage on the demand side
  model.getPlantLoops.each do |loop|
    loop.demandComponents.each do |dc|
      next unless dc.to_WaterHeaterStratified.is_initialized

      solar_wh_tank_stratified = dc.to_WaterHeaterStratified.get
      # runner.registerInfo("solar thermal tank = #{solar_wh_tank_stratified} was found.")
      stratified_tanks << solar_wh_tank_stratified
    end
  end

  model.getWaterHeaterStratifieds.each do |wh|
    # Skip stratified tanks that were already accounted for because they were attached to heat pumps
    next if stratified_tanks.include?(wh)

    # Get the fuel
    case wh.heaterFuelType
    when 'Electricity'
      fuel = 'ELECTRICITY'
    when 'NaturalGas'
      fuel = 'NATURAL_GAS'
    when 'FuelOilNo1', 'FuelOilNo2'
      fuel = 'FUEL_OIL'
    when 'Propane'
      fuel = 'PROPANE'
    else
      fuel = 'NULL'
    end

    # Get the capacity (up to 2 heating elements).
    capacity_heater1_w = if wh.heater1Capacity.is_initialized
                           # runner.registerInfo("Heater 1 Capacity (#{wh.heater1Capacity}) is initialized.")
                           wh.heater1Capacity.get
                         else
                           0
                         end

    # Adding a zero value to the total capacity was creating an issue. So now we check if its zero or nil.
    capacity_heater2_w = if (wh.heater2Capacity != 0) && (wh.heater2Capacity != nil)
                           # runner.registerInfo("Capacity 2 has a value.")
                           wh.heater2Capacity.get
                         else
                           # runner.registerInfo("Capacity 2 does not have a value.")
                           0
                         end

    capacity_w = capacity_heater1_w + capacity_heater2_w

    # Get the volume
    vol_gal = nil
    if wh.tankVolume.is_initialized
      vol_m3 = wh.tankVolume.get
      vol_gal = OpenStudio.convert(vol_m3, 'm^3', 'gal').get
    end

    # Check if the water heater is "tankless" (less than 10 gallons)
    type = if vol_gal < 10
             'INSTANTANEOUS_WATER_HEATER'
           else
             'STORAGE_WATER_HEATER'
           end
    # Get the efficiency
    eff = wh.heaterThermalEfficiency

    # Create the water heater array.
    all_whs << {
      'waterHeaterType' => type,
      'fuelType' => fuel,
      'tankVolume' => vol_gal.round(1),
      'heatingCapacity' => capacity_w,
      'energyFactor' => nil,
      'uniformEnergyFactor' => nil,
      'thermalEfficiency' => eff,
      'waterHeaterInsulationJacketRValue' => nil # defaulted to nil
    }
    runner.registerInfo('Compiled stratified water heater information.')
  end

  all_whs
end

#####################################################################
# DHW - Water Distributions
#####################################################################
def get_water_distributions(num_bathrooms, conditioned_floor_area)
  # Could add user inputs for pipe insulation fraction and r-value and pipe material (PEX vs copper).
  fraction_insulated = 0.5 # hard coded to 50%. Assume all hot and no cold water pipes are insulated.
  pipe_length = 366 + 0.1322 * (conditioned_floor_area - 2432) + 86 * (num_bathrooms - 2.85)

  [
    {
      'hwdPipeRValue' => 2, # hard coded to R-2
      'hwdPipeLengthInsulated' => pipe_length * fraction_insulated.round(1),
      'hwdFractionPipeInsulated' => fraction_insulated,
      'pipingLength' => pipe_length.round(1),
      'pipeMaterial' => 'COPPER'
    }
  ]
end

#####################################################################
# HVAC - Dehumidifier
#####################################################################
def get_moisture_controls(model)
  model.getZoneHVACDehumidifierDXs.map do |dehumidifier|
    {
      'dehumidifierType' => 'STANDALONE',
      'efficiency' => dehumidifier.ratedEnergyFactor,
    }
  end
end
