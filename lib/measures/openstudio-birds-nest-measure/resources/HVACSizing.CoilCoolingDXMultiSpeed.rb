# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# open the class to add methods to return sizing values
class OpenStudio::Model::CoilCoolingDXMultiSpeed

  # Sets all auto-sizeable fields to autosize
  def autosize
    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoilCoolingDXMultiSpeed", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.CoilCoolingDXMultiSpeed", ".applySizingValues not yet implemented for #{self.iddObject.type.valueDescription}.")
        
  end

  # returns the autosized design supply air flow rate as an optional double
  # def autosizedDesignSupplyAirFlowRate

    # return self.model.getAutosizedValue(self, 'Design Supply Air Flow Rate', 'm3/s')
    
  # end
  
  
end
