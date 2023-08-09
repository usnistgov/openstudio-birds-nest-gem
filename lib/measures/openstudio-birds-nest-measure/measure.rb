# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/
#Runners have been added throughout for validation. Just uncomment the runners to see where the code errors out.

require 'erb'
require 'json'
require 'net/http'
require "#{File.dirname(__FILE__)}/resources/Construction"
require "#{File.dirname(__FILE__)}/resources/Material"
require "#{File.dirname(__FILE__)}/resources/Infiltration"
require "#{File.dirname(__FILE__)}/resources/HVACandDHW"
require "#{File.dirname(__FILE__)}/resources/Solar"
#require "#{File.dirname(__FILE__)}/resources/HVACSizing.Model"
require "#{File.dirname(__FILE__)}/resources/Standards.Space"
require "#{File.dirname(__FILE__)}/resources/Standards.ThermalZone"
require "#{File.dirname(__FILE__)}/resources/Standards.ScheduleConstant"
require "#{File.dirname(__FILE__)}/resources/Standards.ScheduleCompact"
require "#{File.dirname(__FILE__)}/resources/Standards.ScheduleRuleset"
require "#{File.dirname(__FILE__)}/resources/ParseResults"
require "#{File.dirname(__FILE__)}/resources/Walls"
require "#{File.dirname(__FILE__)}/resources/SummaryCharacteristics"
require "#{File.dirname(__FILE__)}/resources/Lighting"
require "#{File.dirname(__FILE__)}/resources/Appliances"
require "#{File.dirname(__FILE__)}/resources/AtticAndRoof"
require "#{File.dirname(__FILE__)}/resources/AnnualEnergyUse"
require "#{File.dirname(__FILE__)}/resources/DefineArguments"
require "#{File.dirname(__FILE__)}/resources/HVACDistributionSystems"
require "#{File.dirname(__FILE__)}/resources/Floors"

BIRDS_NEST_POLL_TIME = 5 # seconds
MAX_REFRESH_ATTEMPTS = 5

#start the measure
class NISTBIRDSNESTLCIAReport < OpenStudio::Measure::ReportingMeasure

  # human readable name for the measure
  def name
    return "NIST BIRDS NEST - V2021"
  end

  # human readable description for the measure
  def description
    return "Residential Building Life-Cycle Impact Assessment"
  end

  # human readable description of modeling approach
  def modeler_description
    return "For single-family detached homes only."
  end

  #########################################################
  #Create what the OS User will see and Input
  #########################################################

  # define the arguments that the user will input. These args will be compiled into objects for the json file.
  def arguments(model = nil)
    return define_arguments
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)
    result = OpenStudio::IdfObjectVector.new
    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # Use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    api_url = runner.getStringArgumentValue('api_url', user_arguments)
    api_refresh_url = runner.getStringArgumentValue('api_refresh_url', user_arguments)
    api_refresh_token = runner.getStringArgumentValue('birds_api_refresh_token', user_arguments)

    # Assign the user inputs to variables.
    #birds_ip_address = runner.getStringArgumentValue('birds_ip_address',user_arguments)
    #birds_port = runner.getStringArgumentValue('birds_port',user_arguments)
    birds_api_key = runner.getStringArgumentValue('birds_api_key', user_arguments)
    if birds_api_key == '[Contact NIST for custom key]'
      birds_api_key = 'test_key'
    end

    com_res = runner.getStringArgumentValue('com_res', user_arguments)
    bldg_type = runner.getStringArgumentValue('bldg_type', user_arguments)
    const_qual = runner.getStringArgumentValue('const_qual', user_arguments)
    #state_city = runner.getStringArgumentValue('state_city',user_arguments)
    state = runner.getStringArgumentValue('state', user_arguments)
    city = runner.getStringArgumentValue('city', user_arguments)
    zip = runner.getIntegerArgumentValue('zip', user_arguments)
    climate_zone = runner.getStringArgumentValue('climate_zone', user_arguments)
    num_bedrooms = runner.getIntegerArgumentValue('num_bedrooms', user_arguments)
    num_bathrooms = runner.getIntegerArgumentValue('num_bathrooms', user_arguments)

    pct_inc_lts = runner.getDoubleArgumentValue('pct_inc_lts', user_arguments)
    pct_mh_lts = runner.getDoubleArgumentValue('pct_mh_lts', user_arguments)
    pcf_cfl_lf_lts = runner.getDoubleArgumentValue('pcf_cfl_lf_lts', user_arguments)
    pct_led_lts = runner.getDoubleArgumentValue('pct_led_lts', user_arguments)

    door_mat = runner.getStringArgumentValue('door_mat', user_arguments)
    attic_type = runner.getStringArgumentValue('attic_type', user_arguments)
    found_chars = runner.getStringArgumentValue('found_chars', user_arguments)

    pri_hvac = runner.getStringArgumentValue('pri_hvac', user_arguments)
    #sec_hvac = runner.getStringArgumentValue('sec_hvac',user_arguments)

    panel_type = runner.getStringArgumentValue('panel_type', user_arguments)
    inverter_type = runner.getStringArgumentValue('inverter_type', user_arguments)
    panel_country = runner.getStringArgumentValue('panel_country', user_arguments)

    solar_thermal_sys_type = runner.getStringArgumentValue('solar_thermal_sys_type', user_arguments)
    solar_thermal_collector_type = runner.getStringArgumentValue('solar_thermal_collector_type', user_arguments)
    solar_thermal_loop_type = runner.getStringArgumentValue('solar_thermal_loop_type', user_arguments)

    pct_ductwork_inside = runner.getDoubleArgumentValue('pct_ductwork_inside', user_arguments)
    ductwork = runner.getStringArgumentValue('ductwork', user_arguments)

    appliance_clothes_washer = runner.getStringArgumentValue('appliance_clothes_washer', user_arguments)
    appliance_clothes_dryer = runner.getStringArgumentValue('appliance_clothes_dryer', user_arguments)
    appliance_cooking_range = runner.getStringArgumentValue('appliance_cooking_range', user_arguments)
    appliance_dishwasher = runner.getStringArgumentValue('appliance_dishwasher', user_arguments)
    appliance_frig = runner.getStringArgumentValue('appliance_frig', user_arguments)
    appliance_freezer = runner.getStringArgumentValue('appliance_freezer', user_arguments)

    # Check the totals for the lighting types
    tot_lts = pct_inc_lts + pct_mh_lts + pcf_cfl_lf_lts + pct_led_lts
    unless tot_lts == 100
      runner.registerError("The lighting type percentages must add up to 100.")
      return false
    end

    # Assign the user inputs to the operational energy LCIA data options.
    oper_energy_lcia = runner.getStringArgumentValue('oper_energy_lcia', user_arguments)

    # Assign the user inputs to environmental impact variables.
    # env_wts = {}
    # env_wts['Global Warming'] = runner.getDoubleArgumentValue('global_warming',user_arguments)
    # env_wts['Acidification'] = runner.getDoubleArgumentValue('acidification',user_arguments)
    # env_wts['HH_Respiratory'] = runner.getDoubleArgumentValue('hh_respiratory',user_arguments)
    # env_wts['Ozone Depletion'] = runner.getDoubleArgumentValue('ozone_depletion',user_arguments)
    # env_wts['Eutrophication'] = runner.getDoubleArgumentValue('eutrophication',user_arguments)
    # env_wts['Smog'] = runner.getDoubleArgumentValue('smog',user_arguments)
    # env_wts['Primary Energy'] = runner.getDoubleArgumentValue('primary_energy',user_arguments)
    # runner.registerInfo("Environmental Weight for Global Warming is #{env_wts['Global Warming']}.")
    # runner.registerInfo("Environmental Weight for Primary Energy is #{env_wts['Primary Energy']}.")

    # Check the totals for the env weights
    # tot_env_impact = 0
    # env_wts.each do |cat, def_wt|
    # cat_var = cat.downcase.gsub(' ','_').to_s
    # env_wt = runner.getDoubleArgumentValue(cat_var,user_arguments)
    # env_wts[cat] = env_wt
    # tot_env_impact += env_wt
    # end
    # unless tot_env_impact == 100
    # runner.registerError("The environmental impact weights must add up to 100.")
    # return false
    # end

    # Create User Assumptions object (includes LCIA assumptions only; commented out environmental weights)
    user_lcia_assumptions = nil

    # Add environmental weighting assumptions to the user assumptions object
    #environmental_weights = {
    # 'globalWarming' => env_wts['Global Warming'],
    # 'acidification' => env_wts['Acidification'],
    # 'hhRespiratory' => env_wts['HH_Respiratory'],
    # 'ozoneDepletion' => env_wts['Ozone Depletion'],
    # 'eutrophication' => env_wts['Eutrophication'],
    # 'smog' => env_wts['Smog'],
    # 'primaryEnergy' => env_wts['Primary Energy']
    # }
    # user_lcia_assumptions << environmental_weights

    # Add operational energy LCIA data to the user assumptions object
    # can add values to the array as desired, starting with environmental impact weights
    user_lcia_assumptions = {
      'electricityFuelMixProjection' => oper_energy_lcia
    }

    # Define Study Period Variable
    study_period = runner.getIntegerArgumentValue('study_period', user_arguments)

    # Define Life Cycle Stages to Include
    lc_stage = runner.getStringArgumentValue('lc_stage', user_arguments)

    # Get the last model, IDF, and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    idf = runner.lastEnergyPlusWorkspace
    if idf.empty?
      runner.registerError('Cannot find last idf.')
      return false
    end
    idf = idf.get

    sql = runner.lastEnergyPlusSqlFile
    if sql.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sql = sql.get
    model.setSqlFile(sql)

    # Get the weather file
    epw = model.weatherFile
    if epw.empty?
      runner.registerError('There is no weather file assigned to this model, cannot determine building location.')
      return false
    end
    epw = epw.get

    #######################################################
    #Create JSON File and populate with all objects
    #BIRDS NEST Objects are included in birds[]
    #######################################################

    # Top-level output file
    birds = {}

    ##############################################################################
    #Summary Characteristics
    ##############################################################################

    summary_char = SummaryCharacteristics.new
    birds['summaryCharacteristics'] = summary_char.get_summary_characteristics(model, runner, state, city,
                                                                               epw.country, climate_zone, zip, com_res, bldg_type, const_qual, num_bedrooms, num_bathrooms, study_period, lc_stage)
    runner.registerInfo("Summary Characteristics object has been generated.")

    #################################################################################################
    # Air Infiltration
    #################################################################################################

    birds['airInfiltration'] = get_airinfiltration(model, runner, idf)
    runner.registerInfo("Air Infiltration object has been generated.")

    #################################################################################################
    # Lighting
    #The code could be cleaned up to be more concise.
    ################################################################################################

    birds['lighting'] = get_lighting(idf, runner, model, pct_inc_lts, pct_mh_lts, pcf_cfl_lf_lts, pct_led_lts)
    runner.registerInfo("Lighting object has been generated.")

    ######################################
    # Solar PV - calls on Solar.rb
    ######################################
    # See resources/Solar.rb for implementation
    #Currently only includes "simple PV" objects. Needs to be expanded to other E+ PV object types.

    birds['photovoltaics'] = get_solar_pvs(idf, model, runner, user_arguments, sql, panel_type, inverter_type, panel_country)
    runner.registerInfo("solar PV object reported.")

    ######################################
    # Solar Thermal - calls on Solar.rb
    ######################################
    # See resources/Solar.rb for implementation
    #Currently only includes "flat plate" objects. Needs to be expanded to other E+ solar thermal object types.

    birds['solarThermals'] = get_hw_solar_thermals(model, runner, user_arguments, sql,
                                                   solar_thermal_sys_type, solar_thermal_collector_type, solar_thermal_loop_type)
    runner.registerInfo("solar thermal object reported.")

    ######################################
    # HVAC Heat Cool - calls on user inputs and HVAC.rb
    ######################################

    # Call on HVAC Heating and Cooling System Object from HVACandDHW.rb file.
    birds['hvacHeatCools'] = get_hvac_heat_cool(model, runner, user_arguments, idf)

    ######################################
    # HVAC Distribution Systems - user defined values
    ######################################
    birds['hvacDistributions'] = get_hvac_dist_sys(runner, pct_ductwork_inside, ductwork,
                                                   summary_char.numberOfStoriesAboveGrade, summary_char.conditioned_floor_area, model)
    runner.registerInfo("Added all air distn systems to object.")

    ######################################
    # HVAC Ventilation - calls on user inputs and HVACandDHW.rb
    ######################################
    # Ventilation equipment could be installed at the zone level or within an air loop.
    #Currently only the zone equipment is accessed.
    runner.registerInfo("Moving on to HVAC ventilation equipment.")

    # See resources/HVACandDWH.rb for implementation
    birds['mechanicalVentilations'] = get_hvac_ventilation(model, runner)
    runner.registerInfo("successfully called on HVAC Ventilation Object.")

    #######################################################################
    # HVAC - Moisture Controls
    #####################################################################

    birds['moistureControls'] = get_moisture_controls(runner, model)

    ######################################
    # DHW - Water Heaters - calls on user inputs and HVACandDHW.rb
    ######################################
    # See resources/HVACandDHW.rb for implementation
    birds['waterHeatingSystems'] = get_water_heaters(model, runner)
    runner.registerInfo("Successfully called on DHW Water Heater Object.")

    #######################################################################
    # DHW - Water Distributions
    #####################################################################

    birds['hotWaterDistributions'] = get_water_distributions(runner, summary_char.conditioned_floor_area, num_bathrooms)

    #############################################################
    # Appliances
    #############################################################

    birds['appliances'] = get_appliances(runner, appliance_clothes_washer, appliance_clothes_dryer,
                                         appliance_cooking_range, appliance_frig, appliance_dishwasher, appliance_freezer)

    ###################################################
    # Resource Use - Currently Annual Energy Use - Pulls from the SQL results file.
    ###################################################

    get_annual_energyuse(birds, runner, sql, user_arguments)

    ###################################################
    # User LCIA Assumptions - environmental weighting and operational energy LCIA data
    # Currently Not Supported in Enumerations
    ###################################################

    birds['userAssumptions'] = user_lcia_assumptions

    ######################################################################################################
    # Building Envelope - calls on material.rb and construction.rb to find assemblies by charactersitics.
    # Requires the use of the CEC enumerations for materials in order to work.
    ######################################################################################################
    # Building envelope requires the most significant re-write because we need to report details on each surface.
    # The prior version aggregated up characteristics by exterior surface types: walls, roofs, foundations, windows, doors.
    # Windows and doors (fenestration) are embedded within each surface as a subsurface,
    # and now must be reported in that manner.

    #####################################
    #Walls
    #####################################

    birds['walls'] = build_walls_array(idf, model, runner, user_arguments, sql)
    runner.registerInfo("Found all Walls.")

    #######################################################
    # AtticAndRoofs
    #######################################################

    #birds['roofs'] = build_roofs_array(idf, model, runner, user_arguments, sql)
    #runner.registerInfo("Found all Roofs.")

    #birds['attics'] = get_attics(idf, model, runner, user_arguments, sql)
    #runner.registerInfo("Found all Attics.")

    birds['atticAndRoofs'] = get_atticandroof3(idf, model, runner, user_arguments, sql)
    runner.registerInfo("Found all Attics and Roofs #3.")

    #######################################################
    # Foundations - Bottom Floor
    #######################################################

    birds['foundations'] = get_foundations(idf, model, runner, user_arguments, sql)
    runner.registerInfo("Completed Foundations.")

    #######################################################
    # Foundations Walls - Currently the Walls include foundation walls.
    # Need to restrict Walls and mirror the code.
    #######################################################

    birds['foundationWalls'] = build_foundation_walls_array(idf, model, runner, user_arguments, sql)
    runner.registerInfo("Completed Foundation Walls.")

    #######################################################
    # FrameFloors -
    #######################################################

    #birds['frameFloors'] = build_frame_floors_array(idf, model, runner, user_arguments, sql)
    #runner.registerInfo("Completed Frame Floors.")

    birds['frameFloors'] = build_frame_floors_minus_slab_and_attic_array(idf, model, runner, user_arguments, sql)
    runner.registerInfo("Completed Frame Floors excluding slab and attic array.")

    #######################################################
    # Finished the data pull.
    #######################################################
    runner.registerInfo("Completed Data Pull from OSM and E+.")
    #####################################
    #Creating and Sending JSON File - Place at the end of the code that has been updated to generate the json file for debugging current progress.
    #####################################
    runner.registerInfo("Now writing JSON File.")
    # write JSON file out for debugging
    json_out_path = "./nist_birds_input.json"
    File.open(json_out_path, 'w') do |file|
      file << JSON.pretty_generate(birds)
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # Call the BIRDS NEST API
    runner.registerInfo("Now communicating with BIRDS NEST.")
    birds_json = JSON.generate(birds)

    result = get_response(runner, api_url, birds_api_key, birds_json, api_refresh_url, api_refresh_token)

    if result.nil?
      runner.registerInfo("Cannot parse output.")
      return
    end

    lcia = JSON.parse(result)

    runner.registerInfo('Getting output file.')

    # Write the server response to JSON for debugging
    json_out_path = "./nist_birds_response.json"
    full_csv_out_path = File.expand_path(json_out_path)
    puts full_csv_out_path
    File.open(json_out_path, 'w') do |file|
      file.puts(JSON.pretty_generate(lcia))
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    runner.registerInfo('Output written to file.')

    ######################################################################
    #Reporting BIRDS NEST Output
    ######################################################################
    # Here is where the Measure starts dealing with the Output File
    # Parse the response into the HTML file

    # Table of Building Characteristics - these are a list of the user inputs in the measure
    user_ins_table = []
    user_ins_table << ['Building Parameter', 'Value (user input)']
    user_ins_table << ['Building Category', com_res]
    user_ins_table << ['Building Type', bldg_type]
    user_ins_table << ['State', state]
    user_ins_table << ['City', city]
    user_ins_table << ['ZIP Code', zip]
    user_ins_table << ['Climate Zone', climate_zone]
    user_ins_table << ['Bedrooms', num_bedrooms]
    user_ins_table << ['Bathrooms', num_bathrooms]
    user_ins_table << ['Door Material', door_mat]
    user_ins_table << ['Incandescent Lights (%)', pct_inc_lts]
    user_ins_table << ['Metal Halide Lights (%)', pct_mh_lts]
    user_ins_table << ['Compact Fluorescent Lights (%)', pcf_cfl_lf_lts]
    user_ins_table << ['LED Lights', pct_led_lts]
    #user_ins_table << ['Foundation', found_chars]
    #user_ins_table << ['Primary HVAC Type', pri_hvac]
    #user_ins_table << ['Secondary HVAC Type', sec_hvac]
    user_ins_table << ['Foundation Characteristics', found_chars]
    user_ins_table << ['HVAC System', pri_hvac]
    user_ins_table << ['Photovoltaics - Panels', panel_type]
    user_ins_table << ['Photovoltaics - Inverters', inverter_type]
    user_ins_table << ['Photovoltaics - Source Country', panel_country]
    user_ins_table << ['Solar Thermal - Type', solar_thermal_sys_type]
    user_ins_table << ['Solar Thermal - Collector Type', solar_thermal_collector_type]
    user_ins_table << ['Solar Thermal - Loop Type', solar_thermal_loop_type]
    user_ins_table << ['HVAC Ductwork - Fraction Inside', pct_ductwork_inside]
    user_ins_table << ['HVAC Ductwork - Type', ductwork]
    user_ins_table << ['Clothes Washer', appliance_clothes_washer]
    user_ins_table << ['Clothes Dryer', appliance_clothes_dryer]
    user_ins_table << ['Cooking Range', appliance_cooking_range]
    user_ins_table << ['Dishwasher', appliance_dishwasher]
    user_ins_table << ['Refrigerator', appliance_frig]
    user_ins_table << ['Freezer', appliance_freezer]
    user_ins_table << ['Operational Energy LCIA Data', oper_energy_lcia]
    user_ins_table << ['Study Period', study_period]
    #runner.registerInfo("User Input Table values created: #{user_ins_table}.")

    # LCIA Impact Weights - these are provided by the user in the measure
    # env_wts_table = []
    # env_wts_table << ['Category', 'Value (user input %)']
    # env_wts_table << ['Global Warming', env_wts['Global Warming']]
    # env_wts_table << ['Acidification', env_wts['Acidification']]
    # env_wts_table << ['HH_Respiratory', env_wts['HH_Respiratory']]
    # env_wts_table << ['Ozone Depletion', env_wts['Ozone Depletion']]
    # env_wts_table << ['Eutrophication', env_wts['Eutrophication']]
    # env_wts_table << ['Smog', env_wts['Smog']]
    # env_wts_table << ['Primary Energy', env_wts['Primary Energy']]

    #runner.registerInfo("LCIA Impact Weights Table created: #{env_wts_table}.")

    # Warning Table
    warnings_table = get_warning_data(lcia, runner)

    #runner.registerInfo("Warning Table Created: #{warnings_table}.")

    csv_warnings_table = get_warning_data(lcia, runner)

    #runner.registerInfo('CSV Warnings Table Created.')

    # LCIA Results Summary Table
    # teogwp = Total Embodied & Operational GWP
    csv_summary_table, table1, table2, table3, table4, table5, table6, table7, table8, pie_chart_data, pie_chart_data_2, bar_chart_data, bar_chart_data_2 = get_lcia_results_summary_data(lcia, runner, flow_cols)
    teogwp_pie_chart_data = JSON.generate(pie_chart_data)
    teoe_pie_chart_data = JSON.generate(pie_chart_data_2)
    teogwp_yearly_chart_data = JSON.generate(bar_chart_data)
    teoe_yearly_chart_data = JSON.generate(bar_chart_data_2)
    #runner.registerInfo('Summary Tables Created.')

    # Yearly flow detail tables
    #all_table_data, all_table_titles = get_annual_data_and_titles(lcia)
    #csv_all_table_data, csv_all_table_titles = get_annual_data_and_titles(lcia)

    #runner.registerInfo('Yearly Flow Tables Created.')

    # Combine all the data for the CSV
    csv_data = []

    #runner.registerInfo('CSV Data Collected.')

    # Add the summary flows
    csv_summary_table.each_with_index do |row, i|
      # see if the row has any breaks in it
      if row.any? { |s|
        #only check if s is a string
        if s.is_a? String
          s.include?('</br>')
        end
      }
        # Split the header into 2 rows (separate row for units)
        h1 = []
        h2 = []
        row.each do |cell|
          splits = cell.split('</br>')
          if splits
            h1 << splits[0]
            h2 << splits[1]
          else
            h1 << ''
            h2 << cell
          end
        end
        csv_data += [h1, h2]
      else
        csv_data << row
      end
    end

    #runner.registerInfo('CSV Summary Table with Index.')

    # Add the annual flows
    #csv_all_table_data.zip(csv_all_table_titles).each do |table, title|
    #  # remove the header row
    #  table.shift
    #  # add the title to the first column
    #  table.each_with_index do |row, i|
    #    if i == 0
    #      row.unshift(title)
    #    else
    #      row.unshift('')
    #    end
    #  end
    # Add the modified table to the CSV data
    #  csv_data += table
    #end

    #runner.registerInfo('CSV Data ZIP.')

    # Get the total flow data
    #eis_by_category_chart_data = JSON.generate(get_eis_by_category_chart(lcia, env_wts))

    # Get the EIS data
    #eis_table = get_eis_table(lcia, env_wts)

    # Get the EIS by building category data
    #eis_by_building_chart_data = JSON.generate(get_eis_by_building_chart(eis_table))

    web_asset_path = OpenStudio.getSharedResourcesPath() / OpenStudio::Path.new("web_assets")
    runner.registerInfo('Created Web Asset Path.')

    # Define the csv path
    csv_out_path = "./report.csv"
    full_csv_out_path = File.expand_path(csv_out_path)
    puts full_csv_out_path

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
    runner.registerInfo('Set HTML Template Path.')
    if File.exist?(html_in_path)
      html_in_path = html_in_path
    else
      html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
    end
    html_in = ""
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end
    runner.registerInfo('Read in HTML Template.')

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)
    runner.registerInfo('Configured template with variable values.')

    # write html file
    html_out_path = "./report.html"
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end
    runner.registerInfo('Wrote HTML File.')

    # write the data to a CSV file
    File.open(csv_out_path, 'w') do |file|
      csv_data.each do |row|
        file.puts row.join(',')
      end
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # close the sql file
    sql.close()

    return true

  end

  def try_with_refresh(state)
    # Attempts to run the given block and if it returns Net::HTTPUnauthorized, then the state is updated with a
    # refreshed API key and the block is re-run up to a maximum number of retries.
    tries = 0

    while (response = yield(state)).kind_of? Net::HTTPUnauthorized and tries < MAX_REFRESH_ATTEMPTS do
      state.refresh_key
      tries += 1

      sleep(BIRDS_NEST_POLL_TIME)
    end

    if tries >= MAX_REFRESH_ATTEMPTS and response.nil?
      raise RuntimeError.new("Could not refresh API token.")
    else
      response
    end
  end

  def get_request(uri, key, body)
    # Returns a new POST request for the BIRDS NEST API
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{key}"
    request["Accept"] = 'application/json'
    request["Content-Type"] = 'application/json'
    request.body = body

    request
  end

  def get_poll_request(uri, key)
    # Returns a new GET request to poll the BIRDS NEST API for a result of a running calculation.
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{key}"
    request["Accept"] = 'application/json'
    request["Content-Type"] = 'application/json'

    request
  end

  def do_request(uri, request)
    # Sends the given request to the given URI
    Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true, :read_timeout => 600, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
  end

  def get_response(runner, url, key, body, refresh_url, refresh_key)
    # Main method for calling the BIRDS NEST API. Creates the state object, starts the calculation, and gets the result.
    # Returns the result if the calculation is successful, otherwise nil.
    runner.registerInfo("Connecting to Birds Nest API.")

    # Create state used to create requests
    state = BirdsNestState.new(runner, url, key, refresh_url, refresh_key, body)

    # Start BIRDS NEST calculation
    task_path = try_with_refresh(state) do |s|
      start_birds_nest_calculation(s)
    end

    # If starting the calculation failed, log and return nil.
    if task_path.nil?
      runner.registerError("Could not complete request.")
      return nil
    end

    # Begin polling for result and return when successful.
    try_with_refresh(state) do |s|
      poll_birds_nest_result(s, task_path)
    end
  end

  def start_birds_nest_calculation(state)
    # Sends the request to the BIRDS NEST API and returns the result. Returns the redirect path if the request was
    # successful, Net::HTTPUnauthorized if the key is invalid and a new one needs to be generated, or nil if another
    # error occurs.
    runner = state.runner

    uri = URI(state.url)
    response = do_request(uri, get_request(uri, state.key, state.body))

    case response
    when Net::HTTPRedirection
      runner.registerInfo("Birds Nest calculation successfully started.")
      response["location"]
    when Net::HTTPUnauthorized
      response
    else
      runner.registerError("Could not complete request! Response: #{response}")
      nil
    end
  end

  def poll_birds_nest_result(state, path)
    # Polls the BIRDS NEST API in order to retrieve result of previously started calculation. Returns the body of the
    # response if it is successful, Net::HTTPUnauthorized if the key is invalid and a new one needs to be obtained, or
    # nil if another error occurs.
    runner = state.runner

    uri = URI::HTTPS.build(host: URI(state.url).hostname, path: path)
    request = get_poll_request(uri, state.key)

    while true do
      response = do_request(uri, request)

      case response
      when Net::HTTPAccepted
        runner.registerInfo("Calculation still running, checking again in #{BIRDS_NEST_POLL_TIME} seconds")
      when Net::HTTPOK
        runner.registerInfo("Calculation result retrieved.")
        return response.body
      when Net::HTTPGone
        runner.registerError("Calculation results already retrieved and removed. Try another request.")
        return nil
      when Net::HTTPUnprocessableEntity
        runner.registerError("An error occurred during the calculation. Check inputs and try again.")
        return nil
      when Net::HTTPUnauthorized
        return response
      else
        runner.registerError("An error occurred, please try again. Error: #{response}")
        return nil
      end

      sleep(BIRDS_NEST_POLL_TIME)
    end
  end

end

# register the measure to be used by the application
NISTBIRDSNESTLCIAReport.new.registerWithApplication

class BirdsNestState
  attr_accessor :runner, :url, :key, :body

  def initialize(runner, url, key, refresh_url, refresh_key, body)
    @runner = runner
    @url = url
    @key = key
    @refresh_url = refresh_url
    @refresh_key = refresh_key
    @body = body
  end

  def refresh_key
    # Attempts to refresh the API key with the refresh url and refresh key provided at object creation.
    @runner.registerInfo("Attempting to refresh API token.")

    # Send refresh request
    uri = URI(@refresh_url)
    response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true, :read_timeout => 600, :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(get_refresh_request(uri))
    end

    # If the request failed, log an error and raise and exception
    unless response.kind_of? Net::HTTPSuccess
      @runner.registerError("Could not refresh API token. Is the refresh URL correct and the refresh token valid?")
      return
    end

    # Parse key from response
    json = JSON.parse(response.body)
    new_key = json["access"]

    # Check that key was successfully parsed
    if new_key.nil?
      @runner.registerError("Unexpected refresh response. Was: #{json}")
      raise RuntimeError.new("Unexpected refresh response. Was: #{json}")
    end

    # Set instance variable to newly retrived key
    @key = new_key
  end

  def get_refresh_request(uri)
    # Returns a new POST request to refresh the BIRDS NEST API access token
    request = Net::HTTP::Post.new(uri)
    request["Accept"] = 'application/json'
    request["Content-Type"] = 'application/json'
    request.body = "{\"refresh\": \"#{@refresh_key}\"}"
    request
  end
end