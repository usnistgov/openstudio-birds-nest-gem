# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

##############################################################################
# Summary Characteristics
# Could be moved to a separate rb file, but would require more global variables
##############################################################################

def to_snake_case(string)
  string.gsub(/::/, '/')
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')
        .tr('-', '_')
end

class SummaryCharacteristics
  attr_accessor :num_stories_above_grade, :conditioned_floor_area, :num_bathrooms

  def get_summary_characteristics(model, runner, state, city, country, climate_zone, zip, com_res, bldg_type, const_qual, num_bedrooms, num_bathrooms, study_period, lc_stage)
    @num_bathrooms = num_bathrooms

    # Determine the Number of Floors/Stories Above Grade
    # TO DO: Handle OSM files that do not have stories defined. They only have thermal zones.
    # Find all stories in the OSM model
    all_stories = model.getBuildingStorys.sort
    # Throw an error if no stories are present
    if all_stories.size.zero?
      runner.registerError('This building has no stories.  Assign each space in the model to a story in order to enable the LCA calculations to work properly.')
      return false
    end

    # Remove any basements, crawlspaces, or attics from the list of stories to get the stories above grade.
    birds_stories = []
    hidden_stories = 0
    basement_story = false

    all_stories.each do |story|
      # initialize variables for story specs
      underground_story = false
      basement = false

      # Determine if space is heated or cooled
      conditioned = story.spaces.flat_map(&:spaces).map { |space| space.heated? || space.cooled? }.any?

      story.spaces.each do |space|
        # Determine if this space is underground and if there are more than one story/floor within the space.
        # This is to catch thermal zones that group multiple floors/stories together for modeling purposes (e.g., PNNL prototypes).
        # initalize variables to find underground story height (if < 6 ft, then its crawspace; else its basement)

        # find all floor surfaces and determine how many stories/floors exist in the space/thermal zone
        # this is done by finding the z vertices for the first floor surface
        # and then checking the z vertices for other floors to see if the z vertices are different
        floor_vertices = space.surfaces.select { |surface| surface.surfaceType == 'Floor' }.flat_map(&:vertices)
        floor_0_z_value = floor_vertices.first.z
        floor_1_z_value = floor_vertices[1].z unless floor_vertices[1].nil?

        underground_surfaces = space.surfaces.select { |surface| surface.outsideBoundaryCondition == 'Ground' && surface.surfaceType == 'Wall' }
        underground_story = underground_surfaces.any?

        # check height of the story using all the walls' z values
        underground_z_values = underground_surfaces.flat_map(&:vertices).map(&:z)
        min_z_value = underground_z_values.min
        max_z_value = underground_z_values.max

        # Space Name
        runner.registerInfo("Space = #{space.name}.")

        # Use the max and min of the walls in the (at least partially) underground story to see if its a basement
        # If the min and maz values have changed, then we know we found at least one underground wall.
        # if basement has not yet been found, then keep looping through stories.
        if !basement && underground_story
          if (min_z_value < 10_000) && (max_z_value > -10_000)
            underground_story_height_m = max_z_value - min_z_value
            runner.registerInfo("Underground Story Height (m) = #{underground_story_height_m}.")
            underground_story_height_ft = OpenStudio.convert(underground_story_height_m, 'm', 'ft').get
            runner.registerInfo("Underground Story Height (ft) = #{underground_story_height_ft}.")
            if underground_story_height_ft > 6
              # changes this story being a basement
              basement = true
              # changes whether the building has a basement story to true
              basement_story = true
              runner.registerInfo('Underground Story is a Basement.')
            else
              runner.registerInfo('Underground Story is NOT a Basement.')
            end
          else
            runner.registerInfo('Underground Story z values were not found.')
          end
        end

        # Report whether the space has a single story.
        # Currently assumes 0 or 1 "hidden" stories.
        if !floor_0_z_value.nil? && !floor_1_z_value.nil? && (floor_0_z_value != floor_1_z_value)
          runner.registerInfo("Warning: This space #{space.name} represents multiple stories: Z values are #{floor_0_z_value} and #{floor_1_z_value}. Adding a story to the building.")
          # Adds a story to the hidden stories variable.
          # if the hidden story is found in one or more spaces of the story, then the value is 1.
          # TO DO: how do we address multiple spaces in a given story?
          hidden_stories = hidden_stories + 1
        end
      end

      # Don't count underground stories
      if basement
        runner.registerInfo("#{story.name} is a basement, and will not treated as a building story.")
        next
      end
      if underground_story
        runner.registerInfo("#{story.name} is underground, and will not treated as a building story.")
        next
      end
      # Don't count unconditioned stories
      unless conditioned
        runner.registerInfo("#{story.name} is unconditioned space, and will not treated as a building story.")
        next
      end
      # Don't count more than 2 stories
      if birds_stories.size == 2
        runner.registerWarning("BIRDS only accepts 1 and 2-story homes.  #{story.name}, basement = #{basement}, conditioned = #{conditioned} will not be included.")
        next
      end
      # If here, count this story
      birds_stories << story
    end

    runner.registerInfo("Number of stories defined #{birds_stories.size}.")
    runner.registerInfo("Number of hidden stories found #{hidden_stories}.")

    # Add hidden stories to identified stories.
    @num_stories_above_grade = birds_stories.size + hidden_stories
    runner.registerInfo("total number of stories #{@num_stories_above_grade}.")

    # Calculate the Building Height based on surfaces above grade

    vertices_z = model.getSurfaces
                      .select { |surf| surf.outsideBoundaryCondition != 'Ground' && surf.outsideBoundaryCondition != 'Foundation' }
                      .flat_map(&:vertices)
                      .map(&:z)

    buildingHeight_ft = OpenStudio.convert(vertices_z.max - vertices_z.min, 'm', 'ft').get.round(0)
    runner.registerInfo("Building Height is #{buildingHeight_ft} ft")

    # Calculate the Total Conditioned Floor Areas and Exterior Wall Areas by story
    all_conditioned_spaces = birds_stories.map(&:spaces).map { |spaces| conditioned_spaces(spaces) }

    @conditioned_floor_area = all_conditioned_spaces.map { |conditioned_spaces| conditioned_spaces.map(&:floorArea).sum }
                                                    .map { |sum| OpenStudio.convert(sum, 'm^2', 'ft^2').get.round }
                                                    .sum
                                                    .round

    runner.registerInfo("Total Conditioned Floor Area is #{@conditioned_floor_area} ft2.")

    # Combine objects above into the Summary Characteristics Object
    # (API Version, Location, Building, Stories, Basement, Height, Floor Area, Wall Area)
    {
      'apiVersion' => 'Version 2.0 Draft',
      'referenceStudyPeriod' => ref_study_period(runner, study_period),
      'systemBoundary' => sys_bound(lc_stage, runner),
      'location' => {
        'country' => country, # Default to "USA" if not available.
        'climateZone' => "_#{climate_zone}", # Is not required. Can it be filled from the ZIP code?
        'cityMunicipality' => city.to_s,
        'stateCode' => state.to_s,
        'zipCode' => zip.to_s
      },
      'building' => {
        'category' => to_snake_case(com_res).upcase,
        'residentialFacilityType' => bldg_type_enum(bldg_type),
        'constructionQuality' => const_qual.upcase,
        'occupancyType' => 'OWNER_OCCUPIED' # Assumed to be owner occupied. Needs to be a user input.
      },
      'numberOfStoriesAboveGrade' => @num_stories_above_grade,
      'basement' => basement_story,
      'buildingHeight' => buildingHeight_ft,
      'conditionedFloorArea' => @conditioned_floor_area,
      'exteriorWallAreas' => ext_wall_areas(all_conditioned_spaces),
      'numberOfBedrooms' => num_bedrooms,
      'numberOfBathrooms' => @num_bathrooms
    }

  end

  private

  def ref_study_period(runner, study_period)
    # Study Period
    ref_study_period = study_period.to_i

    if ref_study_period < 60
      runner.registerInfo("User Study Period = #{study_period}, which is not at least 60 years. Please change the study period.")
      runner.registerError("User Study Period = #{study_period}, which is not at least 60 years. Please change the study period.")
    end
    ref_study_period
  end

  def ext_wall_areas(all_conditioned_spaces)
    result = all_conditioned_spaces.map { |conditioned_spaces| conditioned_spaces.map(&:exteriorWallArea).sum }
                                   .map { |sum| OpenStudio.convert(sum, 'm^2', 'ft^2').get.round }
                                   .map { |story_ext_wall_area_ft2| { 'area' => story_ext_wall_area_ft2.round } }

    runner.registerInfo("Total Exterior Wall Area by story is #{result} ft2.")

    result
  end

  def conditioned_spaces(spaces)
    spaces.each { |space| runner.registerInfo("Space #{space.name} has a floor area of #{space.floorArea.round(2)} m2 and an exterior wall area of #{space.exteriorWallArea.round(2)} m2.") }
          .select { |space| space.heated? || space.cooled? }
          .each { |space| runner.registerInfo("Unconditioned Space #{space.name} has a floor area of #{space.floorArea} m2 and an exterior wall area of #{space.exteriorWallArea} m2.") }
  end

  def bldg_type_enum(bldg_type)
    if bldg_type == 'SingleFamilyDetached'
      'SINGLE_FAMILY_DETACHED'
    else
      ''
    end
  end

  def sys_bound(lc_stage, runner)
    lc_stage_string = lc_stage.to_s
    sys_bound = if %w[A-C A-D].include?(lc_stage_string)
                  lc_stage_string.gsub('-', '_')
                else
                  'UNSPECIFIED'
                end

    runner.registerInfo("Life Cycle Stages Included = #{lc_stage_string}.")
    runner.registerInfo("System Boundary = #{sys_bound}.")

    sys_bound
  end
end
