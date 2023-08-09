# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'json'
# impact category columns
 def flow_cols

   flow_col_types = [
         'globalWarmingPotential',
		 'acidificationPotential',
		 'respiratoryEffects',
		 'eutrophicationPotential',
		 'ozoneDepletionPotential',
		 'smogPotential',
         'totalPrimaryEnergy',
		 'nonRenewableEnergy',
		 'renewableEnergy',
		 'fossilFuelEnergy'
   ]

   return flow_col_types
 end

# headers for impact categories including units
 def header_lookup(includeBreak)

  if includeBreak
    lookup = {
         'globalWarmingPotential' => 'Global Warming</br>(kg CO2 eq)',
		 'acidificationPotential' => 'Acidification</br>(kg SO2 eq)',
		 'respiratoryEffects' => 'Respiratory Effects</br>(kg PM2.5 eq)',
		 'eutrophicationPotential' => 'Eutrophication</br>(kg N eq)',
		 'ozoneDepletionPotential' => 'Ozone Depletion</br>(kg CFC-11 eq)',
		 'smogPotential' => 'Smog</br>(kg O3 eq)',
         'totalPrimaryEnergy' => 'Primary Energy</br>(MJ)',
		 'nonRenewableEnergy' => 'Non-Renewable Energy</br>(MJ)',
		 'renewableEnergy' => 'Renewable Energy</br>(MJ)',
		 'fossilFuelEnergy' => 'Fossil Fuel Energy</br>(MJ)'        
    }
  else
    lookup = {
         'globalWarmingPotential' => 'Global Warming (kg CO2 eq)',
		 'acidificationPotential' => 'Acidification (kg SO2 eq)',
		 'respiratoryEffects' => 'Respiratory Effects (kg PM2.5 eq)',
		 'eutrophicationPotential' => 'Eutrophication (kg N eq)',
		 'ozoneDepletionPotential' => 'Ozone Depletion (kg CFC-11 eq)',
		 'smogPotential' => 'Smog (kg O3 eq)',
         'totalPrimaryEnergy' => 'Primary Energy (MJ)',
		 'nonRenewableEnergy' => 'Non-Renewable Energy (MJ)',
		 'renewableEnergy' => 'Renewable Energy (MJ)',
		 'fossilFuelEnergy' => 'Fossil Fuel Energy (MJ)'        
    }
  end
  
  return lookup
 end

# headers for impact categories excluding units
 def header_lookup_2

   lookup = {
         'globalWarmingPotential' => 'Global Warming',
		 'acidificationPotential' => 'Acidification',
		 'respiratoryEffects' => 'Respiratory Effects',
		 'eutrophicationPotential' => 'Eutrophication',
		 'ozoneDepletionPotential' => 'Ozone Depletion',
		 'smogPotential' => 'Smog',
         'totalPrimaryEnergy' => 'Primary Energy',
		 'nonRenewableEnergy' => 'Non-Renewable Energy',
		 'renewableEnergy' => 'Renewable Energy',
		 'fossilFuelEnergy' => 'Fossil Fuel Energy'   
   }
  
   return lookup
 end

# column headers for impact categories
 def flow_col_headers

   lookup = header_lookup(true)

   headers = []
   flow_cols.each do |flow_col|
     headers << lookup[flow_col]
   end

   return headers
 end

# results categories - each provides results to be included in different tables
 def get_nice_category_name(json_name)

   lookup = {
        'buildingComponentFlowsTotal' => 'Total Building Component Flows',
        'buildingComponentFlowsTotalByYear' => 'Total Building Component Flows by Year',
		'energyUseFlows' => 'Operational Energy Flows',
		'energyUseFlowsByYear' => 'Operational Energy Flows by Year',
		'buildingComponentFlows' => 'Building Component Flows by Life Cycle Stage',
		'buildingComponentFlowsByYear' => 'Building Component Flows by Year by Life Cycle Stage' #,
		#'apiVersion' => 'API Version',
		#'billOfMaterials' => 'Bill of Materials',
		#'billOfMaterialsByYear' => 'Bill of Materials by Year',
		#'warnings' => 'Warnings from NIST BIRDS NEST'
   }
   nice_name = lookup[json_name]
   nice_name = 'Unrecognized category name: ' + json_name if nice_name.nil?

   return nice_name
 end

# building component categories - these are subcategories for the categories except bill of materials, api version, and warnings
 def get_nice_subcategory_name(json_name)

   lookup = {
        'totalBuildingComponentFlows' => 'Total Building Component Flows',
        'totalStructureFlows' => 'Total Structure Flows',
        'exteriorWallsFlows'=> 'Exterior Walls Flows',
		'interiorWallsFlows'=> 'Interior Walls Flows',
		'fenestrationFlows'=> ' Fenestration Flows',
		'roofsatticsFlows'=> ' Roofs and Attics Flows',
		'foundationsFlows'=> ' Foundations Flows',
		'interiorFinishesFlows'=> 'Interior Finishes Flows',
		'columnsAndBeamsFlows'=> 'Columns and Beams Flows',
		'floorsFlows'=> 'Floors Flows',
		'extraMaterialsFlows'=> 'Extra Materials Flows',
		'totalSystemsFlows'=> 'Total Systems Flows',
		'hvacSystemsFlows'=> 'HVAC Systems Flows',
		'lightingSystems'=> 'Lighting Systems Flows',
		'dhwSystemsFlows'=> 'DHW Systems Flows',
		'solarPvSystemsFlows'=> 'Solar PV Systems Flows',
		'solarThermalSystemsFlows'=> 'Solar Thermal Systems Flows',
		'appliancesFlows'=> 'Appliances Flows',
		'totalEnergy'=> 'Total Energy Flows',
		'electricity'=> 'Electricity Flows',
		'naturalGas'=> 'Natural Gas Flows',
		'propane'=> 'Propane Flows',
		'fuelOil'=> 'Fuel Oil Flows'
   }

   nice_subname = lookup[json_name]
   nice_subname = 'Unrecognized category subname: ' + json_name if nice_subname.nil?

   return nice_subname
 end

# Life Cycle Stages 
 def nice_lc_stage_name(json_name)

   lookup = {
		'A1' => 'A1',
		'A2' => 'A2',
		'A3' => 'A3',
		'A123' => 'A1-A3',
		'A4' => 'A4',
		'A5' => 'A5',
		'B1' => 'B1',
		'B2' => 'B2',
		'B3' => 'B3',
		'B123' => 'B1-3',
		'B4' => 'B4',
		'B5' => 'B5',
		'B6' => 'B6',
		'B7' => 'B7',
		'C1' => 'C1',
		'C2' => 'C2',
		'C3' => 'C3',
		'C4' => 'C4',
		'C1234' => 'C1-4',
		'D' => 'D'
   }

   nice_stage_name = lookup[json_name]
   nice_stage_name = 'Unrecognized stage name: ' + json_name if nice_stage_name.nil?

   return nice_stage_name
 end

 def lc_stage_cols

   lc_stage_col_types = [
		'A1',
		'A2',
		'A3',
		'A123',
		'A4',
		'A5',
		'B1',
		'B2',
		'B3',
		'B123',
		'B4',
		'B5',
		'B6',
		'B7',
		'C1',
		'C2',
		'C3',
		'C4',
		'C1234',
		'D'
   ]

   return lc_stage_col_types
 end

 def nice_lc_stage_lookup

   lookup = {
		'A1' => 'A1',
		'A2' => 'A2',
		'A3' => 'A3',
		'A123' => 'A1-A3',
		'A4' => 'A4',
		'A5' => 'A5',
		'B1' => 'B1',
		'B2' => 'B2',
		'B3' => 'B3',
		'B123' => 'B1-3',
		'B4' => 'B4',
		'B5' => 'B5',
		'B6' => 'B6',
		'B7' => 'B7',
		'C1' => 'C1',
		'C2' => 'C2',
		'C3' => 'C3',
		'C4' => 'C4',
		'C1234' => 'C1-4',
		'D' => 'D'
   }

   return lookup
 end

# normalization values for creating weighted normalized average - Environmental Impact Score (EIS)
 # def norm_values
 
   # norm = {
     # 'globalWarmingPotential' => 7.16E+12,	### These values need to be updated!!!!!
     # 'acidificationPotential' => 1.66E+12,
     # 'respiratoryEffects' => 2.24E+10,
     # 'eutrophicationPotential' => 1.01E+10,
	 # 'ozoneDepletionPotential' => 51000000,
     # 'smogPotential' => 4.64E+11,
     # 'totalPrimaryEnergy' => 1.2E+14
   # }
   # return norm
 # end

# create warnings results
 def get_warning_data(out, runner)

   # Create array of rows
   rows = []

   # Create Headers for the table
   header_row = []
   header_row << 'System'
   header_row << 'Warning'
   rows << header_row

   # Find warning objects in the "out" file
   lciaResults = out['lciaResults']
   warnings = lciaResults['warnings']
   runner.registerInfo("Warnings: #{warnings}")

   # For each warning, populate a row and add to rows
   if not warnings.nil?
     warnings.each do |warning|
       row = []
       row << warning['system']
       row << warning['warning']
       rows << row
     end
   # return rows
   end
   runner.registerInfo("Rows: #{rows}")

   len = rows.length
   if len == 1
     row = []
     row << ''
     row << 'You have no warnings.'
     rows << row
   end
   return rows
 end
 
def make_table_1(csv_rows, t1_rows, pie_chart_data, pie_chart_data_2, lciaResults, runner)

  data1 = lciaResults["buildingComponentFlowsTotal"]
  data2 = lciaResults["energyUseFlows"]
  
  data1row = data1["totalBuildingComponentFlows"]
  data2row = data2["totalEnergy"]

  # Create Headers for the Table
  header_row = []
  header_row << 'Category'
  header_row += flow_col_headers
  csv_rows << header_row
  t1_rows << header_row
  
  row1 = []
  row2 = []
  row3 = []
  row1 << get_nice_subcategory_name("totalBuildingComponentFlows")
  row2 << get_nice_subcategory_name("totalEnergy")
  row3 << "Whole Building Total"  
  
  flow_cols.each do |flow_col|
    data1 = data1row[flow_col].round(10)
    row1 << data1
    data2 = data2row[flow_col].round(10)
    row2 << data2
    data3 = data1 + data2
    row3 << data3
  end
  
  #fill pie chart data (GWP)
  data1 = data1row['globalWarmingPotential']
  data2 = data2row['globalWarmingPotential']
  
  pie_chart_data << { 
    'Flows' => 'Total Building Component Flows',
    'Global Warming (kg CO2 eq)' => data1
  }
  pie_chart_data << { 
    'Flows' => 'Total Energy Flows',
    'Global Warming (kg CO2 eq)' => data2
  }
  #runner.registerInfo("pie_chart_data = #{pie_chart_data}")
  
  #fill pie chart 2 data (Primary Energy)
  data1_2 = data1row['totalPrimaryEnergy']
  data2_2 = data2row['totalPrimaryEnergy']
  
  pie_chart_data_2 << { 
    'Flows' => 'Total Building Component Flows',
    'Primary Energy (MJ)' => data1_2
  }
  pie_chart_data_2 << { 
    'Flows' => 'Total Energy Flows',
    'Primary Energy (MJ)' => data2_2
  }
  #runner.registerInfo("pie_chart_data_2 = #{pie_chart_data_2}")

  csv_rows << row1 << row2 << row3
  t1_rows << row1 << row2 << row3
end
 
def make_table_2(csv_rows, t2_rows, bar_chart_data, bar_chart_data_2, lciaResults, runner)

  data1 = lciaResults["buildingComponentFlowsTotalByYear"]
  data2 = lciaResults["energyUseFlowsByYear"]

  # Create Headers for the Table
  header_row = []
  header_row << 'Category'
  header_row << 'Year'
  header_row += flow_col_headers
  csv_rows << header_row
  t2_rows << header_row

  # put two arrays together
  combinedData = data1.zip data2
  
  combinedData.each do |yearly_data|
    data1row = yearly_data[0]
    data2row = yearly_data[1]
	year = data1row["year"]
	#runner.registerInfo("yearly_data: #{yearly_data}")

	data1subrow = data1row["totalBuildingComponentFlows"]
    data2subrow = data2row["totalEnergy"]

	#runner.registerInfo("year: #{year}")
	#runner.registerInfo("data1row: #{data1row}")
	#runner.registerInfo("data2row: #{data2row}")
    #runner.registerInfo("data1subrow: #{data1subrow}")
	#runner.registerInfo("data2subrow: #{data2subrow}")
	
	if !data1subrow.nil?
      row1 = []
      row2 = []
      row1 << get_nice_subcategory_name("totalBuildingComponentFlows") << year
      row2 << get_nice_subcategory_name("totalEnergy") << year
    
      flow_cols.each do |flow_col|
        data1 = data1subrow[flow_col]
        row1 << data1
        data2 = data2subrow[flow_col]
        row2 << data2
	  end
      csv_rows << row1 << row2
      t2_rows << row1 << row2

      data1 = data1subrow['globalWarmingPotential']
      data2 = data2subrow['globalWarmingPotential']
      bar_chart_data << {
        "Global Warming (kg CO2 eq)" => data1,
        "Year" => year,
        "Flows" => "Total Building Component Flows"
      }

      bar_chart_data << {
        "Global Warming (kg CO2 eq)" => data2,
        "Year" => year,
        "Flows" => "Total Energy Flows"
      }
	  
	  #fill bar chart 2 data (Primary Energy)
	  data1_2 = data1subrow['totalPrimaryEnergy']
	  data2_2 = data2subrow['totalPrimaryEnergy']
	  
	  bar_chart_data_2 << {
        "Primary Energy (MJ)" => data1_2,
        "Year" => year,
        "Flows" => "Total Building Component Flows"
      }

      bar_chart_data_2 << {
        "Primary Energy (MJ)" => data2_2,
        "Year" => year,
        "Flows" => "Total Energy Flows"
      }
	  #runner.registerInfo("bar_chart_data_2 = #{bar_chart_data_2}")

    end
  end
end
 
def read_section_a(csv_rows, t_rows, lciaResults, cat_name, flow_cols, runner)

  result = lciaResults[cat_name]
  nice_cat_name = get_nice_category_name(cat_name)

  # Create Headers for the Table
  header_row = []
  header_row << 'Category'
  header_row << 'Subcategory'
  header_row += flow_col_headers
  csv_rows << header_row
  t_rows << header_row

  runner.registerInfo("--------process section: #{nice_cat_name}--------")
  # Loop through each building component
  result.each do |comp_type|
	#runner.registerInfo("comp_type: #{comp_type}")
	comp_type_name = comp_type[0]
	#runner.registerInfo("comp_type_name: #{comp_type_name}")
	
	nice_subcategory_name = get_nice_subcategory_name(comp_type[0])
	#runner.registerInfo("comp_type_name: #{comp_type_name}")
	if nice_subcategory_name.include? "Unrecognized"
	  next
	end
	comp_type_flow = comp_type[1]
	#runner.registerInfo("comp_type_flow: #{comp_type_flow}")
	unless comp_type_flow.nil? 
		row = []
		row << nice_cat_name
		row << nice_subcategory_name
		flow_cols.each do |flow_col|
			#runner.registerInfo("flow_col: #{flow_col}")
			comp_flow_value = comp_type_flow[flow_col]
			if not comp_flow_value.is_a? Numeric
			  runner.registerInfo("flow_col not a number: #{flow_col}")
			  next				
			end
			#runner.registerInfo("comp_flow_value: #{comp_flow_value}")
			row << comp_flow_value.round(15)
		end
		if row.count > 2
		  csv_rows << row
		  t_rows << row
		  #runner.registerInfo("Row Added: #{row}")
		end
	end
  end  

end
 
def read_section_b(csv_rows, t_rows, lciaResults, cat_name, flow_cols, runner)

  result = lciaResults[cat_name]
  nice_cat_name = get_nice_category_name(cat_name)
  
  header_row = []
  header_row << 'Category'
  header_row << 'Subcategory'
  header_row << 'Year'
  header_row += flow_col_headers
  csv_rows << header_row
  t_rows << header_row

  runner.registerInfo("--------process section: #{nice_cat_name}--------")
  year = 0

  # loop through years
  result.each do |yearly_data|
    # Loop through each building component
    #runner.registerInfo("year: #{yearly_data["year"]}")
	year = yearly_data["year"]
    yearly_data.each do |comp_type|
	  #runner.registerInfo("comp_type: #{comp_type}")
	
	  nice_subcategory_name = get_nice_subcategory_name(comp_type[0])
	  if nice_subcategory_name.include? "Unrecognized"
	    next
	  end

	  #runner.registerInfo("comp_type_name: #{comp_type_name}")
	  comp_type_flow = comp_type[1]
	  #runner.registerInfo("comp_type_flow: #{comp_type_flow}")
	  unless comp_type_flow.nil?
		row = []
		row << nice_cat_name
		row << nice_subcategory_name
		row << year
		flow_cols.each do |flow_col|
		  #runner.registerInfo("flow_col: #{flow_col}")
		  comp_flow_value = comp_type_flow[flow_col]
		  if not comp_flow_value.is_a? Numeric
			runner.registerInfo("flow_col not a number: #{flow_col}")
		    next				
		  end
		  #runner.registerInfo("comp_flow_value: #{comp_flow_value}")
		  row << comp_flow_value.round(15)
		end
		if row.count > 3
		  csv_rows << row
		  t_rows << row
	      #runner.registerInfo("Row Added: #{row}")
		end
      end
    end
  end
  
end
 
def read_section_c(csv_rows, t_rows, lciaResults, cat_name, runner)

  result = lciaResults[cat_name]
  nice_cat_name = get_nice_category_name(cat_name)

  # Create Headers for the Table
  header_row = []
  header_row << 'Category'
  header_row << 'Subcategory'
  header_row << 'Stage'
  header_row += flow_col_headers
  csv_rows << header_row
  t_rows << header_row

  runner.registerInfo("--------process section: #{nice_cat_name}--------")
  # Loop through each building component
  result.each do |comp_type|
	#runner.registerInfo("comp_type: #{comp_type}")
    nice_subcategory_name = get_nice_subcategory_name(comp_type[0])
	if nice_subcategory_name.include? "Unrecognized"
	  next
	end
	comp_type_flow = comp_type[1]
	#runner.registerInfo("comp_type_flow: #{comp_type_flow}")
	unless comp_type_flow.nil?
	    lc_stage_cols.each do |lc_stage_col|
		  row = []
		  row << nice_cat_name
		  row << nice_subcategory_name
          lc_stage_col_nice = nice_lc_stage_name(lc_stage_col)
		  row << lc_stage_col_nice
          flow_cols.each do |flow_col|
		    comp_flow_value = comp_type_flow[flow_col]
		    #runner.registerInfo("comp_flow_value: #{comp_flow_value}")
		    lc_stage = comp_flow_value[lc_stage_col]
			#runner.registerInfo("lc_stage: #{lc_stage}")
			if not lc_stage.is_a? Numeric
			  runner.registerInfo("lc_stage not a number: #{lc_stage}")
			  runner.registerInfo("lc_stage_col: #{lc_stage_col}")
			  next				
			end
			row << lc_stage.round(15)
		  end
		  if row.count > 3
		    csv_rows << row
		    t_rows << row
		    #runner.registerInfo("Row Added: #{row}")
		  end
		end
	end
  end  

end
 
def read_section_d(csv_rows, t_rows, lciaResults, cat_name, runner)

  result = lciaResults[cat_name]
  nice_cat_name = get_nice_category_name(cat_name)

  # Create Headers for the Table
  header_row = []
  header_row << 'Category'
  header_row << 'Subcategory'
  header_row << 'Year'
  header_row << 'Stage'
  header_row += flow_col_headers
  csv_rows << header_row
  t_rows << header_row

  runner.registerInfo("--------process section: #{nice_cat_name}--------")
  year = 0
  #loop through each year
  result.each do |yearly_data|
	
    #runner.registerInfo("year: #{yearly_data["year"]}")
	year = yearly_data["year"]
    # Loop through each building component	
	yearly_data.each do |comp_type|
	  #runner.registerInfo("comp_type: #{comp_type}")

	  nice_subcategory_name = get_nice_subcategory_name(comp_type[0])
	  if nice_subcategory_name.include? "Unrecognized"
	    next
	  end
	  comp_type_flow = comp_type[1]
	  unless comp_type_flow.nil?
	    lc_stage_cols.each do |lc_stage_col|
		  row = []
		  row << nice_cat_name
		  row << nice_subcategory_name
		  row << year
          lc_stage_col_nice = nice_lc_stage_name(lc_stage_col)
		  row << lc_stage_col_nice
          flow_cols.each do |flow_col|
		    comp_flow_value = comp_type_flow[flow_col]
		    #runner.registerInfo("comp_flow_value: #{comp_flow_value}")
		    lc_stage = comp_flow_value[lc_stage_col]
		    #runner.registerInfo("lc_stage: #{lc_stage}")
		    if not lc_stage.is_a? Numeric
		      runner.registerInfo("lc_stage not a number: #{lc_stage}")
		      runner.registerInfo("lc_stage_col: #{lc_stage_col}")
		      next				
		    end
		    row << lc_stage.round(15)
		  end
		  if row.count > 4
		    csv_rows << row
		    t_rows << row
		    #runner.registerInfo("Row Added: #{row}")
		  end
		end
	  end
	end
  end  

end


# get LCIA results data to include in csv file and report tables
def get_lcia_results_summary_data(out,runner,flow_cols)

  # Create Array of rows
  csv_rows = []
  t1_rows =[]
  t2_rows =[]
  t3_rows =[]
  t4_rows =[]
  t5_rows =[]
  t6_rows =[]
  t7_rows =[]
  t8_rows =[]
  pie_chart_data = []
  pie_chart_data_2 = []
  bar_chart_data = []
  bar_chart_data_2 = []
  
  #Find LCIA Results
  
  # Total Flows over the study period
   
  lciaResults = out['lciaResults']
  
  make_table_1(csv_rows, t1_rows, pie_chart_data, pie_chart_data_2, lciaResults, runner)
  csv_rows << [] # add blank row between tables

  make_table_2(csv_rows, t2_rows, bar_chart_data, bar_chart_data_2, lciaResults, runner)
  csv_rows << [] # add blank row between tables
  
  read_section_a(csv_rows, t3_rows, lciaResults, "buildingComponentFlowsTotal", flow_cols, runner)
  csv_rows << [] # add blank row between tables
  read_section_a(csv_rows, t4_rows, lciaResults, "energyUseFlows", flow_cols, runner)
  csv_rows << [] # add blank row between tables

  read_section_b(csv_rows, t5_rows, lciaResults, "buildingComponentFlowsTotalByYear", flow_cols, runner)
  csv_rows << [] # add blank row between tables
  read_section_b(csv_rows, t6_rows, lciaResults, "energyUseFlowsByYear", flow_cols, runner)
  csv_rows << [] # add blank row between tables

  read_section_c(csv_rows, t7_rows, lciaResults, "buildingComponentFlows", runner)
  csv_rows << [] # add blank row between tables

  read_section_d(csv_rows, t8_rows, lciaResults, "buildingComponentFlowsByYear", runner)
  csv_rows << [] # add blank row between tables

  #runner.registerInfo("LCIA Summary Data Rows Finished: #{rows}")

  # Total Flows over the study period by Life Cycle Stage
  # tot_flow_type = 'totalFlow'
  # tot_flow_sub_type = 'LifeCycle'
  # tot_flow = out[tot_flow_type]
  # out['yearlyFlows'].each do |yearly_flow|
    # year = yearly_flow['year']
    # if year = 40
      # tot_flow = yearly_flow['totalFlowsWConstruction']
    # end
  # end
  # # Skip this flow type if information not included in results
  # unless tot_flow.nil?
    # row = []
    # row << nice_category_name(tot_flow_type)
    # row << nice_category_name(tot_flow_sub_type)
    # flow_cols.each do |flow_col|
      # row << tot_flow[flow_col].round(2)
    # end
    # rows << row
  # end

  return csv_rows, t1_rows, t2_rows, t3_rows, t4_rows, t5_rows, t6_rows, t7_rows, t8_rows, pie_chart_data, pie_chart_data_2, bar_chart_data, bar_chart_data_2
end

# Calculates the Normalized Wegithed Average Results. Not being used.
# def get_eis_by_category_chart(out, user_env_wts)

  # # Get the summary results from the raw data
  # summary_table = get_lcia_results_summary_data(out)
  
  # # Get the header lookups
  # header_keys = header_lookup
  # header_keys_2 = header_lookup_2

  # # Find the Total Flow data
  # impacts = {}
  # summary_table.each do |row|
    # next unless row.first == 'Total Flow'
    # hdrs = summary_table.first
    # hdrs.shift(2)
    # row.shift(2)
    # hdrs.zip(row).each do |hdr, val|
      # impacts[header_keys.key(hdr)] = val
    # end
  # end

  # # Add the custom weights to the weights
  # env_wts = env_weighting_factors
  # us_av = norm_values
  # env_wts['User Input'] = user_env_wts

  # # Create a weighted
  # chart_1_data = []
  # env_wts.each do |type, wts|
    # wts.each do |category, wt|
      # if impacts[category].nil?
        # category = header_keys_2.key(category)
      # end
      # unwtd_impact = impacts[category]
      # next if unwtd_impact.nil?
      # # Normalizes the impact and multiplies by US population
      # wtd_impact = (unwtd_impact / us_av[category]) * wt/100 * 308745538
      # chart_1_data << {
        # 'Weighting Approach' => type,
        # 'Impact Category' => category,
        # 'EIS' => wtd_impact
      # }
    # end
  # end

  # return chart_1_data
# end

# def get_eis_table(out, user_env_wts)

  # # Get the summary results from the raw data
  # summary_table = get_lcia_results_summary_data(out)
  
  # # Get the header lookups
  # header_keys = header_lookup
  # header_keys_2 = header_lookup_2

  # # Add the custom weights to the weights
  # env_wts = env_weighting_factors
  # env_wts['User Input'] = user_env_wts
  # us_av = norm_values
  
  # # Flow types
  # flow_types = ['LifeCycle', 'Total MRR', 'All Construction', 'Total Energy']

  # # Calculate the combined weighted EIS scores
  # # for each type of flow
  # eis_table = []
  # flow_types.each do |flow_type|
  
    # # Get the flow data from the summary table
    # impacts = {}
    # summary_table.each do |row|
      # if row[1] == flow_type
        # hdrs = summary_table.first[2..summary_table.first.size]
        # vals = row[2..summary_table.first.size]
        # hdrs.zip(vals).each do |hdr, val|
          # key = header_keys.key(hdr)
          # impacts[key] = val
        # end
        # break
      # end
    # end

    # # puts "Impact vals for #{flow_type}:"
    # # puts JSON.pretty_generate(impacts)

    # # Loop through the weighting approaches
    # # and calculate the total weight for each.
    # headers = ['Category']  
    # row = [flow_type]
    # env_wts.each do |type, wts|
      # headers << type
      # tot_wtd_eis = 0
      # wts.each do |category, wt|
        # unwtd_impact = impacts[category]
        # unwtd_impact = impacts[header_keys_2.key(category)] if unwtd_impact.nil?
        # norm_key = us_av[category]
        # norm_key = us_av[header_keys_2.key(category)] if norm_key.nil?
        # next if unwtd_impact.nil?
        # next if norm_key.nil?
        # #wtd_impact = unwtd_impact * wt/100
        # # Normalizes the impact and multiplies by US population
        # wtd_impact = (unwtd_impact / norm_key) * wt/100 * 308745538
        # # puts "#{flow_type} #{type} #{category} = #{unwtd_impact} / #{us_av[category]} * #{wt}% = #{wtd_impact}"
        # tot_wtd_eis += wtd_impact
      # end
      # # puts "#{flow_type} #{type} total = #{tot_wtd_eis}"
      # row << tot_wtd_eis.round
    # end
    # eis_table[0] = headers
    # eis_table << row

  # end

  # return eis_table
# end

# def get_eis_by_building_chart(eis_table)
  # categories = eis_table.first
  # data = []
  # eis_table.each do |row|
    # next if row[0] == 'Category'
    # next if row[0] == 'LifeCycle'
    # row.each_with_index do |cell, i|
      # next if i == 0
      # data << {
        # 'Category' => row[0],
        # 'Weighting Approach' => eis_table.first[i],
        # 'EIS' => cell
      # }
    # end
  # end

  # return data
# end