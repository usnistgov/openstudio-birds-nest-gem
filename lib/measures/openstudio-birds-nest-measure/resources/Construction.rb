# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# Extend the OpenStudio class
class OpenStudio::Model::Construction

  # Gets the U-factor of the window construction,
  # as calculated by EnergyPlus.
  # @return [Double] The U-factor in W/m^2*K)
  def glass_u_factor

    name = self.name.get.to_s
  
    # Skip if called on a non-window construction
    unless self.isFenestration
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Construction", "Cannot determine glass U-factor for #{name} because it is not a fenestration.")
      return 0.0
    end
    
	# Currently queries average U-factor for the facility.
    query = "SELECT Value
              FROM tabulardatawithstrings
              WHERE ReportName='EnvelopeSummary'
              AND ReportForString='Entire Facility'
              AND TableName='Exterior Fenestration'
              AND ColumnName='Glass U-Factor'
              AND RowName='#{self.row_id}'"       
  
    u_factor = sql.execAndReturnFirstDouble(query)
    
    if u_factor.is_initialized
      u_factor = u_factor.get
    else
      u_factor = nil
    end

    return u_factor
    
  end

# Gets the visible transmittance (VT) of the window construction,
# as calculated by EnergyPlus.
# @return [Double] The visible transmittance as a fraction.
# (0.5 means 50% visible transmittance)
# Currently queries average VT for the facility.

  def glass_visible_transmittance

    name = self.name.get.to_s
  
    # Skip if called on a non-window construction
    unless self.isFenestration
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Construction", "Cannot determine glass visible transmittance for #{name} because it is not a fenestration.")
      return 0.0
    end
          
    query = "SELECT Value
              FROM tabulardatawithstrings
              WHERE ReportName='EnvelopeSummary'
              AND ReportForString='Entire Facility'
              AND TableName='Exterior Fenestration'
              AND ColumnName='Glass Visible Transmittance'
              AND RowName='#{self.row_id}'"       
  
    vt = sql.execAndReturnFirstDouble(query)
    
    if vt.is_initialized
      vt = vt.get
    else
      vt = nil
    end

    return vt
    
  end
  
  # Gets the solar heat gain coefficient (SHGC) of the window construction,
  # as calculated by EnergyPlus.
  # @return [Double] The solar heat gain coefficient as a fraction.
  def glass_solar_heat_gain_coefficient

    name = self.name.get.to_s
  
    # Skip if called on a non-window construction
    unless self.isFenestration
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Construction", "Cannot determine glass solar heat gain coefficient for #{name} because it is not a fenestration.")
      return 0.0
    end
    
	# Currently queries average SHGC for the facility.	
    query = "SELECT Value
              FROM tabulardatawithstrings
              WHERE ReportName='EnvelopeSummary'
              AND ReportForString='Entire Facility'
              AND TableName='Exterior Fenestration'
              AND ColumnName='Glass SHGC'
              AND RowName='#{self.row_id}'"       
  
    shgc = sql.execAndReturnFirstDouble(query)
    
    if shgc.is_initialized
      shgc = shgc.get
    else
      shgc = nil
    end

    return shgc
    
  end
    
  # Get the structural (stud or mass) layer
  # in the wall or roof.  This is done by looking at the
  # Standards Category for each layer and finding the first layer
  # with a string that specifies the wall type.
  #
  # @return [OpenStudio::Model::Material] the structural layer material
  def structural_layer_index()
    
    index = nil
    
	# this identifies the standards categories that are structural layers. These include layers that are composite materials (framing + insulation; SIPs; ICF). May be the only layer.
    # added CLT to structural layer. Could replicate for other
	# Since the index searches from outside to inside, 
	# exterior walls with find mass layers before interior framing of those mass layers.
	# This results in identifying the correct "structural layer". 
	# The only issue is if the surface is shared between thermal zones. QUESTION: Do we need to add a check?
	self.layers.each_with_index do |layer, i|
      stds = layer.standardsInformation
      cat = stds.standardsCategory
      next if cat.empty?
      cat = cat.get.downcase
      if cat.include?('wall') || cat.include?('concrete') || cat.include?('framed') || (cat.include?('roof') && !cat.include?('roofing')) || cat.include?('ceiling') || cat.include?('sips') || cat.include?('masonry units') || cat.include?('floor') || cat.include?('clt') || cat.include?('woods') || cat.include?('cross laminated timber')
        index = i
        break
      end
    end
    
    return index

  end

  # Get the structural (mass) layer for foundation walls
  # in the wall or roof.  This is done by looking at the
  # Standards Category for each layer and finding the first layer
  # with a string that specifies the wall type.
  #
  # @return [OpenStudio::Model::Material] the structural layer material
  def found_wall_structural_layer_index()
    
    index = nil
    
	# this identifies the standards categories that are structural layers. These include layers that are composite materials (framing + insulation; SIPs; ICF). May be the only layer.
    # added CLT to structural layer. Could replicate for other 
	self.layers.each_with_index do |layer, i|
      stds = layer.standardsInformation
      cat = stds.standardsCategory
      next if cat.empty?
      cat = cat.get.downcase
      if cat.include?('concrete')|| cat.include?('sips') || cat.include?('masonry units') || cat.include?('clt') || cat.include?('woods') || cat.include?('cross laminated timber')
        index = i
        break
      end
    end
    
    return index

  end

  # Get the structural (mass) layer for foundation walls
  # in the wall or roof.  This is done by looking at the
  # Standards Category for each layer and finding the first layer
  # with a string that specifies the wall type.
  #
  # @return [OpenStudio::Model::Material] the structural layer material
  def found_structural_layer_index()
    
    index = nil
    
	# this identifies the standards categories that are structural layers. Only concrete considered.
	self.layers.each_with_index do |layer, i|
      stds = layer.standardsInformation
      cat = stds.standardsCategory
      next if cat.empty?
      cat = cat.get.downcase
      if cat.include?('concrete')
        index = i
        break
      end
    end
    
    return index

  end

  
  # Get the construction type enumeration for the overall
  # construction.
  def nist_construction_type  

    type = nil
    
    stds = self.standardsInformation
    cat = stds.standardsConstructionType
    return type if cat.empty?
    type = cat.get

    return type
  
  end
  
  # Find the R-value of any insulation on the interior
  # side of the structural layer.
  #
  # @param struct_layer_i [Integer] the index of the structural layer
  # @param side [String] interior or exterior
  # @return [Double] the R-value of the insulation, in "ft^2*h*R/Btu"
  def rigid_insulation_r_value(struct_layer_i, side='interior')  ### Why is side = interior here?
    
    r_val_ip = nil
    
    # Get the layers interior of the structural layer
    possible_ins_layers = []
    # Layers from exterior to interior
    self.layers.each_with_index do |layer, i|
      # Skip fenestration, partition, and airwall materials
      layer = layer.to_OpaqueMaterial
      next if layer.empty?
      layer = layer.get
      if side == 'interior'
        # All layers inside (after) the structural layer
        next unless i > struct_layer_i
        possible_ins_layers << layer
      elsif side == 'exterior'
        # All layers outside (before) the structural layer
        next unless i < struct_layer_i
        possible_ins_layers << layer
      elsif side == 'both'
        # All layers except the structural layer
        next if i == struct_layer_i
        possible_ins_layers << layer
      end
    end
  
    # Add up the R-value of all the insulation layers
    r_val_si = 0.0
	total_ins_thickness_si = 0.0
    possible_ins_layers.each do |layer|
      if layer.nist_is_insulation
        r_val_si += layer.thermalResistance
      end
    end
    
    # Convert SI to IP
    if r_val_si > 0
      r_val_ip = OpenStudio.convert(r_val_si,"m^2*K/W","ft^2*h*R/Btu").get
    end
    
    return r_val_ip

  end
  
  #Rigid Insulation Values (R and Thickness)
  def rigid_insulation_values(struct_layer_i, side='interior')  ### Why is side = interior here?
    
    r_val_ip = nil
    
    # Get the layers interior of the structural layer
    possible_ins_layers = []
    # Layers from exterior to interior
    self.layers.each_with_index do |layer, i|
      # Skip fenestration, partition, and airwall materials
      layer = layer.to_OpaqueMaterial
      next if layer.empty?
      layer = layer.get
      if side == 'interior'
        # All layers inside (after) the structural layer
        next unless i > struct_layer_i
        possible_ins_layers << layer
      elsif side == 'exterior'
        # All layers outside (before) the structural layer
        next unless i < struct_layer_i
        possible_ins_layers << layer
      elsif side == 'both'
        # All layers except the structural layer
        next if i == struct_layer_i
        possible_ins_layers << layer
      end
    end
  
    # Add up the R-value of all the insulation layers
	# TO DO: update using the Standards information
    r_val_si = 0.0
	total_ins_thickness_si = 0.0
    possible_ins_layers.each do |layer|
      if layer.nist_is_insulation
        r_val_si += layer.thermalResistance
		total_ins_thickness_si += layer.thickness
      end
    end
    
    # Convert SI to IP
    if r_val_si > 0
      r_val_ip = OpenStudio.convert(r_val_si,"m^2*K/W","ft^2*h*R/Btu").get
	  total_ins_thickness_ip = OpenStudio.convert(total_ins_thickness_si,"m","in").get
    end
    
    return r_val_ip, total_ins_thickness_ip

  end
  
  # Gets the row ID of this construction in the EnergyPlus output
  # data file.  Will be used by other queries.
  # @return [Integer] The ID of the table row where this construction can be found.
  def row_id
  
    name = self.name.get.to_s
  
    row_query = "SELECT RowName
                FROM tabulardatawithstrings
                WHERE ReportName='EnvelopeSummary'
                AND ReportForString='Entire Facility'
                AND TableName='Exterior Fenestration'
                AND Value='#{name.upcase}'"
  
    row_id = sql.execAndReturnFirstString(row_query)
    
    if row_id.is_initialized
      row_id = row_id.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.Construction", "Row ID not found for construction: #{name}.  Cannot find requested window property.")
      row_id = 9999
    end  
  
    return row_id
  
  end        

  # Get the sqlFile attached to the model
  def sql()
  
    sql = self.model.sqlFile
    
    if sql.is_initialized
      sql = sql.get
    else
      sql = nil
    end
  
    return sql
  
  end
  
end