# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

##############################################################################
#Summary Characteristics
#Could be moved to a separate rb file, but woud require more global variables
##############################################################################

class SummaryCharacteristics

attr_accessor :numberOfStoriesAboveGrade, :conditioned_floor_area, :numberOfbathrooms

def get_summary_characteristics(model, runner, state, city, country, climate_zone, zip, com_res, bldg_type, 
	const_qual, num_bedrooms, num_bathrooms, study_period, lc_stage)
	
	@numberOfbathrooms = num_bathrooms
	
	# Study Period
	ref_study_period = study_period.to_i
	
	if ref_study_period < 60
		runner.registerInfo("User Study Period = #{study_period}, which is not at least 60 years. Please change the study period.")
		runner.registerError("User Study Period = #{study_period}, which is not at least 60 years. Please change the study period.")
	end
	
	# Life Cycle Stages
	lc_stage = lc_stage.to_s
	runner.registerInfo("Life Cycle Stages Included = #{lc_stage}.")
	if lc_stage == 'A-C'
		sys_bound = 'A_C'
	elsif lc_stage == 'A-D'
		sys_bound = 'A_D'
	else
		sys_bound = 'UNSPECIFIED'
	end
	runner.registerInfo("System Boundary = #{sys_bound}.")

	# Location
	#Split the state city provided by the user
	#state, city = state_city.split(' - ')
	
	#convert climate zone to enum
	climate_zone_enum = '_' + climate_zone

	#create array of location information
	location = {
	  'country' => country,		#Default to "USA" if not available.
	  'climateZone' => climate_zone_enum, #Is not required. Can it be filled from the ZIP code?
	  'cityMunicipality' => city.to_s,
	  'stateCode' => state.to_s,
	  'zipCode' => zip.to_s
	}
	
	# convert category to enum value
	
	com_res_enum = ""
	if com_res == 'Commercial'
		com_res_enum = 'COMMERCIAL'
	elsif com_res == 'LowRiseResidential'
		com_res_enum = 'LOW_RISE_RESIDENTIAL'
	elsif com_res == 'NonLowRiseResidential'
		com_res_enum = 'NON_LOW_RISE_RESIDENTIAL'
	end
	
	# set building type enum 
	#add more types when they are added in the arguments
	bldg_type_enum = ""
	if bldg_type == 'SingleFamilyDetached'
		bldg_type_enum = 'SINGLE_FAMILY_DETACHED'
	end
	
	#set building quality enum
	const_qual_enum = ""
	if(const_qual == 'Average')
		const_qual_enum = 'AVERAGE'
	elsif(const_qual == 'Luxury')
		const_qual_enum = "LUXURY"
	elsif(const_qual == 'Custom')
		const_qual_enum = 'CUSTOM'
	end

	# Create array of Building information
	building = {  
	  'category' => com_res_enum,
	  'residentialFacilityType' => bldg_type_enum,
	  'constructionQuality' => const_qual_enum,
	  'occupancyType' => 'OWNER_OCCUPIED'					#Assumed to be owner occupied. Needs to be a user input.
	}
	
	# Determine the Number of Floors/Stories Above Grade
	# TO DO: Handle OSM files that do not have stories defined. They only have thermal zones.
	#Find all stories in the OSM model
	all_stories = model.getBuildingStorys.sort
	# Throw an error if no stories are present
	if all_stories.size == 0
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
	  conditioned = false
	  # initalize variables to determine if there is more than one story/floor within the space/thermal zone
	  # Have to initialize here so it can be used outside the story loop
	  floor_0_z_value = nil
	  floor_1_z_value = nil  
					
	  story.spaces.each do |space|
		# Determine if this space is underground and if there are more than one story/floor within the space.
		# This is to catch thermal zones that group multiple floors/stories together for modeling purposes (e.g., PNNL prototypes).
		# initalize variables to find underground story height (if < 6 ft, then its crawspace; else its basement)
		
		min_z_value = 10000
		max_z_value = -10000
		underground_story_height_m = nil
		underground_story_height_ft = nil
		
		# Reset floor z values before moving to the next space
		floor_0_z_value = nil
		floor_1_z_value = nil
		
		# Space Name
		runner.registerInfo("Space = #{space.name}.")
		
		space.surfaces.each do |surf|
			# check to see if any of walls are underground. assumes partial basements are full basements.
			if surf.outsideBoundaryCondition == 'Ground' && surf.surfaceType == 'Wall'
				# if there is an underground wall, then the story is underground.
				underground_story = true
				# check height of the story using all the walls' z values
				surf.vertices.each do |vertex|
					if vertex.z < min_z_value
						min_z_value = vertex.z
					end
					if vertex.z > max_z_value
						max_z_value = vertex.z
					end
				end
			end
			# find all floor surfaces and determine how many stories/floors exist in the space/thermal zone
			# this is done by finding the z vertices for the first floor surface
			# and then checking the z vertices for other floors to see if the z vertices are different
			if surf.surfaceType == 'Floor'
				#runner.registerInfo("Floor Name = #{surf.name}.")
				surf.vertices.each do |vertex|
					if floor_0_z_value == nil
						floor_0_z_value = vertex.z
					elsif floor_0_z_value != nil
						floor_1_z_value	= vertex.z
					end
				end
				#runner.registerInfo("Floor Z Vertices values = #{floor_0_z_value} and #{floor_1_z_value}.")
			end
		end
		
		# Use the max and min of the walls in the (at least partially) underground story to see if its a basement
		# If the min and maz values have changed, then we know we found at least one underground wall.
		# if basement has not yet been found, then keep looping through stories.
		if basement == false	and underground_story == true
			if min_z_value < 10000 and max_z_value > -10000
				underground_story_height_m = max_z_value - min_z_value
				runner.registerInfo("Underground Story Height (m) = #{underground_story_height_m}.")
				underground_story_height_ft = OpenStudio.convert(underground_story_height_m, 'm','ft').get
				runner.registerInfo("Underground Story Height (ft) = #{underground_story_height_ft}.")
				if 	underground_story_height_ft > 6
					# changes this story being a basement
					basement = true
					# changes whether the building has a basement story to true
					basement_story = true
					runner.registerInfo("Underground Story is a Basement.")
				else
					runner.registerInfo("Underground Story is NOT a Basement.")
				end
			else
				runner.registerInfo("Underground Story z values were not found.")
			end
		end
		
		# Report whether the space has a single story.
		# Currently assumes 0 or 1 "hidden" stories.
		if floor_0_z_value != nil and floor_1_z_value != nil and floor_0_z_value != floor_1_z_value
			runner.registerInfo("Warning: This space #{space.name} represents multiple stories: Z values are #{floor_0_z_value} and #{floor_1_z_value}. Adding a story to the building.")
			# Adds a story to the hidden stories variable.
			# if the hidden story is found in one or more spaces of the story, then the value is 1.
			# TO DO: how do we address multiple spaces in a given story?
			hidden_stories = hidden_stories + 1
		else
			#runner.registerInfo('Confirmed this space represents a single story.')
		end
		  
		  # Determine if space is heated or cooled
		  conditioned = true if space.heated? || space.cooled?	
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
	
	#Add hidden stories to identified stories.
	@numberOfStoriesAboveGrade = birds_stories.size + hidden_stories
	runner.registerInfo("total number of stories #{@numberOfStoriesAboveGrade}.")

	# Calculate the Building Height based on surfaces above grade
	maxZ = Float::MIN
	minZ = Float::MAX
	model.getSurfaces.each do |surf|
		# only include surfaces not adjacent to ground or foundation
		if surf.outsideBoundaryCondition != 'Ground' && surf.outsideBoundaryCondition != 'Foundation'
			surf.vertices.each do |vertex|
				z = vertex.z
				if z < minZ
					minZ = z
				elsif z > maxZ
					maxZ = z
				end
			end
		end
	end
	buildingHeight_m = maxZ - minZ;
	buildingHeight_ft = OpenStudio.convert(buildingHeight_m, 'm','ft').get
	buildingHeight_ft = buildingHeight_ft.round(0)
	runner.registerInfo("Building Height is #{buildingHeight_ft} ft")
   
	# Calculate the Total Conditioned Floor Areas and Exterior Wall Areas by story
	@conditioned_floor_area = 0
	ext_wall_areas = []
	
	birds_stories.each do |story|
	  story_floor_area_m2 = 0
	  story_ext_wall_area_m2 = 0
	  
	  story.spaces.each do |space|

	  runner.registerInfo("Space #{space.name} has a floor area of #{space.floorArea.round(2)} m2 and an exterior wall area of #{space.exteriorWallArea.round(2)} m2.")

	  # Add this floor area
	  next unless space.heated? || space.cooled?   ### skips unconditioned spaces
	  runner.registerInfo("Unconditioned Space #{space.name} has a floor area of #{space.floorArea} m2 and an exterior wall area of #{space.exteriorWallArea} m2.")
	  story_floor_area_m2 += space.floorArea  ### Changed to account for conditioned floor area only.
	  # Add this exterior wall area
	  story_ext_wall_area_m2 += space.exteriorWallArea 
	  end
	  
	  # Record the total for this story
	  story_floor_area_ft2 = OpenStudio.convert(story_floor_area_m2, 'm^2','ft^2').get.round
	  story_ext_wall_area_ft2 = OpenStudio.convert(story_ext_wall_area_m2, 'm^2','ft^2').get.round
	  story_name = story.name.get.to_s
	  runner.registerInfo("Story #{story_name} has a floor area of #{story_floor_area_ft2} ft2 and an exterior wall area of #{story_ext_wall_area_ft2} ft2.")
	  
	  #Aggregate floor areas to a single total conditioned floor area value.
	  @conditioned_floor_area += story_floor_area_ft2.round
	  runner.registerInfo("Total CFA is now #{@conditioned_floor_area} ft2.")
	  
	  #Report exterior wall area by story.
	  ext_wall_areas << {
		'area' => story_ext_wall_area_ft2.round
	  }
	  runner.registerInfo("EWA Array is now #{ext_wall_areas} ft2.")
	end
	
	runner.registerInfo("Total Conditioned Floor Area is #{@conditioned_floor_area} ft2.")
	runner.registerInfo("Total Exterior Wall Area by story is #{ext_wall_areas} ft2.")

	#Combine objects above into the Summary Characteristics Object (API Version, Location, Building, Stories, Basement, Height, Floor Area, Wall Area)
	return {
	'apiVersion' => "Version 2.0 Draft",
	'referenceStudyPeriod' => ref_study_period,
	'systemBoundary' => sys_bound,
	'location' => location,
	'building' => building,
	'numberOfStoriesAboveGrade' => @numberOfStoriesAboveGrade,
	'basement' => basement_story,
	'buildingHeight' => buildingHeight_ft,
	'conditionedFloorArea' => @conditioned_floor_area,
	'exteriorWallAreas' => ext_wall_areas,
	'numberOfBedrooms' => num_bedrooms, 
	'numberOfBathrooms' => @numberOfbathrooms
	}

end #func

end # class