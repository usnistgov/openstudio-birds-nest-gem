# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::Space
  # Determines heating status.  If the space's
  # zone has a thermostat with a maximum heating
  # setpoint above 5C (41F), counts as heated.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if heated, false if not
  def heated?
    # Get the zone this space is inside
    zone = thermalZone

    # Assume unheated if not assigned to a zone
    if zone.empty?
      return false
    end

    # Get the category from the zone
    htd = zone.get.heated?

    return htd
  end

  # Determines cooling status.  If the space's
  # zone has a thermostat with a minimum cooling
  # setpoint above 33C (91F), counts as cooled.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if cooled, false if not
  def cooled?
    # Get the zone this space is inside
    zone = thermalZone

    # Assume uncooled if not assigned to a zone
    if zone.empty?
      return false
    end

    # Get the category from the zone
    cld = zone.get.cooled?

    return cld
  end

# Determine if the space is a plenum.
  # Assume it is a plenum if it is a supply
  # or return plenum for an AirLoop,
  # if it is not part of the total floor area,
  # or if the space type name contains the
  # word plenum.
  #
  # return [Bool] returns true if plenum, false if not
  #def plenum?
   # plenum_status = false

    # Check if it is designated
    # as not part of the building
    # floor area.  This method internally
    # also checks to see if the space's zone
    # is a supply or return plenum
    #unless partofTotalFloorArea
    #  plenum_status = true
    #  return plenum_status
    #end

    # TODO: - update to check if it has internal loads

    # Check if the space type name
    # contains the word plenum.
    #space_type = spaceType
    #if space_type.is_initialized
    #  space_type = space_type.get
    #  if space_type.name.get.to_s.downcase.include?('plenum')
    #    plenum_status = true
    #    return plenum_status
    #  end
    #  if space_type.standardsSpaceType.is_initialized
    #    if space_type.standardsSpaceType.get.downcase.include?('plenum')
    #      plenum_status = true
    #      return plenum_status
    #    end
    #  end
    #end

    #return plenum_status
 # end
end
