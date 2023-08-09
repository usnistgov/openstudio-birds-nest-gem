# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  # Ensure that the version of OpenStudio is 1.6.0 or greater
  # because the HVACSizing .autosizedFoo methods are currently built
  # expecting the EnergyPlus 8.2 syntax.
  min_os_version = "1.6.0"
  if OpenStudio::Model::Model.new.version < OpenStudio::VersionString.new(min_os_version)
    OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "This measure requires a minimum OpenStudio version of #{min_os_version} because the HVACSizing .autosizedFoo methods expect EnergyPlus 8.2 output variable names.")
  end
  
  # Load the helper libraries for getting the autosized
  # values for each type of model object.
  require_relative 'HVACSizing.CoilHeatingElectric'
  require_relative 'HVACSizing.CoilHeatingGas'
  require_relative 'HVACSizing.CoilHeatingDXSingleSpeed'
  require_relative 'HVACSizing.CoilCoolingDXSingleSpeed'
  require_relative 'HVACSizing.CoilCoolingDXTwoSpeed'
  require_relative 'HVACSizing.BoilerHotWater'
  require_relative 'HVACSizing.ChillerElectricEIR'
  require_relative 'HVACSizing.ZoneHVACPackagedTerminalAirConditioner'
  require_relative 'HVACSizing.ZoneHVACPackagedTerminalHeatPump'
  
  # A helper method to get component sizes from the model
  # returns the autosized value as an optional double
  def getAutosizedValue(object, value_name, units)

    result = OpenStudio::OptionalDouble.new

    name = object.name.get.upcase
    
    object_type = object.iddObject.type.valueDescription.gsub('OS:','')
      
    sql = self.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    
      #SELECT * FROM ComponentSizes WHERE CompType = 'Coil:Heating:Gas' AND CompName = "COIL HEATING GAS 3" AND Description = "Design Size Nominal Capacity"
      query = "SELECT Value 
              FROM ComponentSizes 
              WHERE CompType='#{object_type}' 
              AND CompName='#{name}' 
              AND Description='#{value_name}' 
              AND Units='#{units}'"
              
      val = sql.execAndReturnFirstDouble(query)
      
      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        # TODO: comment following line (debugging new HVACsizing objects right now)
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "QUERY ERROR: Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end

  # A helper method to get component sizes from the Equipment Summary of the TabularDataWithStrings Report
  # returns the autosized value as an optional double
  def getAutosizedValueFromEquipmentSummary(object, table_name, value_name, units)

    result = OpenStudio::OptionalDouble.new

    name = object.name.get.upcase

    sql = self.sqlFile

    if sql.is_initialized
      sql = sql.get

      #SELECT * FROM ComponentSizes WHERE CompType = 'Coil:Heating:Gas' AND CompName = "COIL HEATING GAS 3" AND Description = "Design Size Nominal Capacity"
      query = "Select Value FROM TabularDataWithStrings WHERE
      ReportName = 'EquipmentSummary' AND
      TableName = '#{table_name}' AND
      RowName = '#{name}' AND
      ColumnName = '#{value_name}' AND
      Units = '#{units}'"

      val = sql.execAndReturnFirstDouble(query)

      if val.is_initialized
        result = OpenStudio::OptionalDouble.new(val.get)
      else
        # TODO: comment following line (debugging new HVACsizing objects right now)
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Model", "QUERY ERROR: Data not found for query: #{query}")
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
    end

    return result
  end

end
