# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

#####################################
# Walls - calls on material.rb and construction.rb to find assemblies by charactersitics.
#####################################
# Here is what the code should do...
# find each wall surface
# determine its characeteristics
# determine the materials in each layer
# determine the fenestration in the surface
# This process will need to determine the type of insulation, which can be done from the CEC enumerations.

# Get all the Walls model
# @return [Array] returns an array of JSON objects, where
# each object represents a Wall.

def build_walls_array(idf, model, runner, user_arguments, sql)

  walls = [] # Used for the new code, which are the 2nd set of objects reported.
  shared_surface_walls_completed = []

  # ONLY WALL SURFACES - Get each surface and get information from each surface that is a wall. Replicate for other surfaces.
  model.getSurfaces.each do |surf|
    # Skip surfaces that aren't walls (changed the old code to allow for internal walls)
    next unless surf.surfaceType == 'Wall' && surf.outsideBoundaryCondition != 'Ground'

    # Skip surfaces with no construction.
    # Question: If there is no construction should we exclude it or assume basic internal design?
    const = surf.construction
    next if const.empty?

    const = const.get
    # Convert construction base to construction
    const = const.to_Construction.get
    # Get the area
    area_m2 = surf.netArea
    # Area (ft2)
    area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get
    # Get Surface Name
    wall_name = surf.name.get

    # Remove if its determined to be a duplicate wall.
    # Default to not a duplicate wall.
    duplicate = 0

    # Determine if wall shares plane with another surface. If so, then must skip the
    if surf.outsideBoundaryCondition == 'Surface'
      # Find the wall name that is the outside boundary condition object.
      shared_wall = surf.adjacentSurface.get.name.to_s
      # check to see if the outside boundary condition object is already in the "completed" list.
      shared_surface_walls_completed.each do |sswc|
        if shared_wall == sswc
          duplicate = 1
          runner.registerInfo("#{wall_name} is a shared surface with #{sswc}, which is already accounted for. Wall is skipped.")
        end
      end
    end

    # If the wall is the same wall that is already completed (just reversed),
    # then should skip surface to avoid duplication.
    next if duplicate == 1

    # If not a duplicate, add to list of walls completed that outside boundary condition is another surface.
    shared_surface_walls_completed << wall_name if duplicate.zero? and surf.outsideBoundaryCondition == 'Surface'

    # Determine if the surface is an internal or external wall. If its internal, we may have to default the assembly design.
    # Check if the construction has measure tags. If so, then use those. Otherwise interpret the model.
    construction_stds = const.standardsInformation

    if surf.outsideBoundaryCondition == 'Outdoors'
      exterior_adjacent_to = 'AMBIENT'
    elsif surf.outsideBoundaryCondition.include?('Ground') or surf.outsideBoundaryCondition.include?('Foundation')
      exterior_adjacent_to = 'GROUND'
    elsif surf.outsideBoundaryCondition == 'Zone' || surf.outsideBoundaryCondition == 'Adiabatic' || surf.outsideBoundaryCondition == 'Surface'
      exterior_adjacent_to = 'LIVING_SPACE'
    else
      exterior_adjacent_to = 'OTHER_EXTERIOR_ADJACENT_TO'
    end

    # runner.registerInfo("Exterior Adjacent To is #{exterior_adjacent_to}.")

    # find wall height
    wall_z_max = -1_000_000_000
    wall_z_min = 1_000_000_000
    # runner.registerInfo("finding  wall vertices.")
    vertices = surf.vertices
    # runner.registerInfo("found subsurface vertices.")
    vertices.each do |vertex|
      z = vertex.z
      if z < wall_z_min
        wall_z_min = z
      else
        next
      end
      if z > wall_z_max
        wall_z_max = z
      else
      end
    end
    # runner.registerInfo("found max and min z vertices.")
    wall_height_m = wall_z_max - wall_z_min
    # runner.registerInfo("wall height = #{wall_height_m}.")
    # Convert to IP
    wall_height_ft = OpenStudio.convert(wall_height_m, 'm', 'ft').get
    wall_length_ft = area_ft2 / wall_height_ft

    # Get the layers from the construction
    layers = const.layers

    # Find the main structural layer. This is a function in construction.rb created by NREL
    sl_i = const.structural_layer_index
    # runner.registerInfo("sl_i = #{sl_i}.")
    # Skip and warn if we can't find a structural layer
    if sl_i.nil?
      runner.registerInfo("Cannot find structural layer in wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")
      next
    end

    # Find characteristics of the structural layer using Material Standard Information Measure Tags
    # Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
    # These are the tags for the structural layer.
    wall_type = nil

    sli_stds = layers[sl_i].standardsInformation

    category = sli_stds.standardsCategory.get.to_s if sli_stds.standardsCategory.is_initialized
    identifier = sli_stds.standardsIdentifier.get.to_s if sli_stds.standardsIdentifier.is_initialized
    frame_mat = sli_stds.compositeFramingMaterial.get.to_s if sli_stds.compositeFramingMaterial.is_initialized
    if sli_stds.compositeFramingConfiguration.is_initialized
      frame_config = sli_stds.compositeFramingConfiguration.get.to_s
    end
    frame_depth = sli_stds.compositeFramingDepth.get.to_s if sli_stds.compositeFramingDepth.is_initialized
    frame_size = sli_stds.compositeFramingSize.get.to_s if sli_stds.compositeFramingSize.is_initialized
    cavity_ins = sli_stds.compositeCavityInsulation.get.to_i if sli_stds.compositeCavityInsulation.is_initialized

    # Find interior and exterior layer for the construction to define the finishes
    # Layers from exterior to interior
    il_identifier = nil
    el_identifier = nil
    vapor_barrier = 'NO_BARRIER'
    air_barrier = false

    layers.each_with_index do |layer, i|
      # Skip fenestration, partition, and airwall materials
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      if i.zero?
        ext_layer = layer
        el_i_stds = layer.standardsInformation
        el_category = el_i_stds.standardsCategory.get.to_s if el_i_stds.standardsCategory.is_initialized
        el_identifier = el_i_stds.standardsIdentifier.get.to_s if el_i_stds.standardsIdentifier.is_initialized
      else
        int_layer = layer
        il_i_stds = layer.standardsInformation
        il_category = il_i_stds.standardsCategory.get.to_s if il_i_stds.standardsCategory.is_initialized
        il_identifier = il_i_stds.standardsIdentifier.get.to_s if il_i_stds.standardsIdentifier.is_initialized
      end
    end

    # Convert identifiers to interior wall finish and wall siding for exterior walls.
    if exterior_adjacent_to != 'LIVING_SPACE'
      # Interior Wall Finish
      # Category could be Bldg Board and Siding - Limited to gypsum board, otherwise its "other"
      if !il_identifier.nil?
        if il_identifier.include?('Gypsum Board - 1/2 in.') or il_identifier.include?('Gypsum Board - 3/8 in.')
          wall_interior_finish = 'GYPSUM_REGULAR_1_2'
        elsif il_identifier.include?('Gypsum Board - 3/4 in.') or il_identifier.include?('Gypsum Board - 5/8 in.')
          wall_interior_finish = 'GYPSUM_REGULAR_5_8'
        else
          wall_interior_finish = 'OTHER_FINISH'
        end
      else
        wall_interior_finish = 'NONE'
      end

      # Wall Siding - Should be renamed Cladding
      # Category could be Bldg Board and Siding or Plastering Materials or Masonry Materials
      # Currently does not include composite single siding or aluminum siding.
      if !el_identifier.nil? and el_identifier != identifier
        if el_identifier.include?('Fiber cement board')
          wall_siding = 'FIBER_CEMENT_SIDING'
        elsif el_identifier.include?('Fiberboard')
          wall_siding = 'FIBER_CEMENT_SIDING'
        elsif el_identifier.include?('Metal') # Assumes metal is steel. Currently missing aluminum siding
          wall_siding = 'STEEL_SIDING'
        elsif el_identifier.include?('Shingles')
          wall_siding = 'SHINGLES'
        elsif el_identifier.include?('Asphalt')
          wall_siding = 'OTHER_SIDING'
        elsif el_identifier.include?('Wood') and (el_identifier.include?('Siding') or el_identifier.include?('Shingles'))
          wall_siding = 'WOOD_SIDING'
        elsif el_identifier.include?('Synthetic Stucco')
          wall_siding = 'SYNTHETIC_STUCCO'
        elsif el_identifier.include?('Stucco')
          wall_siding = 'STUCCO'
        elsif il_identifier.include?('Hardboard') or il_identifier.include?('HB Part. Brd') or il_identifier.include?('Hard Board')
          wall_siding = 'MASONITE_SIDING'
        elsif el_identifier.include?('Vinyl')
          wall_siding = 'VINYL_SIDING'
        elsif el_identifier.include?('Brick')
          wall_siding = 'BRICK_VENEER'
        elsif el_identifier.include?('Asbestos')
          wall_siding = 'ASBESTOS_SIDING'
        else
          wall_siding = 'OTHER_SIDING'
        end
      else
        wall_siding = 'NONE'
      end
    else
      # Interior Wall Finish for interior wall
      # Category could be Bldg Board and Siding - Limited to gypsum board, otherwise its "other"
      if !il_identifier.nil?
        if il_identifier.include?('Gypsum Board - 1/2 in.') or il_identifier.include?('Gypsum Board - 3/8 in.')
          wall_interior_finish = 'GYPSUM_REGULAR_1_2'
        elsif il_identifier.include?('Gypsum Board - 3/4 in.') or il_identifier.include?('Gypsum Board - 5/8 in.')
          wall_interior_finish = 'GYPSUM_REGULAR_5_8'
        else
          wall_interior_finish = 'OTHER_FINISH'
        end
      else
        wall_interior_finish = 'NONE'
      end
      # runner.registerInfo("Interior Layer = #{wall_interior_finish}.")

      # Wall Siding - Its really just the other side of the interior wall.
      # Since gypsum is not an option for wall siding, need to default to "other siding"
      wall_siding = 'OTHER_SIDING'
      # runner.registerInfo("Wall Siding = #{wall_siding}.")
    end

    # Determine if there is a air barrier or vapor barrier
    layers.each do |layer|
      # Skip fenestration, partition, and airwall materials
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      barrier_stds = layer.standardsInformation
      next unless barrier_stds.standardsCategory.is_initialized

      barrier_category = barrier_stds.standardsCategory.get.to_s
      next unless barrier_category.include?('Building Membrane')

      next unless barrier_stds.standardsIdentifier.is_initialized

      barrier_identifier = barrier_stds.standardsIdentifier.get.to_s
      if barrier_identifier.include?('Vapor') # Should we add custom identifiers?
        vapor_barrier = if barrier_identifier.include?('1/16') # Need to update these values since even 6 mil is too small
                          'POLYETHELYNE_3_MIL'
                        elsif barrier_identifier.include?('1/8')
                          'POLYETHELYNE_3_MIL'
                        elsif barrier_identifier.include?('1/4')
                          'POLYETHELYNE_6_MIL'
                        else
                          'PSK' # Default value
                        end
      else
        air_barrier = true
      end
    end

    # Find the thickness of the surface assembly
    assembly_thickness_m = 0
    assembly_thickness_in = 0
    # sum the thickness of all layers in the assembly
    layers.each do |layer|
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      assembly_thickness_m = assembly_thickness_m + layer.thickness
      assembly_thickness_in = OpenStudio.convert(assembly_thickness_m, 'm', 'in').get
      # runner.registerInfo("assembly thickness = #{assembly_thickness_in}.")
    end
    # runner.registerInfo("Assembly thickness = #{assembly_thickness_in}.")

    # Inialize insulations array here because approach to insulation varies by wall type.
    insulations = []

    # Define wall type based on the measure tags
    # how do we handle uncommon wall types? Group in other for now.
    # missing match for DOUBLE_WOOD_STUD; DOUBLE_WOOD_STUD_STAGGERED; STRUCTURAL_BRICK; STRAW_BALE; STONE; LOG_WALL
    # Currently capture materials for DOUBLE_WOOD_STUD and DOUBLE_WOOD_STUD_STAGGERED by grabbing interior framing and its cavity insulation.
    # Can use Standards Identifier, which is blank for wood framed wall structural layer.

    # WOOD_STUD Wall Type
    if category.to_s.include?('Wood Framed')

      # define the wall type
      wall_type = 'WOOD_STUD'

      # define the framing size
      studs_size = case frame_size
                   when '2x2'
                     '_2X2'
                   when '2x3'
                     '_2X3'
                   when '2x4'
                     '_2X4'
                   when '2x6'
                     '_2X6'
                   when '2x8'
                     '_2X8'
                   when '2x10'
                     '_2X10'
                   when '2x12'
                     '_2X12'
                   when '2x14'
                     '_2X14'
                   when '2x16'
                     '_2X16'
                   else
                     'OTHER_SIZE'
                   end

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer. This would be double stud walls.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_on_center_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              insulations << insulationCav
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # define On Center
      on_center_in = /(\d+)/.match(frame_config).to_s.to_f

      # Define framing cavity thickness
      cav_thickness = case frame_depth
                      when '3_5In'
                        3.5
                      when '5_5In'
                        5.5
                      when '7_25In'
                        7.25
                      when '9_25In'
                        9.25
                      when '11_25In'
                        11.25
                      else
                        nil
                      end

      # define the cavity insulation
      if cavity_ins.nil?
        cav_r_ip = 0
        ins_r_value_per_in = 0
      else
        cav_r_ip = cavity_ins
        ins_r_value_per_in = if not cav_thickness.nil?
                               cav_r_ip / cav_thickness
                             else
                               nil # If this occurs, there is something wrong.
                             end
      end

      # Define the cavity insulation material for wood framing
      # If user defines material in "identifier" then use that; If not then assume fiberglass batt
      if not ins_r_value_per_in.nil?
        if ins_r_value_per_in < 0.1
          ins_mat = 'NONE'
        elsif not identifier.nil?
          identifier = identifier.downcase
          ins_mat = if identifier.include?('glass')
                      'BATT_FIBERGLASS'
                    elsif identifier.include?('cellulose')
                      'LOOSE_FILL_CELLULOSE'
                    elsif identifier.include?('mineral') or identifier.include?('wool') or identifier.include?('rock')
                      'BATT_ROCKWOOL'
                    elsif identifier.include?('spray') or identifier.include?('cell') or identifier.include?('foam')
                      if ins_r_value_per_in < 5
                        'SPRAY_FOAM_OPEN_CELL'
                      elsif ins_r_value_per_in > 5
                        'SPRAY_FOAM_CLOSED_CELL'
                      else
                        'SPRAY_FOAM_UNKNOWN'
                      end
                    else
                      'BATT_FIBERGLASS'
                    end
        else
          ins_mat = 'BATT_FIBERGLASS'
        end
      else
        ins_mat = 'UNKNOWN'
      end

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        insulations << insulationCav
      end

      concrete_value = {}

      clt_values = {}

      # Metal Framed Wall Type
    elsif category.to_s.include?('Metal Framed')
      wall_type = 'STEEL_FRAME'

      # define the framing size
      studs_size = case frame_size
                   when '2x2'
                     '_2X2'
                   when '2x3'
                     '_2X3'
                   when '2x4'
                     '_2X4'
                   when '2x6'
                     '_2X6'
                   when '2x8'
                     '_2X8'
                   when '2x10'
                     '_2X10'
                   when '2x12'
                     '_2X12'
                   when '2x14'
                     '_2X14'
                   when '2x16'
                     '_2X16'
                   else
                     'OTHER_SIZE'
                   end

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # define On Center
      # fc = frame_config.get.downcase
      # runner.registerInfo("OC = #{fc}.")
      on_center_in = /(\d+)/.match(frame_config).to_s.to_f
      # runner.registerInfo("OC = #{on_center_in}.")

      # Define framing cavity thickness
      cav_thickness = case frame_depth
                      when '3_5In'
                        3.5
                      when '5_5In'
                        5.5
                      when '7_25In'
                        7.25
                      when '9_25In'
                        9.25
                      when '11_25In'
                        11.25
                      else
                        nil
                      end
      # runner.registerInfo("Cavity Thickness = #{cav_thickness}.")

      # define the cavity insulation
      if cavity_ins.nil?
        cav_r_ip = 0
        ins_r_value_per_in = 0
      else
        cav_r_ip = cavity_ins
        # runner.registerInfo("Cavity R Value = #{cav_r_ip}.")
        ins_r_value_per_in = if not cav_thickness.nil?
                               cav_r_ip / cav_thickness
                             else
                               nil # If this occurs, there is something wrong.
                             end
      end
      # runner.registerInfo("Cavity Insulation R is #{cav_r_ip}.")
      # runner.registerInfo("Cavity Insulation R per Inch is #{ins_r_value_per_in}.")

      # Define the cavity insulation material for metal framing
      # If user defines material in "identifier" then use that; If not then assume fiberglass batt
      if not ins_r_value_per_in.nil?
        if ins_r_value_per_in < 0.1
          ins_mat = 'NONE'
        elsif not identifier.nil?
          identifier = identifier.downcase
          ins_mat = if identifier.include?('glass')
                      'BATT_FIBERGLASS'
                    elsif identifier.include?('cellulose')
                      'LOOSE_FILL_CELLULOSE'
                    elsif identifier.include?('mineral') or identifier.include?('wool') or identifier.include?('rock')
                      'BATT_ROCKWOOL'
                    elsif identifier.include?('spray') or identifier.include?('cell') or identifier.include?('foam')
                      if ins_r_value_per_in < 5
                        'SPRAY_FOAM_OPEN_CELL'
                      elsif ins_r_value_per_in > 5
                        'SPRAY_FOAM_CLOSED_CELL'
                      else
                        'SPRAY_FOAM_UNKNOWN'
                      end
                    else
                      'BATT_FIBERGLASS'
                    end
        else
          ins_mat = 'BATT_FIBERGLASS'
        end
      else
        ins_mat = 'UNKNOWN'
      end
      # runner.registerInfo("Cavity Insulation  is #{ins_mat}.")

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      clt_values = {}

      # SIPS Wall Type
    elsif category.to_s.include?('SIPS')
      # define the wall type
      wall_type = 'STRUCTURALLY_INSULATED_PANEL'

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # define the framing size; there are no studs for SIPs
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")

      # define On Center
      # fc = frame_config.get.downcase
      # runner.registerInfo("OC = #{fc}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # parse the standard identifier;  eg SIPS - R55 - OSB Spline - 10 1/4 in.

      # find R value of the "cavity" of the SIP
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      sips_r_value_ip = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("SIPS R Value = #{sips_r_value_ip}.")

      # Define framing cavity thickness
      sips_thickness = /(\d+)\s(\d).(\d)/.match(identifier).to_s
      # runner.registerInfo("SIPs insulation thickness = #{sips_thickness}.")
      # assumes 7/16 OSB
      cav_thickness = case sips_thickness
                      when '4 1/2'
                        (4.5 - 0.875)
                      when '6 1/2'
                        (6.5 - 0.875)
                      when '8 1/4'
                        (8.25 - 0.875)
                      when '10 1/4'
                        (10.25 - 0.875)
                      when '12 1/4'
                        (12.25 - 0.875)
                      else
                        nil
                      end
      # runner.registerInfo("SIPS Insulation Thickness = #{cav_thickness}.")

      # define the SIPs insulation
      if sips_r_value_ip.nil?
        cav_r_ip = 0
        ins_r_value_per_in = 0
      else
        cav_r_ip = sips_r_value_ip
        # runner.registerInfo("SIPs R Value = #{cav_r_ip}.")
        ins_r_value_per_in = if not cav_thickness.nil?
                               cav_r_ip / cav_thickness
                             else
                               nil # If this occurs, there is something wrong.
                             end
      end
      # runner.registerInfo("SIPs Insulation R is #{cav_r_ip}.")
      # runner.registerInfo("SIPs Insulation R per Inch is #{ins_r_value_per_in}.")

      # Assume rigid insulation for SIPs; are there others to include?
      ins_mat = if not ins_r_value_per_in.nil?
                  if ins_r_value_per_in < 0.1
                    'NONE'
                  elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
                    'RIGID_EPS'
                  elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
                    'RIGID_XPS'
                  elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
                    'RIGID_POLYISOCYANURATE'
                  else
                    'RIGID_UNKNOWN'
                  end
                else
                  'UNKNOWN'
                end
      # runner.registerInfo("SIPs Insulation is #{ins_mat}.")

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      clt_values = {}

    elsif category.to_s.include?('Concrete') and not category.to_s.include?('Sandwich Panel')
      wall_type = 'SOLID_CONCRETE'

      # define structural framing specs.
      # Since structural layer is concrete, there is no framing information.
      studs_size = nil
      on_center_in = nil

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # solid concrete will not have framing in the structural layer
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # Define concrete thickness
      concrete_thickness = /(\d+)\sin/.match(identifier).to_s
      # runner.registerInfo("Concrete thickness string = #{concrete_thickness}.")
      cav_thickness = case concrete_thickness
                      when '6 in'
                        6
                      when '8 in'
                        8
                      when '10 in'
                        10
                      when '12 in'
                        12
                      else
                        nil
                      end
      # runner.registerInfo("Concrete Thickness = #{cav_thickness}.")

      # Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

      # Masonry Unit Walls - Assume concrete; ignores clay masonry; excludes block fill
    elsif category.to_s.include?('Masonry Units')
      wall_type = 'CONCRETE_MASONRY_UNIT'

      # Provide details on the masonry fill; currently not used for anything.
      wall_fill_unused = if category.to_s.include?('Hollow')
                           'HOLLOW'
                         elsif category.to_s.include?('Solid')
                           'SOLID'
                         elsif category.to_s.include?('Fill')
                           'FILL'
                         else
                           'UNKNOWN'
                         end

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # ICF wall will not have framing or cavity insulation within the material
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # Define thickness of the block
      cmu_thickness = /(\d+)\sin/.match(identifier).to_s
      # runner.registerInfo("CMU thickness string = #{cmu_thickness}.")
      cav_thickness = case cmu_thickness
                      when '6 in'
                        6
                      when '8 in'
                        8
                      when '10 in'
                        10
                      when '12 in'
                        12
                      else
                        nil
                      end
      # runner.registerInfo("CMU Thickness = #{cav_thickness}.")

      ins_mat = 'NONE'
      # runner.registerInfo("Cavity Insulation  is #{ins_mat}.")
      # Currently creating the cavity insulation object, but could be deleted.
      # TO DO: How do we handle framing on the inside of the concrete wall?
      cav_r_ip = 0
      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      # Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

    elsif category.to_s.include?('ICF')
      wall_type = 'INSULATED_CONCRETE_FORMS'

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # solid concrete will not have framing or cavity insulation within the material
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # Insulating Concrete Forms - 1 1/2 in. Polyurethane Ins. each side - concrete 8 in.
      # Define thickness of the concrete
      concrete_thickness = /(\d+)\sin/.match(identifier).to_s
      # runner.registerInfo("ICF thickness string = #{concrete_thickness}.")
      cav_thickness = case concrete_thickness
                      when '6 in'
                        6
                      when '8 in'
                        8
                      else
                        nil
                      end
      # runner.registerInfo("Concrete Thickness = #{cav_thickness}.")

      # define the ICF insulation type
      icf_ins = identifier.to_s
      # runner.registerInfo("ICF String = #{icf_ins}.")

      if identifier.to_s.include?('XPS')
        ins_mat = 'RIGID_XPS'
        ins_r_value_per_in = 5.0
      elsif identifier.to_s.include?('EPS')
        ins_mat = 'RIGID_EPS'
        ins_r_value_per_in = 4.6
      elsif identifier.to_s.include?('Polyurethane')
        ins_mat = 'SPRAY_FOAM_CLOSED_CELL'
        ins_r_value_per_in = 6.5
      elsif identifier.to_s.include?('Polyiso')
        ins_mat = 'RIGID_POLYISOCYANURATE'
        ins_r_value_per_in = 5.8
      else
        ins_mat = 'UNKNOWN'
        ins_r_value_per_in = 0
      end
      # runner.registerInfo("ICF Insulation is #{ins_mat}.")
      # runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")

      # define the ICF insulation thickness; concrete is always thicker than the insulation
      cav_thickness = if identifier.to_s.include?('1 1/2 in.')
                        1.5
                      elsif identifier.to_s.include?('2 in.')
                        2
                      elsif identifier.to_s.include?('2 1/2 in.')
                        2.5
                      elsif identifier.to_s.include?('3 in.')
                        3
                      elsif identifier.to_s.include?('4 in.')
                        4
                      elsif identifier.to_s.include?('4 1/2 in.')
                        4.5
                      else
                        nil
                      end
      # runner.registerInfo("ICF Thickness = #{cav_thickness}.")
      cav_r_ip = cav_thickness * ins_r_value_per_in
      # runner.registerInfo("ICF Insulation R Value = #{cav_r_ip}.")

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      ##Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

      # Concrete Sandwich Panel Walls; matched to ICF because the material take-off approach is the same
    elsif category.to_s.include?('Concrete Sandwich Panel')
      wall_type = 'INSULATED_CONCRETE_FORMS'

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # solid concrete will not have framing or cavity insulation within the material
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # Concrete Sandwich Panel - 100% Ins. Layer - No Steel in Ins. - Ins. 1 1/2 in.
      # Concrete Sandwich Panel - 100% Ins. Layer - Steel in Ins. - Ins. 1 1/2 in.
      # Concrete Sandwich Panel - 90% Ins. Layer - No Steel in Ins. - Ins. 2 in.

      # Define thickness of the concrete
      concrete_thickness = 3 * 2 # Defaulted to 3 in wythes of concrete

      # define the CSP insulation thickness
      ins_thickness = if identifier.to_s.include?('1 1/2 in.')
                        1.5
                      elsif identifier.to_s.include?('2 in.')
                        2
                      elsif identifier.to_s.include?('3 in.')
                        3
                      elsif identifier.to_s.include?('4 in.')
                        4
                      elsif identifier.to_s.include?('5 in.')
                        5
                      elsif identifier.to_s.include?('6 in.')
                        6
                      else
                        nil
                      end
      # runner.registerInfo("Insulation Thickness = #{ins_thickness}.")

      # define the ICF insulation type and R value
      ins_mat = 'RIGID_EPS'
      ins_r_value_per_in = 5
      # runner.registerInfo("ICF Insulation is #{ins_mat}.")
      # runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")

      # Calculate total Cavity R value
      cav_r_ip = ins_thickness * ins_r_value_per_in
      # runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")

      # calculate structural layer thickness
      cav_thickness = concrete_thickness + ins_thickness

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      # Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

      # Metal Insulated Panel Walls; metal SIPs
    elsif category.to_s.include?('Metal Insulated Panel Wall')
      wall_type = 'STRUCTURALLY_INSULATED_PANEL'

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # metal insulated panels will not have framing or cavity insulation within the material
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # Metal Insulated Panels - 2 1/2 in.
      # metal is assumed to be 26 gauge steel at 0.02 in thick for a total of 0.04 in of steel.
      # Currently assume metal thickness is additional to defined thickness

      # define the panel thickness
      cav_thickness = if identifier.to_s.include?('2 in.')
                        2
                      elsif identifier.to_s.include?('2 1/2 in.')
                        2.5
                      elsif identifier.to_s.include?('3 in.')
                        3
                      elsif identifier.to_s.include?('4 in.')
                        4
                      elsif identifier.to_s.include?('5 in.')
                        5
                      elsif identifier.to_s.include?('6 in.')
                        6
                      else
                        nil
                      end
      # runner.registerInfo("Insulation Thickness = #{cav_thickness}.")

      # define the insulation type and R value; assume EPS at R-5/in
      ins_mat = 'RIGID_EPS'
      ins_r_value_per_in = 5
      # runner.registerInfo("Metal Panel Wall Insulation is #{ins_mat}.")
      # runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")

      # Calculate total Cavity R value
      cav_r_ip = cav_thickness * ins_r_value_per_in
      # runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      clt_values = {}

      # Cross Laminated Timber (CLT) Walls - does not include any insulation.
      # User must manually add a standards category and standards identifier
      # Category = CLT; Identifier Format = X in. 50/75/100 psf Live Load
      # Question: How do we handle insulation within the CLT layers? Add it to the format?
    elsif category.to_s.include?('CLT') or category.to_s.include?('Cross Laminated Timber') or category.to_s.include?('Woods') # not a tag option at the moment
      wall_type = 'CROSS_LAMINATED_TIMBER'

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      # define the framing size; there are no studs for CLTs
      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")

      # define On Center
      # fc = frame_config.get.downcase
      # runner.registerInfo("OC = #{fc}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      # parse the standard identifier;  eg CLT - 2x4 - 3 Layers

      # find R value of the "cavity" of the SIP
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      live_load = 50
      live_load = /(\d+)\spsf/.match(identifier).to_s.to_f if not category.nil?
      # runner.registerInfo("Live Load = #{live_load}.")

      # Define framing cavity thickness
      clt_thickness = /(\d+)\sin./.match(identifier).to_s
      # runner.registerInfo("CLT thickness = #{clt_thickness}.")
      value, unit = clt_thickness.split(' ')
      cav_thickness = value.to_f
      # runner.registerInfo("CLT Thickness = #{cav_thickness}.")

      cav_r_ip = 0
      ins_r_value_per_in = 0
      ins_r_value_per_in = 0
      ins_mat = 'NONE'

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      # Define supported span using wall length and stories - defaulted to 1 for residential
      supported_span = wall_length_ft # equal to the width of the wall; what is the max span?
      supported_stories = 1 # assume 1 story for residential.

      # Define supported element
      clt_supported_element_type = 'ROOF' # if surface is first floor then assume "floor", if 2nd floor assume "roof"

      clt_values = {
        'liveLoad' => live_load, # kPa
        'supportedSpan' => supported_span, # the length of wall unless it exceeds the maximum
        'supportedElementType' => clt_supported_element_type,
        'supportedStories' => supported_stories
      }

    else
      # Includes Spandrel Panels Curtain Walls and straw bale wall;
      wall_type = 'OTHER_WALL_TYPE'
      # define the framing size; there are no studs for SIPs

      # Find the interior wall framing specs, including insulation if it exists.
      # Check for framing that is inside the structural layer.
      # Cavity insulation is included in the wall object, but is calculated by IE4B as continuous
      # wall object is created for only the wall framing (no insulation or interior or exterior layers)

      int_studs_size = nil
      int_frame_mat = nil
      int_on_center_in = nil
      int_ins_mat = nil
      int_ins_r = nil
      int_ins_r_per_in = nil
      int_ins_thickness = nil
      int_wall_type = nil

      layers.each_with_index do |layer, i|
        # Skip fenestration, partition, and airwall materials
        layer = layer.to_OpaqueMaterial
        next if layer.empty?

        layer = layer.get
        # runner.registerInfo("layer = #{layer}.")
        # Check if layer is interior to the structural layer (i starts on the outside and works in)
        next unless i > sl_i

        int_frame_stds = layer.standardsInformation
        if int_frame_stds.standardsCategory.is_initialized
          int_frame_category = int_frame_stds.standardsCategory.get.to_s
          if int_frame_category.include?('Framed')
            # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
            # Find framing material (WOOD or METAL)
            if int_frame_stds.compositeFramingMaterial.is_initialized
              int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
              int_frame_mat = int_frame_mat.upcase
              int_wall_type = if int_frame_mat == 'METAL'
                                'STEEL_FRAME'
                              else
                                'WOOD_STUD'
                              end
            else
              int_frame_mat = 'WOOD'
              int_wall_type = 'WOOD_STUD'
            end
            # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")
            # runner.registerInfo("Interior Framing Wall Type = #{int_wall_type}.")

            # Find OC
            if int_frame_stds.compositeFramingConfiguration.is_initialized
              frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
              int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
            else
              int_on_center_in = 16
            end
            # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

            # Find frame size
            if int_frame_stds.compositeFramingSize.is_initialized
              frame_size = int_frame_stds.compositeFramingSize.get.to_s
              case frame_size
              when '2x4'
                int_studs_size = '_2X4'
                int_ins_thickness = 3.5
              when '2x6'
                int_studs_size = '_2X6'
                int_ins_thickness = 5.5
              when '2x8'
                int_studs_size = '_2X8'
                int_ins_thickness = 7.25
              else
                int_studs_size = 'OTHER_SIZE'
              end
            else
              int_studs_size = '_2x4'
              int_ins_thickness = 3.5
            end
            # runner.registerInfo("Studs Size = #{int_studs_size}.")
            # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

            # Find cavity insulation R-value
            if int_frame_stds.compositeCavityInsulation.is_initialized
              int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
              if int_ins_r.positive? and int_ins_thickness.positive?
                int_ins_r_per_in = int_ins_r / int_ins_thickness
              else
                int_ins_r = 0
                int_ins_r_per_in = 0
              end
            else
              int_ins_r = 0
              int_ins_r_per_in = 0
            end
            # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
            # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

            # Find cavity insulation material
            if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
              int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
              int_frame_identifier = int_frame_identifier.downcase
              if int_frame_identifier.include?('cellulose')
                int_ins_mat = 'LOOSE_FILL_CELLULOSE'
              elsif int_frame_identifier.include?('glass')
                int_ins_mat = 'BATT_FIBERGLASS'
              elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
                int_ins_mat = 'BATT_ROCKWOOL'
              elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
                int_ins_mat = if int_ins_r > 5
                                'SPRAY_FOAM_CLOSED_CELL'
                              elsif int_ins_r < 5
                                'SPRAY_FOAM_OPEN_CELL'
                              else
                                'SPRAY_FOAM_UNKNOWN'
                              end
              else
                int_ins_mat = 'BATT_FIBERGLASS'
              end
            elsif int_ins_r.positive? and int_ins_thickness.positive?
              int_ins_mat = 'BATT_FIBERGLASS'
            else
              int_ins_mat = nil
            end
            # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

            # Add insulation to insulations array.
            if int_ins_r.positive?
              insulationCav = {
                'insulationMaterial' => int_ins_mat,
                'insulationThickness' => int_ins_thickness,
                'insulationNominalRValue' => int_ins_r,
                'insulationInstallationType' => 'CAVITY',
                'insulationLocation' => 'INTERIOR'
              }
              # runner.registerInfo("Cavity Insulation = #{insulationCav}")
              insulations << insulationCav
              # runner.registerInfo("Foundation Wall Insulations = #{insulations}")
            end

          end
        else
          # Default to nil (no framing found)
          int_frame_mat = nil
          int_on_center_in = nil
          int_studs_size = nil
          int_ins_mat = nil
          int_ins_r = nil
        end
      end

      studs_size = nil
      # runner.registerInfo("Studs Size = #{studs_size}.")

      # define On Center
      # fc = frame_config.get.downcase
      # runner.registerInfo("OC = #{fc}.")
      on_center_in = nil
      # runner.registerInfo("OC = #{on_center_in}.")

      cav_r_ip = 0
      ins_r_value_per_in = 0
      ins_r_value_per_in = 0
      ins_mat = 'NONE'

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      clt_values = {}

    end

    # Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
    # Use structural layer as base to find other insulation.
    # runner.registerInfo("sl_i = #{sl_i}.")
    layers.each_with_index do |layer, i|
      # Skip fenestration, partition, and airwall materials
      ins_mat = nil
      ins_thickness = nil
      ins_r_val_ip = nil
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      # runner.registerInfo("layer = #{layer}.")
      # if side == 'interior'
      # All layers inside (after) the structural layer
      #	next unless i > struct_layer_i
      if i != sl_i
        # runner.registerInfo("Layer is not Structural Layer. checking for insulation")
        if layer.nist_is_insulation
          # identify insulation material, thickness, and r-value using standard information
          ins_stds = layer.standardsInformation
          # If standard information is available, use to define insulation.
          if ins_stds.standardsCategory.is_initialized and ins_stds.standardsIdentifier.is_initialized
            ins_category = ins_stds.standardsCategory.get.to_s
            ins_category = ins_category.downcase
            ins_identifier = ins_stds.standardsIdentifier.get.to_s
            ins_identifier = ins_identifier.downcase
            # runner.registerInfo("Insulation Layer Category = #{ins_category}.")
            # runner.registerInfo("Insulation Layer Identifier = #{ins_identifier}.")

            # identify insulation thickness
            # If "compliance" insulation, then thickness is calculated later.
            ins_thickness = if !ins_identifier.nil? and ins_category.include?('insulation')
                              if ins_identifier.include?('- 1/8 in.')
                                0.125
                              elsif ins_identifier.include?('- 1/4 in.')
                                0.25
                              elsif ins_identifier.include?('- 1/2 in.')
                                0.5
                              elsif ins_identifier.include?('1 in.')
                                1.0
                              elsif ins_identifier.include?('1 1/2 in.')
                                1.5
                              elsif ins_identifier.include?('2 in.')
                                2.0
                              elsif ins_identifier.include?('2 1/2 in.')
                                2.5
                              elsif ins_identifier.include?('3 in.')
                                3.0
                              elsif ins_identifier.include?('3 1/2 in.')
                                3.5
                              elsif ins_identifier.include?('4 in.')
                                4.0
                              elsif ins_identifier.include?('4 1/2 in.')
                                4.5
                              elsif ins_identifier.include?('5 in.')
                                5.0
                              elsif ins_identifier.include?('5 1/2 in.')
                                5.5
                              elsif ins_identifier.include?('6 in.')
                                6.0
                              elsif ins_identifier.include?('6 1/2 in.')
                                6.5
                              elsif ins_identifier.include?('7 in.')
                                7.0
                              elsif ins_identifier.include?('7 1/4 in.')
                                7.25
                              elsif ins_identifier.include?('7 1/2 in.')
                                7.5
                              elsif ins_identifier.include?('8 in.')
                                8.0
                              elsif ins_identifier.include?('8 1/4 in.')
                                8.25
                              elsif ins_identifier.include?('8 1/2 in.')
                                8.5
                              elsif ins_identifier.include?('9 in.')
                                9.0
                              elsif ins_identifier.include?('9 1/2 in.')
                                9.5
                              elsif ins_identifier.include?('10 in.')
                                10.0
                              elsif ins_identifier.include?('11 in.')
                                11.0
                              elsif ins_identifier.include?('12 in.')
                                12.0
                              else
                                nil
                              end
                              # runner.registerInfo("Insulation Thickness is #{ins_thickness}.")
                            else
                              nil
                              # runner.registerInfo("Insulation Thickness is missing.")
                            end

            # identify insulation r-value
            if !ins_identifier.nil? and ins_identifier.include?('r')
              ins_r_string = /r(\d+)/.match(ins_identifier).to_s
              ins_r_val_ip = /(\d+)/.match(ins_r_string).to_s.to_f
            elsif ins_category.include?('spray')
              if ins_identifier.include?('urethane')
                if ins_identifier.include?('3.0 lb/ft3')
                  ins_r_val_ip = ins_thickness * 6.3
                elsif ins_identifier.include?('0.5 lb/ft3')
                  ins_r_val_ip = ins_thickness * 3.7
                end
              elsif ins_identifier.include?('cellulosic')
                ins_r_val_ip = ins_thickness * 3.7
              elsif ins_identifier.include?('glass')
                ins_r_val_ip = ins_thickness * 3.7
              end
            elsif not layer.thermalConductivity.nil? and not layer.thickness.nil?
              layer_conductivity = layer.thermalConductivity.to_s.to_f
              layer_thickness_m = layer.thickness.to_s.to_f
              ins_r_val_ip = layer_thickness_m / layer_conductivity * 5.678
            else
              ins_r_val_ip = nil
            end
            # runner.registerInfo("Insulation R is #{ins_r_val_ip}.")

            # identify insulation material
            if ins_category.include?('insulation board')
              if !ins_identifier.nil?
                if ins_identifier.include?('polyiso')
                  ins_mat = 'RIGID_POLYISOCYANURATE'
                elsif ins_identifier.include?('xps')
                  ins_mat = 'RIGID_XPS'
                elsif ins_identifier.include?('compliance')
                  ins_mat = 'RIGID_XPS'
                  ins_thickness = ins_r_val_ip / 5.0 # must define thickness for compliance insulation
                elsif ins_identifier.include?('eps')
                  ins_mat = 'RIGID_EPS'
                elsif ins_identifier.include?('urethane')
                  ins_mat = 'SPRAY_FOAM_CLOSED_CELL' # R-values for CBES materials match closed cell
                else
                  ins_mat = 'RIGID_UNKNOWN'
                end
              else
                ins_mat = 'RIGID_UNKNOWN'
              end
            elsif ins_category.include?('insulation')
              # runner.registerInfo("Non-board Insulation found on top of attic floor.")
              ins_identifier = ins_identifier.downcase
              ins_mat = if !ins_identifier.nil?
                          if ins_identifier.include?('loose fill')
                            'LOOSE_FILL_CELLULOSE'
                          elsif ins_identifier.include?('cellulosic fiber')
                            'LOOSE_FILL_CELLULOSE'
                          elsif ins_identifier.include?('batt')
                            'BATT_FIBERGLASS'
                          elsif ins_identifier.include?('glass fiber')
                            'LOOSE_FILL_FIBERGLASS'
                          elsif ins_identifier.include?('spray') and ins_identifier.include?('4.6 lb/ft3')
                            'SPRAY_FOAM_CLOSED_CELL'
                          elsif ins_identifier.include?('spray') and ins_identifier.include?('3.0 lb/ft3')
                            'SPRAY_FOAM_CLOSED_CELL'
                          elsif ins_identifier.include?('spray') and ins_identifier.include?('0.5 lb/ft3')
                            'SPRAY_FOAM_OPEN_CELL'
                          else
                            'UNKNOWN'
                          end
                        else
                          'UNKNOWN'
                        end
            else
              ins_mat = nil
              # runner.registerInfo("No Insulation Material found.")
            end
            # runner.registerInfo("Insulation Material is #{ins_mat}.")
            # If no standard information is available, use the layer performance specs (thickness and thermal resistance to match insulation material)
            # Currently only considers rigid insulation.
          elsif not layer.thickness.nil? and not layer.thermalResistance.nil?
            ins_thickness_m = layer.thickness.to_f
            ins_thickness = OpenStudio.convert(ins_thickness_m, 'm', 'in').get
            ins_r_val_si = layer.thermalResistance.to_f
            ins_r_val_ip = OpenStudio.convert(r_val_si, "m^2*K/W", "ft^2*h*R/Btu").get
            ins_r_value_per_in = ins_r_val_ip / ins_thickness
            ins_mat = if ins_r_value_per_in < 0.1
                        'NONE'
                      elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
                        'RIGID_EPS'
                      elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
                        'RIGID_XPS'
                      elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
                        'RIGID_POLYISOCYANURATE'
                      else
                        'RIGID_UNKNOWN'
                      end
            # If a failure occurs above, then provide nil values.
          else
            ins_mat = nil
            ins_thickness = nil
            ins_r_val_ip = nil
            # runner.registerInfo("No Insulation Material found.")
          end
          # Populate the correct insulation object (interior or exterior)
          # runner.registerInfo("Insulation Specs: #{ins_mat},#{ins_thickness},#{ins_r_val_ip}.")
          if i > sl_i
            # add interior insulation to insulations
            insulationInt = {
              'insulationMaterial' => ins_mat,
              'insulationThickness' => ins_thickness.round(1),
              'insulationNominalRValue' => ins_r_val_ip.round(1),
              'insulationInstallationType' => 'CONTINUOUS',
              'insulationLocation' => 'INTERIOR'
            }
            # runner.registerInfo("Insulation = #{insulationInt}")
            insulations << insulationInt
          elsif i < sl_i
            # add exterior insulation to insulations
            insulationExt = {
              'insulationMaterial' => ins_mat,
              'insulationThickness' => ins_thickness.round(1),
              'insulationNominalRValue' => ins_r_val_ip.round(1),
              'insulationInstallationType' => 'CONTINUOUS',
              'insulationLocation' => 'EXTERIOR'
            }
            # runner.registerInfo("Insulation = #{insulationExt}")
            insulations << insulationExt
          else
            # runner.registerInfo("Layer was not added as Insulation.")
          end
        else
          # runner.registerInfo("Layer not insulation")
        end
      end
    end

    # Need to find all subsurfaces on a wall surface and determine which are windows and doors.
    # Then pull the information for each to add to the array.
    # This will require a do loop through each wall surface.
    windows = []
    doors = []

    # if subsurface is a window, then populate the window object.
    # Only need to populate the physical components or the performance specs. Use performance specs from OSM.
    # Can I pull this info from OSM or do I have to go through each E+ window object, match the surface name, and pull specs?

    # runner.registerInfo("finding all windows in this surface.")
    surf.subSurfaces.each do |ss|
      # if ss is a window, else its a door.
      # runner.registerInfo("found subsurface.")
      subsurface_type = ss.subSurfaceType
      # runner.registerInfo("found subsurface type: #{subsurface_type}.")
      # Determine if the subsurface is a window or door or other
      # This is determined by Spaces - Subsurfaces type
      # Could also be done using the construction details.
      case subsurface_type
      when 'FixedWindow', 'OperableWindow'
        # Determine operability
        operable = case subsurface_type
                   when 'FixedWindow'
                     false
                   when 'OperableWindow'
                     true
                   else
                     false
                   end
        window_name = ss.name
        # runner.registerInfo("found subsurface #{window_name}.")
        window_area_m2 = ss.grossArea
        # runner.registerInfo("found subsurface #{window_name} with area #{window_area}.")
        window_area_ft2 = OpenStudio.convert(window_area_m2, 'm^2', 'ft^2').get
        window_z_max = -1_000_000_000
        window_z_min = 1_000_000_000
        # runner.registerInfo("finding subsurface vertices.")
        vertices = ss.vertices
        # runner.registerInfo("found subsurface vertices.")
        vertices.each do |vertex|
          z = vertex.z
          if z < window_z_min
            window_z_min = z
          else
            next
          end
          if z > window_z_max
            window_z_max = z
          else
          end
        end
        # runner.registerInfo("found max and min z vertices.")
        window_height_m = window_z_max - window_z_min
        # runner.registerInfo("window height = #{window_height_m}.")
        # Convert to IP
        window_height_ft = OpenStudio.convert(window_height_m, 'm', 'ft').get

        # Use construction standards for subsurface to find window characteristics
        # Default all the characteristics to NONE
        frame_type = 'NONE_FRAME_TYPE'
        glass_layer = 'NONE_GLASS_LAYERS'
        glass_type = 'NONE_GLASS_TYPE'
        gas_fill = 'NONE_GAS_FILL'

        # Find the construction of the window
        sub_const = ss.construction
        next if sub_const.empty?

        sub_const = sub_const.get
        # Convert construction base to construction
        sub_const = sub_const.to_Construction.get
        # runner.registerInfo("Window Construction is #{sub_const}.")
        # Check if the construction has measure tags.
        sub_const_stds = sub_const.standardsInformation
        # runner.registerInfo("Window Const Stds Info is #{sub_const_stds}.")

        # Find number of panes. Does not account for storm windows. Quad panes is not in enumerations.
        if sub_const_stds.fenestrationNumberOfPanes.is_initialized
          number_of_panes = sub_const_stds.fenestrationNumberOfPanes.get.downcase.to_s
          glass_layer = if number_of_panes.include?('single')
                          'SINGLE_PANE'
                        elsif number_of_panes.include?('double')
                          'DOUBLE_PANE'
                        elsif number_of_panes.include?('triple')
                          'TRIPLE_PANE'
                        elsif number_of_panes.include?('quadruple')
                          'MULTI_LAYERED'
                        elsif number_of_panes.include?('glass block')
                          'NONE_GLASS_LAYERS'
                        else
                          'NONE_GLASS_LAYERS'
                        end
        end
        # runner.registerInfo("Glass Layers = #{glass_layer}.")

        # Find frame type. Does not account for wood, aluminum, vinyl, or fiberglass.
        if sub_const_stds.fenestrationFrameType.is_initialized
          os_frame_type = sub_const_stds.fenestrationFrameType.get.downcase.to_s
          frame_type = if os_frame_type.include?('non-metal')
                         'COMPOSITE'
                       elsif os_frame_type.include?('metal framing thermal')
                         'METAL_W_THERMAL_BREAK'
                       elsif os_frame_type.include?('metal framing')
                         'METAL'
                       else
                         'NONE_FRAME_TYPE'
                       end
        end
        # runner.registerInfo("Frame Type = #{frame_type}.")

        # Find tint and low e coating. Does not account for reflective.
        os_low_e = sub_const_stds.fenestrationLowEmissivityCoating
        # runner.registerInfo("low e = #{os_low_e}.")
        if sub_const_stds.fenestrationTint.is_initialized
          os_tint = sub_const_stds.fenestrationTint.get.downcase.to_s
          if os_low_e == true
            glass_type = 'LOW_E'
          else
            if os_tint.include?('clear')
              glass_type = 'NONE_GLASS_TYPE'
            elsif os_tint.include?('tinted') or os_tint.include?('green') or os_tint.include?('blue') or os_tint.include?('grey') or os_tint.include?('bronze')
              glass_type = 'TINTED'
            else
              glass_type = 'NONE_GLASS_TYPE'
            end
          end
        elsif not sub_const_stds.fenestrationTint.is_initialized
          glass_type = if os_low_e == true
                         'LOW_E'
                       else
                         'NONE_GLASS_TYPE'
                       end
        end
        # runner.registerInfo("Glass Type = #{glass_type}.")

        # Find gas fill. Enumerations missing krypton - matches to argon.
        if sub_const_stds.fenestrationGasFill.is_initialized
          os_gas_fill = sub_const_stds.fenestrationGasFill.get.downcase.to_s
          gas_fill = if os_gas_fill.include?('air')
                       'AIR'
                     elsif os_gas_fill.include?('argon') or os_tint.include?('krypton')
                       'ARGON'
                     else
                       'NONE_GAS_FILL'
                     end
        end
        # runner.registerInfo("Gas Fill = #{gas_fill}.")

        # Take window name and use it to find the specs.
        # Parse the window name, upcase the letters, and then put back together. The periods are causing the problem.
        window_name_string = window_name.to_s
        # runner.registerInfo("window name now string: #{window_name_string}.")
        window_name_capped = window_name_string.upcase
        # runner.registerInfo("window name capped: #{window_name_capped}.")
        # query the SQL file including the row name being a variable. Treat like its in a runner.
        # U-Factor Query
        query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass U-Factor'
				  AND RowName='#{window_name_capped}'
				  AND Units='W/m2-K'"
        # runner.registerInfo("Query is #{query}.")
        u_si = sql.execAndReturnFirstDouble(query)
        # runner.registerInfo("U-SI value was found: #{u_si}.")
        u_si = if u_si.is_initialized
                 u_si.get
               else
                 0
               end
        u_ip = OpenStudio.convert(u_si, 'W/m^2*K', 'Btu/hr*ft^2*R').get
        # SHGC Query
        query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass SHGC'
				  AND RowName='#{window_name_capped}'"
        # runner.registerInfo("Query is #{query}.")
        shgc = sql.execAndReturnFirstDouble(query)
        # runner.registerInfo("SHGC value was found: #{shgc}.")
        shgc = if shgc.is_initialized
                 shgc.get
               else
                 0
               end

        # VT Query
        query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass Visible Transmittance'
				  AND RowName='#{window_name_capped}'"
        # runner.registerInfo("Query is #{query}.")
        vt = sql.execAndReturnFirstDouble(query)
        # runner.registerInfo("U-SI value was found: #{vt}.")
        vt = if vt.is_initialized
               vt.get
             else
               0
             end

        window = {
          'name' => window_name,
          'operable' => operable,
          'area' => window_area_ft2.round(2),
          'height' => window_height_ft.round(2), # TO DO  - need to add to enumerations
          'quantity' => 1, # Hard coded until we introduce Construction Fenstration Information option
          'frameType' => frame_type,
          'glassLayer' => glass_layer,
          'glassType' => glass_type,
          'gasFill' => gas_fill,
          'shgc' => shgc.round(4),
          'visualTransmittance' => vt.round(4),
          'uFactor' => u_ip.round(4)
        }
        # runner.registerInfo("Window = #{window}")
        windows << window

        # if subsurface is a door, then populate the door object.
        # Question: Can we use the U value to guess the material?
      when 'Door', 'GlassDoor'
        # Determine door type
        door_type = 'EXTERIOR'
        door_mat = runner.getStringArgumentValue('door_mat', user_arguments)
        door_material = nil
        # TODO: finalize the percent glazing values
        case door_mat
        when 'Solid Wood'
          pct_glazing = 0.0
          door_material = 'SOLID_WOOD'
        when 'Glass'
          pct_glazing = 0.99
          door_material = 'GLASS'
        when 'Uninsulated Fiberglass'
          pct_glazing = 0.00
          door_material = 'UNINSULATED_FIBERGLASS'
        when 'Insulated Fiberglass'
          pct_glazing = 0.00
          door_material = 'INSULATED_FIBERGLASS'
        when 'Uninsulated Metal (Aluminum)'
          pct_glazing = 0.00
          door_material = 'UNINSULATED_METAL_ALUMINUM'
        when 'Insulated Metal (Aluminum)'
          pct_glazing = 0.00
          door_material = 'INSULATED_METAL_ALUMINUM'
        when 'Uninsualted Metal (Steel)'
          pct_glazing = 0.00
          door_material = 'UNINSULATED_METAL_STEEL'
        when 'Insulated Metal (Steel)'
          pct_glazing = 0.00
          door_material = 'INSULATED_METAL_STEEL'
        when 'Hollow Wood'
          pct_glazing = 0.00
          door_material = 'HOLLOW_WOOD'
        when 'Other'
          pct_glazing = 0.00
          door_material = 'NONE'
        end
        door_name = ss.name
        # runner.registerInfo("found subsurface #{door_name}.")
        door_area_m2 = ss.grossArea
        # runner.registerInfo("found subsurface #{window_name} with area #{window_area}.")
        door_area_ft2 = OpenStudio.convert(door_area_m2, 'm^2', 'ft^2').get
        door_z_max = -1_000_000_000
        door_z_min = 1_000_000_000
        # runner.registerInfo("finding subsurface vertices.")
        vertices = ss.vertices
        # runner.registerInfo("found subsurface vertices.")
        vertices.each do |vertex|
          z = vertex.z
          if z < door_z_min
            door_z_min = z
          else
            next
          end
          if z > door_z_max
            door_z_max = z
          else
          end
        end
        # runner.registerInfo("found max and min z vertices.")
        door_height_m = door_z_max - door_z_min
        # runner.registerInfo("door height = #{door_height_m}.")
        # Convert to IP
        door_height_ft = OpenStudio.convert(door_height_m, 'm', 'ft').get
        door = {
          'name' => door_name, ###STOPPING POINT
          'type' => door_type,
          'material' => door_material,
          'percentGlazing' => pct_glazing,
          'area' => door_area_ft2.round(2),
          'height' => door_height_ft.round(2), # Needs to be added to enumerations
          'quantity' => 1 # Defaulted to 1 because we report each individually. Should we remove?
        }
        # runner.registerInfo("Door = #{door}")
        doors << door
      else
        runner.registerInfo("subsurface type is not a window or door and will be skipped: #{subsurface_type}.")
      end
    end

    # Populate the surface object
    # runner.registerInfo("Creating Wall object.")
    wall = {
      'wallName' => wall_name,
      'wallType' => wall_type, # TODO: need to complete search for all wall types; some are not supported by tags
      'wallThickness' => assembly_thickness_in.round(2),
      'exteriorAdjacentTo' => exterior_adjacent_to,
      'wallSiding' => wall_siding,
      'wallInteriorFinish' => wall_interior_finish,
      'studsSpacing' => on_center_in,
      'studsFramingFactor' => nil, # Defaulted to nil; not used but could be used with HPXML files
      'studsSize' => studs_size,
      'wallArea' => area_ft2.round(2),
      'wallHeight' => wall_height_ft.round(2),
      'cltValues' => clt_values,
      'concreteValue' => concrete_value,
      'vaporBarrier' => vapor_barrier,
      'airBarrier' => air_barrier,
      'insulations' => insulations,
      'windows' => windows,
      'doors' => doors
    }
    # runner.registerInfo("Wall = #{wall}")
    # Add surface to the object
    walls << wall

    # Add wall object for interior framing
    # Only created if its a non-framed structural layer (e.g., concrete)
    next if int_wall_type.nil?

    wall_interior_framing = {
      'wallName' => wall_name + ".Interior.Framing",
      'wallType' => int_wall_type,
      'wallThickness' => nil,
      'exteriorAdjacentTo' => exterior_adjacent_to,
      'wallSiding' => nil,
      'wallInteriorFinish' => nil,
      'studsSpacing' => int_on_center_in,
      'studsFramingFactor' => nil, # Defaulted to nil; not used but could be used with HPXML files
      'studsSize' => int_studs_size,
      'wallArea' => area_ft2.round(2),
      'wallHeight' => wall_height_ft.round(2),
      'cltValues' => {},
      'concreteValue' => {},
      'vaporBarrier' => nil,
      'airBarrier' => nil,
      'insulations' => [],
      'windows' => [],
      'doors' => []
    }
    walls << wall_interior_framing
  end

  # check for interior walls and if none exist, then add proxy walls based on the geometry.
  # TO DO: the proxy walls are calculated using a function of the conditioned space floor area

  model.getSurfaces.each do |surf|
    # Skip surfaces that aren't walls (changed the old code to allow for internal walls)
    next unless surf.surfaceType == 'Wall' && surf.outsideBoundaryCondition == 'Adiabatic'

    # For surfaces that are interior walls, find its space.

    # Check each space for an interior wall (a single wall is sufficient)
    model.getSpaces.each do |space|
    end
    #

  end

  walls
end

# Get all the Foundation Walls in the model
# @return [Array] returns an array of JSON objects, where
# each object represents a Wall.
def build_foundation_walls_array(idf, model, runner, user_arguments, sql)

  found_chars = runner.getStringArgumentValue('found_chars', user_arguments)
  # runner.registerInfo("User specified Foundation Characteristics: #{found_chars}.")
  foundation_type_string, slab_r_string, wall_r_string = found_chars.split(', ')
  # runner.registerInfo("Split Characteristics: #{foundation_type_string}, #{slab_r_string}, #{wall_r_string}.")
  # foundation_type = foundation_type_string.to_s
  # runner.registerInfo("Slab R: #{foundation_type}")
  # slab_r = /(\d+)/.match(slab_r_string).to_s.to_f
  # runner.registerInfo("Slab R: #{slab_r}")
  wall_r = /(\d+)/.match(wall_r_string).to_s.to_f
  # runner.registerInfo("Slab R: #{wall_r}")

  foundationWalls = []
  foundation_wall_area_m2 = 0

  # ONLY WALL SURFACES - Get each surface and get information from each surface that is a wall. Replicate for other surfaces.
  model.getSurfaces.each do |surf|

    # Skip surfaces that aren't foundation_walls
    next unless surf.outsideBoundaryCondition == 'Ground' && surf.surfaceType == 'Wall'

    # Skip surfaces with no construction
    const = surf.construction
    next if const.empty?

    const = const.get
    # Convert construction base to construction
    const = const.to_Construction.get

    # Get Surface Name
    found_wall_name = surf.name.get

    # Get the area
    area_m2 = surf.netArea
    # runner.registerInfo("Wall Area is #{area_m2} m2.")
    # Area (ft2)
    found_wall_area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

    # find foundation wall height
    wall_z_max = -1_000_000_000
    wall_z_min = 1_000_000_000
    # runner.registerInfo("finding foundation wall vertices.")
    vertices = surf.vertices
    # runner.registerInfo("found subsurface vertices.")
    vertices.each do |vertex|
      z = vertex.z
      if z < wall_z_min
        wall_z_min = z
      else
        next
      end
      if z > wall_z_max
        wall_z_max = z
      else
      end
    end
    # runner.registerInfo("found max and min z vertices.")
    wall_height_m = wall_z_max - wall_z_min
    # runner.registerInfo("wall height = #{wall_height_m}.")
    # Convert to IP
    wall_height_ft = OpenStudio.convert(wall_height_m, 'm', 'ft').get
    wall_length_ft = found_wall_area_ft2 / wall_height_ft

    # Confirm that the surface is a foundation wall.
    # Check if the construction has measure tags. If so, then use those. Otherwise interpret the model.
    construction_stds = const.standardsInformation
    # runner.registerInfo("Construction Standards Information is #{construction_stds}.")

    # Get the layers from the construction
    layers = const.layers
    # Find the structural mass layer. This is a function in construction.rb replicated from the structural layer index
    sl_i = const.found_wall_structural_layer_index
    # Skip and warn if we can't find a structural layer
    if sl_i.nil?
      runner.registerInfo("Cannot find structural layer in foundation wall construction #{const.name}; this construction will not be included in the LCA calculations.  To ensure that the LCA calculations work, you must specify the Standards Information fields in the Construction and its constituent Materials.  Use the CEC2013 enumerations.")
      next
    end

    # Find characteristics of the structural layer using Material Standard Information Measure Tags
    # Assumes a single structural layer. For example, does not capture SIPs manually defined by mutliple layers.
    # These are the tags for the structural layer.
    wall_type = nil

    sli_stds = layers[sl_i].standardsInformation

    if sli_stds.standardsCategory.is_initialized
      category = sli_stds.standardsCategory.get.to_s
      # runner.registerInfo("Structural Layer Category = #{category}.")
    end
    if sli_stds.standardsIdentifier.is_initialized
      identifier = sli_stds.standardsIdentifier.get.to_s
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
    end

    # Find interior and exterior layer for the construction to define the finishes
    # Layers from exterior to interior
    il_identifier = nil
    wall_interior_finish = nil

    layers.each_with_index do |layer, _i|
      # Skip fenestration, partition, and airwall materials
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      # runner.registerInfo("layer = #{layer}.")
      int_layer = layer
      # runner.registerInfo("interior layer = #{int_layer}.")
      il_i_stds = layer.standardsInformation
      if il_i_stds.standardsCategory.is_initialized
        il_category = il_i_stds.standardsCategory.get.to_s
        # runner.registerInfo("Interior Layer Category = #{il_category}.")
      end
      if il_i_stds.standardsIdentifier.is_initialized
        il_identifier = il_i_stds.standardsIdentifier.get.to_s
        # runner.registerInfo("Interior Layer Identifier = #{il_identifier}.")
      end
    end
    # runner.registerInfo("Interior Layer = #{il_identifier}.")

    # Convert identifier to interior wall finish.
    if !il_identifier.nil?
      if il_identifier.include?('Gypsum Board - 1/2 in.') or il_identifier.include?('Gypsum Board - 3/8 in.')
        wall_interior_finish = 'GYPSUM_REGULAR_1_2'
      elsif il_identifier.include?('Gypsum Board - 3/4 in.') or il_identifier.include?('Gypsum Board - 5/8 in.')
        wall_interior_finish = 'GYPSUM_REGULAR_5_8'
      else
        wall_interior_finish = 'OTHER_FINISH'
      end
    else
      wall_interior_finish = 'NONE'
    end
    # runner.registerInfo("Interior Layer = #{wall_interior_finish}.")

    # Find the thickness of the surface assembly
    assembly_thickness_m = 0
    assembly_thickness_in = 0
    # sum the thickness of all layers in the assembly
    layers.each do |layer|
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      assembly_thickness_m = assembly_thickness_m + layer.thickness
      assembly_thickness_in = OpenStudio.convert(assembly_thickness_m, 'm', 'in').get
      # runner.registerInfo("assembly thickness = #{assembly_thickness_in}.")
    end
    # runner.registerInfo("Assembly thickness = #{assembly_thickness_in}.")

    # Inialize insulations array here because approach to insulation varies by wall type and may include interior framing insulation.
    insulations = []

    # Find the foundation interior wall framing specs, including insulation if it exists.
    # Not part of the structural layer.
    int_studs_size = nil
    int_frame_mat = nil
    int_on_center_in = nil
    int_ins_mat = nil
    int_ins_r = nil
    int_ins_r_per_in = nil
    int_ins_thickness = nil
    found_wall_int_stud = nil

    layers.each_with_index do |layer, _i|
      # Skip fenestration, partition, and airwall materials
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      # runner.registerInfo("layer = #{layer}.")
      int_frame_stds = layer.standardsInformation
      next unless int_frame_stds.standardsCategory.is_initialized

      int_frame_category = int_frame_stds.standardsCategory.get.to_s
      next unless int_frame_category.include?('Framed')

      # runner.registerInfo("Interior Framing (#{int_frame_category}) found on foundation wall.")
      # Find framing material (WOOD or METAL)
      if int_frame_stds.compositeFramingMaterial.is_initialized
        int_frame_mat = int_frame_stds.compositeFramingMaterial.get.to_s
        int_frame_mat = int_frame_mat.upcase
      else
        frame_mat = 'WOOD'
      end
      # runner.registerInfo("Interior Framing Material = #{int_frame_mat}.")

      # Find OC
      if int_frame_stds.compositeFramingConfiguration.is_initialized
        frame_config = int_frame_stds.compositeFramingConfiguration.get.to_s
        int_on_center_in = /(\d+)/.match(frame_config).to_s.to_f
      else
        on_center_in = 16
      end
      # runner.registerInfo("Interior Framing Config = #{int_on_center_in}.")

      # Find frame size
      if int_frame_stds.compositeFramingSize.is_initialized
        frame_size = int_frame_stds.compositeFramingSize.get.to_s
        case frame_size
        when '2x4'
          int_studs_size = '_2X4'
          int_ins_thickness = 3.5
        when '2x6'
          int_studs_size = '_2X6'
          int_ins_thickness = 5.5
        when '2x8'
          int_studs_size = '_2X8'
          int_ins_thickness = 7.25
        else
          int_studs_size = 'OTHER_SIZE'
        end
      else
        int_studs_size = '_2x4'
        int_ins_thickness = 3.5
      end
      # runner.registerInfo("Studs Size = #{int_studs_size}.")
      # runner.registerInfo("stud thickness = #{int_ins_thickness}.")

      # Find cavity insulation R-value
      if int_frame_stds.compositeCavityInsulation.is_initialized
        int_ins_r = int_frame_stds.compositeCavityInsulation.get.to_s.to_f
        if int_ins_r.positive? and int_ins_thickness.positive?
          int_ins_r_per_in = int_ins_r / int_ins_thickness
        else
          int_ins_r = 0
          int_ins_r_per_in = 0
        end
      else
        int_ins_r = 0
        int_ins_r_per_in = 0
      end
      # runner.registerInfo("Cavity Insulation R = #{int_ins_r}.")
      # runner.registerInfo("Cavity Insulation R Per Inch = #{int_ins_r_per_in}.")

      # Find cavity insulation material
      if int_frame_stds.standardsIdentifier.is_initialized and int_ins_r.positive? and int_ins_thickness.positive?
        int_frame_identifier = int_frame_stds.standardsIdentifier.get.to_s
        int_frame_identifier = int_frame_identifier.downcase
        if int_frame_identifier.include?('cellulose')
          int_ins_mat = 'LOOSE_FILL_CELLULOSE'
        elsif int_frame_identifier.include?('glass')
          int_ins_mat = 'BATT_FIBERGLASS'
        elsif int_frame_identifier.include?('mineral') or int_frame_identifier.include?('wool') or int_frame_identifier.include?('rock')
          int_ins_mat = 'BATT_ROCKWOOL'
        elsif int_frame_identifier.include?('cell') or int_frame_identifier.include?('spray') or int_frame_identifier.include?('foam')
          int_ins_mat = if int_ins_r > 5
                          'SPRAY_FOAM_CLOSED_CELL'
                        elsif int_ins_r < 5
                          'SPRAY_FOAM_OPEN_CELL'
                        else
                          'SPRAY_FOAM_UNKNOWN'
                        end
        else
          int_ins_mat = 'BATT_FIBERGLASS'
        end
      elsif int_ins_r.positive? and int_ins_thickness.positive?
        int_ins_mat = 'BATT_FIBERGLASS'
      else
        int_ins_mat = nil
      end
      # runner.registerInfo("Cavity Insulation Material = #{int_ins_mat}.")

      # Add insulation to insulations array.
      next unless int_ins_r.positive?

      insulationCav = {
        'insulationMaterial' => int_ins_mat,
        'insulationThickness' => int_ins_thickness,
        'insulationNominalRValue' => int_ins_r,
        'insulationInstallationType' => 'CAVITY',
        'insulationLocation' => 'INTERIOR'
      }
      # runner.registerInfo("Cavity Insulation = #{insulationCav}")
      insulations << insulationCav
      # runner.registerInfo("Foundation Wall Framing Cavity Insulations = #{insulations}")
    end

    # populate foundation wall objects
    found_wall_int_stud = {
      'foundationWallInteriorStudSize' => int_studs_size,
      'foundationWallInteriorStudSpacing' => int_on_center_in,
      'foundationWallInteriorStudFramingFactor' => nil, # Defaulted to 0%; not used but could be used with HPXML files
      'foundationWallInteriorStudFramingMaterial' => int_frame_mat
    }
    # runner.registerInfo("Foundation Wall Interior Frame = #{found_wall_int_stud}")

    # Define foundation wall type based on the measure tags.
    # FoundationWallType can be WOOD, DOUBLE_BRICK, CONCRETE_BLOCK, CONCRETE_BLOCK_FOAM_CORE, CONCRETE_BLOCK_VERMICULITE_CORE,
    # SOLID_CONCRETE, or INSULATED_CONCRETE_FORM

    # WOOD Wall Type - Solid wood; ignore wood framed walls because they are not foundation walls.
    if category.to_s.include?('Woods')
      # define the wall type
      wall_type = 'WOOD'
      cav_thickness_m = layers[sl_i].thickness
      cav_thickness = OpenStudio.convert(cav_thickness_m, 'm', 'in').get.round(2)
      # runner.registerInfo("Concrete Thickness = #{cav_thickness}.")

      concrete_value = {}

      clt_values = {}

    elsif category.to_s.include?('Concrete') and not category.to_s.include?('Sandwich Panel')
      wall_type = 'SOLID_CONCRETE'
      # Define concrete thickness
      concrete_thickness = /(\d+)\sin/.match(identifier).to_s
      # runner.registerInfo("Concrete thickness string = #{concrete_thickness}.")
      cav_thickness = case concrete_thickness
                      when '6 in'
                        6
                      when '8 in'
                        8
                      when '10 in'
                        10
                      when '12 in'
                        12
                      else
                        nil
                      end
      # runner.registerInfo("Concrete Thickness = #{cav_thickness}.")

      # Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

      # Masonry Unit Walls - Assume concrete; ignores clay masonry; excludes block fill
    elsif category.to_s.include?('Masonry Units')

      # Provide details on the masonry fill
      # currently not matching to DOUBLE_BRICK
      if category.to_s.include?('Hollow')
        wall_fill_unused = 'HOLLOW'
        wall_type = 'CONCRETE_BLOCK'
      elsif category.to_s.include?('Solid')
        wall_fill_unused = 'SOLID'
      elsif category.to_s.include?('Fill')
        wall_fill_unused = 'FILL'
        wall_type = 'CONCRETE_BLOCK_FOAM_CORE' # defaulted. could also be CONCRETE_BLOCK_VERMICULITE_CORE
      else
        wall_fill_unused = 'UNKNOWN'
      end

      # Masonry Unit wall will not have framing or cavity insulation within the material

      # Define thickness of the block
      cmu_thickness = /(\d+)\sin/.match(identifier).to_s
      # runner.registerInfo("CMU thickness string = #{cmu_thickness}.")
      cav_thickness = case cmu_thickness
                      when '6 in'
                        6
                      when '8 in'
                        8
                      when '10 in'
                        10
                      when '12 in'
                        12
                      else
                        nil
                      end
      # runner.registerInfo("CMU Thickness = #{cav_thickness}.")

      # Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

    elsif category.to_s.include?('ICF')
      wall_type = 'INSULATED_CONCRETE_FORM'

      # Insulating Concrete Forms - 1 1/2 in. Polyurethane Ins. each side - concrete 8 in.
      # Define thickness of the concrete
      concrete_thickness = /(\d+)\sin/.match(identifier).to_s
      # runner.registerInfo("ICF thickness string = #{concrete_thickness}.")
      cav_thickness = case concrete_thickness
                      when '6 in'
                        6
                      when '8 in'
                        8
                      else
                        nil
                      end
      # runner.registerInfo("Concrete Thickness = #{cav_thickness}.")

      # define the ICF insulation type
      icf_ins = identifier.to_s
      # runner.registerInfo("ICF String = #{icf_ins}.")

      if identifier.to_s.include?('XPS')
        ins_mat = 'RIGID_XPS'
        ins_r_value_per_in = 5.0
      elsif identifier.to_s.include?('EPS')
        ins_mat = 'RIGID_EPS'
        ins_r_value_per_in = 4.6
      elsif identifier.to_s.include?('Polyurethane')
        ins_mat = 'SPRAY_FOAM_CLOSED_CELL'
        ins_r_value_per_in = 6.5
      elsif identifier.to_s.include?('Polyiso')
        ins_mat = 'RIGID_POLYISOCYANURATE'
        ins_r_value_per_in = 5.8
      else
        ins_mat = 'UNKNOWN'
        ins_r_value_per_in = 0
      end
      # runner.registerInfo("ICF Insulation is #{ins_mat}.")
      # runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")

      # define the ICF insulation thickness; concrete is always thicker than the insulation
      cav_thickness = if identifier.to_s.include?('1 1/2 in.')
                        1.5
                      elsif identifier.to_s.include?('2 in.')
                        2
                      elsif identifier.to_s.include?('2 1/2 in.')
                        2.5
                      elsif identifier.to_s.include?('3 in.')
                        3
                      elsif identifier.to_s.include?('4 in.')
                        4
                      elsif identifier.to_s.include?('4 1/2 in.')
                        4.5
                      else
                        nil
                      end
      # runner.registerInfo("ICF Thickness = #{cav_thickness}.")
      cav_r_ip = cav_thickness * ins_r_value_per_in
      # runner.registerInfo("ICF Insulation R Value = #{cav_r_ip}.")

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      ##Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

      # Concrete Sandwich Panel Walls; matched to ICF because the material take-off approach is the same
    elsif category.to_s.include?('Concrete Sandwich Panel')
      wall_type = 'INSULATED_CONCRETE_FORMS'
      # solid concrete will not have framing or cavity insulation within the material
      # Concrete Sandwich Panel - 90% Ins. Layer - No Steel in Ins. - Ins. 2 in.

      # Define thickness of the concrete
      concrete_thickness = 3 * 2 # Defaulted to 3 in wythes of concrete

      # define the CSP insulation thickness
      ins_thickness = if identifier.to_s.include?('1 1/2 in.')
                        1.5
                      elsif identifier.to_s.include?('2 in.')
                        2
                      elsif identifier.to_s.include?('3 in.')
                        3
                      elsif identifier.to_s.include?('4 in.')
                        4
                      elsif identifier.to_s.include?('5 in.')
                        5
                      elsif identifier.to_s.include?('6 in.')
                        6
                      else
                        nil
                      end
      # runner.registerInfo("Insulation Thickness = #{ins_thickness}.")

      # define the ICF insulation type and R value
      ins_mat = 'RIGID_EPS'
      ins_r_value_per_in = 5
      # runner.registerInfo("ICF Insulation is #{ins_mat}.")
      # runner.registerInfo("Nominal R Value = #{ins_r_value_per_in}.")

      # Calculate total Cavity R value
      cav_r_ip = ins_thickness * ins_r_value_per_in
      # runner.registerInfo("CSP Insulation R Value = #{cav_r_ip}.")

      # calculate structural layer thickness
      cav_thickness = concrete_thickness + ins_thickness

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      # Find concrete strength and reinforcement from standards identifier
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      concrete_name = identifier.to_s
      # runner.registerInfo("Concrete Name = #{concrete_name}.")
      density = /(\d+)/.match(identifier).to_s.to_f
      # runner.registerInfo("lb/ft3 = #{density}.") # Initially thought I could use the density to figure out concrete specs...
      compressive_strength_value = 4000 # Defaulted to middle of typical concrete walls (3000 to 5000)
      # runner.registerInfo("PSI = #{compressive_strength_value}.")

      # Closest match calculated compressive strength to enumation options. 3000 to 5000 is typical in walls
      compressive_strength = if compressive_strength_value < 2000
                               'NONE_CONCRETE_COMPRESSIVE_STRENGTH'
                             elsif compressive_strength_value > 2000 and compressive_strength_value < 2750
                               '_2500_PSI'
                             elsif compressive_strength_value > 2750 and compressive_strength_value < 3500
                               '_3000_PSI'
                             elsif compressive_strength_value > 3500 and compressive_strength_value < 4500
                               '_4000_PSI'
                             elsif compressive_strength_value > 4500 and compressive_strength_value < 5500
                               '_5000_PSI'
                             elsif compressive_strength_value > 5500 and compressive_strength_value < 7000
                               '_6000_PSI'
                             elsif compressive_strength_value > 7000
                               '_8000_PSI'
                             else
                               'UNSPECIFIED_CONCRETE_COMPRESSIVE_STRENGTH'
                             end

      # Define reinforcement - defaulted to 5
      rebar_number = 5 # defaulted to 5 for no particular reason

      # Match reinforcement with enumerations for poured or stand up walls. Others will be used for slabs and footings
      reinforcement = case rebar_number
                      when 4
                        'REBAR_NO_4'
                      when 5
                        'REBAR_NO_5'
                      when 6
                        'REBAR_NO_6'
                      else
                        'UNSPECIFIED_CONCRETE_REINFORCEMENT'
                      end

      concrete_value = {
        'concreteName' => concrete_name,
        'compressiveStrength' => compressive_strength,
        'reinforcement' => reinforcement
      }
      # runner.registerInfo("Concrete value = #{concrete_value}")

      clt_values = {}

      # Cross Laminated Timber (CLT) Walls - does not include any insulation.
      # Currently not supported for foundation walls. Should we add?
      # User must manually add a standards category and standards identifier.
      # Category = CLT; Identifier Format = X in. 50/75/100 psf Live Load
    elsif category.to_s.include?('CLT') or category.to_s.include?('Cross Laminated Timber') or category.to_s.include?('Woods') # not a tag option at the moment
      wall_type = 'CROSS_LAMINATED_TIMBER'

      # parse the standard identifier;  eg CLT - 2x4 - 3 Layers

      # find R value of the "cavity" of the SIP
      # runner.registerInfo("Structural Layer Identifier = #{identifier}.")
      live_load = 50
      live_load = /(\d+)\spsf/.match(identifier).to_s.to_f if not category.nil?
      # runner.registerInfo("Live Load = #{live_load}.")

      # Define framing cavity thickness
      clt_thickness = /(\d+)\sin./.match(identifier).to_s
      # runner.registerInfo("CLT thickness = #{clt_thickness}.")
      value, unit = clt_thickness.split(' ')
      cav_thickness = value.to_f
      # runner.registerInfo("CLT Thickness = #{cav_thickness}.")

      cav_r_ip = 0
      ins_r_value_per_in = 0
      ins_r_value_per_in = 0
      ins_mat = 'NONE'

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      # Define supported span using wall length and stories - defaulted to 1 for residential
      supported_span = wall_length_ft # equal to the width of the wall; what is the max span?
      supported_stories = 1 # assume 1 story for residential.

      # Define supported element
      clt_supported_element_type = 'ROOF' # if surface is first floor then assume "floor", if 2nd floor assume "roof"

      clt_values = {
        'liveLoad' => live_load, # kPa
        'supportedSpan' => supported_span, # the length of wall unless it exceeds the maximum
        'supportedElementType' => clt_supported_element_type,
        'supportedStories' => supported_stories
      }

    else
      # Includes metal and brick walls.
      wall_type = 'OTHER_WALL_TYPE'
      # define the framing size; there are no studs for SIPs

      cav_r_ip = 0
      ins_r_value_per_in = 0
      ins_r_value_per_in = 0
      ins_mat = 'NONE'

      if cav_r_ip.positive?
        insulationCav = {
          'insulationMaterial' => ins_mat,
          'insulationThickness' => cav_thickness,
          'insulationNominalRValue' => cav_r_ip,
          'insulationInstallationType' => 'CAVITY',
          'insulationLocation' => 'INTERIOR'
        }
        # runner.registerInfo("Cavity Insulation = #{insulationCav}")
        insulations << insulationCav
      end

      concrete_value = {}

      clt_values = {}

    end

    # Additional insulation either interior or exterior to the structural layer (composite framing layer, SIPs, CIFs, CLTs)
    # Use structural layer as base to find other insulation.
    # runner.registerInfo("sl_i = #{sl_i}.")
    layers.each_with_index do |layer, i|
      # Skip fenestration, partition, and airwall materials
      ins_mat = nil
      ins_thickness = nil
      ins_r_val_ip = nil
      layer = layer.to_OpaqueMaterial
      next if layer.empty?

      layer = layer.get
      # runner.registerInfo("layer = #{layer}.")
      # if side == 'interior'
      # All layers inside (after) the structural layer
      #	next unless i > struct_layer_i
      if i != sl_i
        # runner.registerInfo("Layer is not Structural Layer. checking for insulation")
        if layer.nist_is_insulation
          # identify insulation material, thickness, and r-value using standard information
          ins_stds = layer.standardsInformation
          # If standard information is available, use to define insulation.
          if ins_stds.standardsCategory.is_initialized and ins_stds.standardsIdentifier.is_initialized
            ins_category = ins_stds.standardsCategory.get.to_s
            ins_category = ins_category.downcase
            ins_identifier = ins_stds.standardsIdentifier.get.to_s
            ins_identifier = ins_identifier.downcase
            # runner.registerInfo("Insulation Layer Category = #{ins_category}.")
            # runner.registerInfo("Insulation Layer Identifier = #{ins_identifier}.")

            # identify insulation thickness
            ins_thickness = if !ins_identifier.nil? and ins_category.include?('insulation')
                              if ins_identifier.include?('- 1/8 in.')
                                0.125
                              elsif ins_identifier.include?('- 1/4 in.')
                                0.25
                              elsif ins_identifier.include?('- 1/2 in.')
                                0.5
                              elsif ins_identifier.include?('1 in.')
                                1.0
                              elsif ins_identifier.include?('1 1/2 in.')
                                1.5
                              elsif ins_identifier.include?('2 in.')
                                2.0
                              elsif ins_identifier.include?('2 1/2 in.')
                                2.5
                              elsif ins_identifier.include?('3 in.')
                                3.0
                              elsif ins_identifier.include?('3 1/2 in.')
                                3.5
                              elsif ins_identifier.include?('4 in.')
                                4.0
                              elsif ins_identifier.include?('4 1/2 in.')
                                4.5
                              elsif ins_identifier.include?('5 in.')
                                5.0
                              elsif ins_identifier.include?('5 1/2 in.')
                                5.5
                              elsif ins_identifier.include?('6 in.')
                                6.0
                              elsif ins_identifier.include?('6 1/2 in.')
                                6.5
                              elsif ins_identifier.include?('7 in.')
                                7.0
                              elsif ins_identifier.include?('7 1/4 in.')
                                7.25
                              elsif ins_identifier.include?('7 1/2 in.')
                                7.5
                              elsif ins_identifier.include?('8 in.')
                                8.0
                              elsif ins_identifier.include?('8 1/4 in.')
                                8.25
                              elsif ins_identifier.include?('8 1/2 in.')
                                8.5
                              elsif ins_identifier.include?('9 in.')
                                9.0
                              elsif ins_identifier.include?('9 1/2 in.')
                                9.5
                              elsif ins_identifier.include?('10 in.')
                                10.0
                              elsif ins_identifier.include?('11 in.')
                                11.0
                              elsif ins_identifier.include?('12 in.')
                                12.0
                              else
                                nil
                              end
                              # runner.registerInfo("Insulation Thickness is #{ins_thickness}.")
                            else
                              nil
                              # runner.registerInfo("Insulation Thickness is missing.")
                            end

            # identify insulation r-value
            if !ins_identifier.nil? and ins_identifier.include?('r')
              ins_r_string = /r(\d+)/.match(ins_identifier).to_s
              ins_r_val_ip = /(\d+)/.match(ins_r_string).to_s.to_f
            elsif ins_category.include?('spray')
              if ins_identifier.include?('urethane')
                if ins_identifier.include?('3.0 lb/ft3')
                  ins_r_val_ip = ins_thickness * 6.3
                elsif ins_identifier.include?('0.5 lb/ft3')
                  ins_r_val_ip = ins_thickness * 3.7
                end
              elsif ins_identifier.include?('cellulosic')
                ins_r_val_ip = ins_thickness * 3.7
              elsif ins_identifier.include?('glass')
                ins_r_val_ip = ins_thickness * 3.7
              end
            elsif not layer.thermalConductivity.nil? and not layer.thickness.nil?
              layer_conductivity = layer.thermalConductivity.to_s.to_f
              layer_thickness_m = layer.thickness.to_s.to_f
              ins_r_val_ip = layer_thickness_m / layer_conductivity * 5.678
            else
              ins_r_val_ip = nil
            end
            # runner.registerInfo("Insulation R is #{ins_r_val_ip}.")

            # identify insulation material
            if ins_category.include?('insulation board')
              if !ins_identifier.nil?
                if ins_identifier.include?('polyiso')
                  ins_mat = 'RIGID_POLYISOCYANURATE'
                elsif ins_identifier.include?('xps')
                  ins_mat = 'RIGID_XPS'
                elsif ins_identifier.include?('compliance')
                  ins_mat = 'RIGID_XPS'
                  ins_thickness = ins_r_val_ip / 5.0 # must define thickness for compliance insulation
                elsif ins_identifier.include?('eps')
                  ins_mat = 'RIGID_EPS'
                elsif ins_identifier.include?('urethane')
                  ins_mat = 'SPRAY_FOAM_CLOSED_CELL' # R-values for CBES materials match closed cell
                else
                  ins_mat = 'RIGID_UNKNOWN'
                end
              else
                ins_mat = 'RIGID_UNKNOWN'
              end
            elsif ins_category.include?('insulation')
              # runner.registerInfo("Non-board Insulation found on top of attic floor.")
              ins_identifier = ins_identifier.downcase
              ins_mat = if !ins_identifier.nil?
                          if ins_identifier.include?('loose fill')
                            'LOOSE_FILL_CELLULOSE'
                          elsif ins_identifier.include?('cellulosic fiber')
                            'LOOSE_FILL_CELLULOSE'
                          elsif ins_identifier.include?('batt')
                            'BATT_FIBERGLASS'
                          elsif ins_identifier.include?('glass fiber')
                            'LOOSE_FILL_FIBERGLASS'
                          elsif ins_identifier.include?('spray') and ins_identifier.include?('4.6 lb/ft3')
                            'SPRAY_FOAM_CLOSED_CELL'
                          elsif ins_identifier.include?('spray') and ins_identifier.include?('3.0 lb/ft3')
                            'SPRAY_FOAM_CLOSED_CELL'
                          elsif ins_identifier.include?('spray') and ins_identifier.include?('0.5 lb/ft3')
                            'SPRAY_FOAM_OPEN_CELL'
                          else
                            'UNKNOWN'
                          end
                        else
                          'UNKNOWN'
                        end
            else
              ins_mat = nil
              # runner.registerInfo("No Insulation Material found.")
            end
            # runner.registerInfo("Insulation Material is #{ins_mat}.")
            # If no standard information is available, use the layer performance specs (thickness and thermal resistance to match insulation material)
            # Currently only considers rigid insulation.
          elsif not layer.thickness.nil? and not layer.thermalResistance.nil?
            ins_thickness_m = layer.thickness.to_f
            ins_thickness = OpenStudio.convert(ins_thickness_m, 'm', 'in').get
            ins_r_val_si = layer.thermalResistance.to_f
            ins_r_val_ip = OpenStudio.convert(r_val_si, "m^2*K/W", "ft^2*h*R/Btu").get
            ins_r_value_per_in = ins_r_val_ip / ins_thickness
            ins_mat = if ins_r_value_per_in < 0.1
                        'NONE'
                      elsif ins_r_value_per_in < 4.5 and ins_r_value_per_in > 0.1
                        'RIGID_EPS'
                      elsif ins_r_value_per_in < 5.25 and ins_r_value_per_in > 4.5
                        'RIGID_XPS'
                      elsif ins_r_value_per_in < 7 and ins_r_value_per_in > 5.25
                        'RIGID_POLYISOCYANURATE'
                      else
                        'RIGID_UNKNOWN'
                      end
            # If a failure occurs above, then provide nil values.
          else
            ins_mat = nil
            ins_thickness = nil
            ins_r_val_ip = nil
            # runner.registerInfo("No Insulation Material found.")
          end
          # Populate the correct insulation object (interior or exterior)
          # runner.registerInfo("Insulation Specs: #{ins_mat},#{ins_thickness},#{ins_r_val_ip}.")
          if i > sl_i
            # add interior insulation to insulations
            insulationInt = {
              'insulationMaterial' => ins_mat,
              'insulationThickness' => ins_thickness.round(1),
              'insulationNominalRValue' => ins_r_val_ip.round(1),
              'insulationInstallationType' => 'CONTINUOUS',
              'insulationLocation' => 'INTERIOR'
            }
            # runner.registerInfo("Insulation = #{insulationInt}")
            insulations << insulationInt
          elsif i < sl_i
            # add exterior insulation to insulations
            insulationExt = {
              'insulationMaterial' => ins_mat,
              'insulationThickness' => ins_thickness.round(1),
              'insulationNominalRValue' => ins_r_val_ip.round(1),
              'insulationInstallationType' => 'CONTINUOUS',
              'insulationLocation' => 'EXTERIOR'
            }
            # runner.registerInfo("Insulation = #{insulationExt}")
            insulations << insulationExt
          else
            # runner.registerInfo("Layer was not added as Insulation.")
          end
        else
          # runner.registerInfo("Layer not insulation")
        end
      end
    end
    # runner.registerInfo("Insulations = #{insulations}")

    # Need to find all subsurfaces on a wall surface and determine which are windows and doors.
    # Then pull the information for each to add to the array.
    # This will require a do loop through each wall surface.
    windows = []
    doors = []

    # if subsurface is a window, then populate the window object.
    # Only need to populate the physical components or the performance specs. Use performance specs from OSM.
    # Can I pull this info from OSM or do I have to go through each E+ window object, match the surface name, and pull specs?

    # runner.registerInfo("finding all windows in this surface.")
    surf.subSurfaces.each do |ss|
      # if ss is a window, else its a door.
      # runner.registerInfo("found subsurface.")
      subsurface_type = ss.subSurfaceType
      # runner.registerInfo("found subsurface type: #{subsurface_type}.")
      # Determine if the subsurface is a window or door or other
      case subsurface_type
      when 'FixedWindow', 'OperableWindow'
        # Determine operability
        operable = case subsurface_type
                   when 'FixedWindow'
                     false
                   when 'OperableWindow'
                     true
                   else
                     false
                   end
        window_name = ss.name
        # runner.registerInfo("found subsurface #{window_name}.")
        window_area_m2 = ss.grossArea
        # runner.registerInfo("found subsurface #{window_name} with area #{window_area}.")
        window_area_ft2 = OpenStudio.convert(window_area_m2, 'm^2', 'ft^2').get
        window_z_max = -1_000_000_000
        window_z_min = 1_000_000_000
        # runner.registerInfo("finding subsurface vertices.")
        vertices = ss.vertices
        # runner.registerInfo("found subsurface vertices.")
        vertices.each do |vertex|
          z = vertex.z
          if z < window_z_min
            window_z_min = z
          else
            next
          end
          if z > window_z_max
            window_z_max = z
          else
          end
        end
        # runner.registerInfo("found max and min z vertices.")
        window_height_m = window_z_max - window_z_min
        # runner.registerInfo("window height = #{window_height_m}.")
        # Convert to IP
        window_height_ft = OpenStudio.convert(window_height_m, 'm', 'ft').get

        # Use construction standards for subsurface to find window characteristics
        # Default all the characteristics to NONE
        frame_type = 'NONE_FRAME_TYPE'
        glass_layer = 'NONE_GLASS_LAYERS'
        glass_type = 'NONE_GLASS_TYPE'
        gas_fill = 'NONE_GAS_FILL'

        # Find the construction of the window
        sub_const = ss.construction
        next if sub_const.empty?

        sub_const = sub_const.get
        # Convert construction base to construction
        sub_const = sub_const.to_Construction.get
        # runner.registerInfo("Window Construction is #{sub_const}.")
        # Check if the construction has measure tags.
        sub_const_stds = sub_const.standardsInformation
        # runner.registerInfo("Window Const Stds Info is #{sub_const_stds}.")

        # Find number of panes. Does not account for storm windows. Quad panes is not in enumerations.
        if sub_const_stds.fenestrationNumberOfPanes.is_initialized
          number_of_panes = sub_const_stds.fenestrationNumberOfPanes.get.downcase.to_s
          glass_layer = if number_of_panes.include?('single')
                          'SINGLE_PANE'
                        elsif number_of_panes.include?('double')
                          'DOUBLE_PANE'
                        elsif number_of_panes.include?('triple')
                          'TRIPLE_PANE'
                        elsif number_of_panes.include?('quadruple')
                          'MULTI_LAYERED'
                        elsif number_of_panes.include?('glass block')
                          'NONE_GLASS_LAYERS'
                        else
                          'NONE_GLASS_LAYERS'
                        end
        end
        # runner.registerInfo("Glass Layers = #{glass_layer}.")

        # Find frame type. Does not account for wood, aluminum, vinyl, or fiberglass.
        if sub_const_stds.fenestrationFrameType.is_initialized
          os_frame_type = sub_const_stds.fenestrationFrameType.get.downcase.to_s
          frame_type = if os_frame_type.include?('non-metal')
                         'COMPOSITE'
                       elsif os_frame_type.include?('metal framing thermal')
                         'METAL_W_THERMAL_BREAK'
                       elsif os_frame_type.include?('metal framing')
                         'METAL'
                       else
                         'NONE_FRAME_TYPE'
                       end
        end
        # runner.registerInfo("Frame Type = #{frame_type}.")

        # Find tint and low e coating. Does not account for reflective.
        os_low_e = sub_const_stds.fenestrationLowEmissivityCoating
        # runner.registerInfo("low e = #{os_low_e}.")
        if sub_const_stds.fenestrationTint.is_initialized
          os_tint = sub_const_stds.fenestrationTint.get.downcase.to_s
          if os_low_e == true
            glass_type = 'LOW_E'
          else
            if os_tint.include?('clear')
              glass_type = 'NONE_GLASS_TYPE'
            elsif os_tint.include?('tinted') or os_tint.include?('green') or os_tint.include?('blue') or os_tint.include?('grey') or os_tint.include?('bronze')
              glass_type = 'TINTED'
            else
              glass_type = 'NONE_GLASS_TYPE'
            end
          end
        elsif not sub_const_stds.fenestrationTint.is_initialized
          glass_type = if os_low_e == true
                         'LOW_E'
                       else
                         'NONE_GLASS_TYPE'
                       end
        end
        # runner.registerInfo("Glass Type = #{glass_type}.")

        # Find gas fill. Enumerations missing krypton - matches to argon.
        if sub_const_stds.fenestrationGasFill.is_initialized
          os_gas_fill = sub_const_stds.fenestrationGasFill.get.downcase.to_s
          gas_fill = if os_gas_fill.include?('air')
                       'AIR'
                     elsif os_gas_fill.include?('argon') or os_tint.include?('krypton')
                       'ARGON'
                     else
                       'NONE_GAS_FILL'
                     end
        end
        # runner.registerInfo("Gas Fill = #{gas_fill}.")

        # Take window name and use it to find the specs.
        # Parse the window name, upcase the letters, and then put back together. The periods are causing the problem.
        window_name_string = window_name.to_s
        # runner.registerInfo("window name now string: #{window_name_string}.")
        window_name_capped = window_name_string.upcase
        # runner.registerInfo("window name capped: #{window_name_capped}.")
        # query the SQL file including the row name being a variable. Treat like its in a runner.
        # U-Factor Query
        query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass U-Factor'
				  AND RowName='#{window_name_capped}'
				  AND Units='W/m2-K'"
        # runner.registerInfo("Query is #{query}.")
        u_si = sql.execAndReturnFirstDouble(query)
        # runner.registerInfo("U-SI value was found: #{u_si}.")
        u_si = if u_si.is_initialized
                 u_si.get
               else
                 0
               end
        u_ip = OpenStudio.convert(u_si, 'W/m^2*K', 'Btu/hr*ft^2*R').get
        # SHGC Query
        query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass SHGC'
				  AND RowName='#{window_name_capped}'"
        # runner.registerInfo("Query is #{query}.")
        shgc = sql.execAndReturnFirstDouble(query)
        # runner.registerInfo("SHGC value was found: #{shgc}.")
        shgc = if shgc.is_initialized
                 shgc.get
               else
                 0
               end

        # VT Query
        query = "SELECT Value
				  FROM tabulardatawithstrings
				  WHERE ReportName='EnvelopeSummary'
				  AND ReportForString= 'Entire Facility'
				  AND TableName='Exterior Fenestration'
				  AND ColumnName='Glass Visible Transmittance'
				  AND RowName='#{window_name_capped}'"
        # runner.registerInfo("Query is #{query}.")
        vt = sql.execAndReturnFirstDouble(query)
        # runner.registerInfo("U-SI value was found: #{vt}.")
        vt = if vt.is_initialized
               vt.get
             else
               0
             end

        window = {
          'name' => window_name,
          'operable' => operable,
          'area' => window_area_ft2.round(2),
          'height' => window_height_ft.round(2), # TO DO  - need to add to enumerations
          'quantity' => 1, # Hard coded until we introduce Construction Fenstration Information option
          'frameType' => 'NONE_FRAME_TYPE', # Hard coded until we introduce Construction Fenstration Information option
          'glassLayer' => 'NONE_GLASS_LAYERS', # Hard coded until we introduce Construction Fenstration Information option
          'glassType' => 'NONE_GLASS_TYPE', # Hard coded until we introduce Construction Fenstration Information option
          'gasFill' => 'NONE_GAS_FILL', # Hard coded until we introduce Construction Fenstration Information option
          'shgc' => shgc.round(4),
          'visualTransmittance' => vt.round(4),
          'uFactor' => u_ip.round(4)
        }
        # runner.registerInfo("Window = #{window}")
        windows << window

        # if subsurface is a door, then populate the door object.
        # Question: Can we use the U value to guess the material?
      when 'Door', 'GlassDoor'
        # Determine door type
        door_type = 'EXTERIOR'
        door_mat = runner.getStringArgumentValue('door_mat', user_arguments)
        door_material = nil
        # TODO: finalize the percent glazing values
        case door_mat
        when 'Solid Wood'
          pct_glazing = 0.0
          door_material = 'SOLID_WOOD'
        when 'Glass'
          pct_glazing = 0.99
          door_material = 'GLASS'
        when 'Uninsulated Fiberglass'
          pct_glazing = 0.00
          door_material = 'UNINSULATED_FIBERGLASS'
        when 'Insulated Fiberglass'
          pct_glazing = 0.00
          door_material = 'INSULATED_FIBERGLASS'
        when 'Uninsulated Metal (Aluminum)'
          pct_glazing = 0.00
          door_material = 'UNINSULATED_METAL_ALUMINUM'
        when 'Insulated Metal (Aluminum)'
          pct_glazing = 0.00
          door_material = 'INSULATED_METAL_ALUMINUM'
        when 'Uninsualted Metal (Steel)'
          pct_glazing = 0.00
          door_material = 'UNINSULATED_METAL_STEEL'
        when 'Insulated Metal (Steel)'
          pct_glazing = 0.00
          door_material = 'INSULATED_METAL_STEEL'
        when 'Hollow Wood'
          pct_glazing = 0.00
          door_material = 'HOLLOW_WOOD'
        when 'Other'
          pct_glazing = 0.00
          door_material = 'NONE'
        end
        door_name = ss.name
        # runner.registerInfo("found subsurface #{door_name}.")
        door_area_m2 = ss.grossArea
        # runner.registerInfo("found subsurface #{window_name} with area #{window_area}.")
        door_area_ft2 = OpenStudio.convert(door_area_m2, 'm^2', 'ft^2').get
        door_z_max = -1_000_000_000
        door_z_min = 1_000_000_000
        # runner.registerInfo("finding subsurface vertices.")
        vertices = ss.vertices
        # runner.registerInfo("found subsurface vertices.")
        vertices.each do |vertex|
          z = vertex.z
          if z < door_z_min
            door_z_min = z
          else
            next
          end
          if z > door_z_max
            door_z_max = z
          else
          end
        end
        # runner.registerInfo("found max and min z vertices.")
        door_height_m = door_z_max - door_z_min
        # runner.registerInfo("door height = #{door_height_m}.")
        # Convert to IP
        door_height_ft = OpenStudio.convert(door_height_m, 'm', 'ft').get
        door = {
          'name' => door_name, ###STOPPING POINT
          'type' => door_type,
          'material' => door_material,
          'percentGlazing' => pct_glazing,
          'area' => door_area_ft2.round(2),
          'height' => door_height_ft.round(2), # Needs to be added to enumerations
          'quantity' => 1 # Defaulted to 1 because we report each individually. Should we remove?
        }
        # runner.registerInfo("Door = #{door}")
        doors << door
      else
        # runner.registerInfo("subsurface type is not a window or door and will be skipped: #{subsurface_type}.")
      end
    end

    foundationWall = {
      'foundationWallName' => found_wall_name,
      'foundationWallType' => wall_type, # TODO: need to complete search for all wall types; some are not supported by tags
      'foundationWallArea' => found_wall_area_ft2.round(2),
      'foundationWallHeight' => wall_height_ft.round(2),
      'foundationWallThickness' => assembly_thickness_in.round(2),
      'foundationWallInsulations' => insulations,
      'foundationWallInteriorStud' => found_wall_int_stud,
      'concreteValue' => concrete_value,
      'windows' => windows,
      'doors' => doors
    }
    # runner.registerInfo("Foundation Wall = #{foundationWall}")
    foundationWalls << foundationWall
  end
  return foundationWalls
end
