# frozen_string_literal: true

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
    return false if zone.empty?

    # Get the category from the zone
    zone.get.heated?
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
    return false if zone.empty?

    # Get the category from the zone
    zone.get.cooled?
  end
end
