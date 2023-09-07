# frozen_string_literal: true

module Default
  def cooling_system_type
    'NULL_CST'
  end

  def cooling_system_fuel
    'NULL'
  end

  def heating_system_type
    'NULL_HST'
  end

  def heating_system_fuel
    'NULL'
  end

  def heat_pump_type
    'NULL_HPT'
  end

  def heat_pump_fuel
    'NULL_HPF'
  end

  def geothermal_loop_transfer
    'NULL'
  end

  def geothermal_loop_type
    'NULL_GLT'
  end

  def backup_type
    'NULL_BT'
  end

  def backup_system_fuel
    'NULL'
  end
end

class PrimaryHVACInstance
  include Default

  def initialize(display_name)
    @display_name = display_name
  end

  def to_s
    @display_name
  end
end

default = {
  userHeatPumpTypes: 'NullHPT'
}

PRIMARY_HVAC = {
  Resid_CentralAC_Furnace_Gas: PrimaryHVACInstance.new('Central AC, Gas Furnace'),
  # Resid_CentralAC_Furnace_Oil: PrimaryHVACInstance.new('Central AC, Oil Furnace'),
  # Resid_CentralAC_Furnace_Propane: PrimaryHVACInstance.new('Central AC, Propane Furnace'),
  Resid_CentralAC_Furnace_Electric: PrimaryHVACInstance.new('Central AC, Electric Furnace'),
  Resid_CentralAC_Baseboard_Electric: PrimaryHVACInstance.new('Central AC, Electric Baseboard'),
  Resid_CentralAC_Boiler_Electric: PrimaryHVACInstance.new('Central AC, Electric Boiler'),
  Resid_CentralAC_Boiler_Gas: PrimaryHVACInstance.new('Central AC, Gas Boiler'),
  Resid_CentralAC_Boiler_Oil: PrimaryHVACInstance.new('Central AC, Oil Boiler'),
  Resid_CentralAC_Boiler_Propane: PrimaryHVACInstance.new('Central AC, Propane Boiler'),
  Resid_CentralAC_NoHeat_NoFuel: PrimaryHVACInstance.new('Central AC, No Heat'),
  Resid_NoAC_Furnace_Gas: PrimaryHVACInstance.new('No AC, Gas Furnace'),
  Resid_NoAC_Furnace_Electric: PrimaryHVACInstance.new('No AC, Electric Furnace'),
  Resid_NoAC_Boiler_Electric: PrimaryHVACInstance.new('No AC, Electric Boiler'),
  Resid_NoAC_Boiler_Gas: PrimaryHVACInstance.new('No AC, Gas Boiler'),
  Resid_NoAC_Boiler_Oil: PrimaryHVACInstance.new('No AC, Oil Boiler'),
  Resid_NoAC_Boiler_Propane: PrimaryHVACInstance.new('No AC, Propane Boiler'),
  Resid_NoAC_Baseboard_Electric: PrimaryHVACInstance.new('No AC, Electric Baseboard'),
  Resid_HeatPump_AirtoAir_Std: PrimaryHVACInstance.new('Heat Pump, Air-to-Air Std'),
  Resid_HeatPump_AirtoAir_SDHV: PrimaryHVACInstance.new('Heat Pump, Air-to-Air SDHV'),
  Resid_HeatPump_AirtoAir_MiniSplitDucted: PrimaryHVACInstance.new('Heat Pump, Ducted Air-to-Air Mini Split'),
  Resid_HeatPump_AirtoAir_MiniSplitNonDucted: PrimaryHVACInstance.new('Heat Pump, Non-Ducted Air-to-Air Mini Split'),
  Resid_HeatPump_Geothermal_Vertical: PrimaryHVACInstance.new('Heat Pump, Vertical Geothermal'),
  Resid_RoomAC_Furnace_Gas: PrimaryHVACInstance.new('Room AC, Gas Furnace'),
  Resid_RoomAC_Furnace_Electric: PrimaryHVACInstance.new('Room AC, Electric Furnace'),
  Resid_RoomAC_Baseboard_Electric: PrimaryHVACInstance.new('Room AC, Electric Baseboard')
}.freeze
