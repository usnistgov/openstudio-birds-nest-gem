# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/
# Runners have been added throughout for validation. Just uncomment the runners to see where the code errors out.

require 'erb'
require 'json'
require 'net/http'
require_relative 'resources/Construction'
require_relative 'resources/Material'
require_relative 'resources/Infiltration'
require_relative 'resources/HVACandDHW'
require_relative 'resources/Solar'
require_relative 'resources/Standards.Space'
require_relative 'resources/Standards.ThermalZone'
require_relative 'resources/Standards.ScheduleConstant'
require_relative 'resources/Standards.ScheduleCompact'
require_relative 'resources/Standards.ScheduleRuleset'
require_relative 'resources/ParseResults'
require_relative 'resources/Walls'
require_relative 'resources/SummaryCharacteristics'
require_relative 'resources/Lighting'
require_relative 'resources/Appliances'
require_relative 'resources/AtticAndRoof'
require_relative 'resources/AnnualEnergyUse'
require_relative 'resources/DefineArguments'
require_relative 'resources/HVACDistributionSystems'
require_relative 'resources/Floors'

BIRDS_NEST_POLL_TIME = 5 # seconds
MAX_REFRESH_ATTEMPTS = 5

# start the measure
class NISTBIRDSNESTLCIAReport < OpenStudio::Measure::ReportingMeasure

  # human readable name for the measure
  def name
    'NIST BIRDS NEST - V2021'
  end

  # human readable description for the measure
  def description
    'Residential Building Life-Cycle Impact Assessment'
  end

  # human readable description of modeling approach
  def modeler_description
    'For single-family detached homes only.'
  end

  #########################################################
  # Create what the OS User will see and Input
  #########################################################

  # define the arguments that the user will input. These args will be compiled into objects for the json file.
  def arguments(model = nil)
    define_arguments
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)
    OpenStudio::IdfObjectVector.new
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # Use the built-in error checking
    return false unless runner.validateUserArguments(arguments, user_arguments)

    api_url = runner.getStringArgumentValue('api_url', user_arguments)
    api_refresh_url = runner.getStringArgumentValue('api_refresh_url', user_arguments)
    api_refresh_token = runner.getStringArgumentValue('birds_api_refresh_token', user_arguments)

    # Assign the user inputs to variables
    birds_api_key = runner.getStringArgumentValue('birds_api_key', user_arguments)
    birds_api_key = 'test_key' if birds_api_key == '[Contact NIST for custom key]'

    com_res = runner.getStringArgumentValue('com_res', user_arguments)
    bldg_type = runner.getStringArgumentValue('bldg_type', user_arguments)
    const_qual = runner.getStringArgumentValue('const_qual', user_arguments)
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
    found_chars = runner.getStringArgumentValue('found_chars', user_arguments)

    pri_hvac = runner.getStringArgumentValue('pri_hvac', user_arguments)

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
      runner.registerError('The lighting type percentages must add up to 100.')
      return false
    end

    # Assign the user inputs to the operational energy LCIA data options.
    oper_energy_lcia = runner.getStringArgumentValue('oper_energy_lcia', user_arguments)

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
    # Create JSON File and populate with all objects
    # BIRDS NEST Objects are included in birds[]
    #######################################################

    # Top-level output file
    birds = {}

    ##############################################################################
    # Summary Characteristics
    ##############################################################################

    summary_char = SummaryCharacteristics.new
    birds['summaryCharacteristics'] = summary_char.get_summary_characteristics(
      model, runner, state, city, epw.country, climate_zone, zip, com_res, bldg_type, const_qual, num_bedrooms,
      num_bathrooms, study_period, lc_stage
    )
    runner.registerInfo('Summary Characteristics object has been generated.')

    #################################################################################################
    # Air Infiltration
    #################################################################################################

    birds['airInfiltration'] = get_airinfiltration(model, runner)
    runner.registerInfo('Air Infiltration object has been generated.')

    #################################################################################################
    # Lighting
    # The code could be cleaned up to be more concise.
    ################################################################################################

    birds['lighting'] = get_lighting(idf, pct_inc_lts, pct_mh_lts, pcf_cfl_lf_lts, pct_led_lts, model, runner)
    runner.registerInfo('Lighting object has been generated.')

    ######################################
    # Solar PV - calls on Solar.rb
    ######################################
    # See resources/Solar.rb for implementation
    # Currently only includes "simple PV" objects. Needs to be expanded to other E+ PV object types.

    birds['photovoltaics'] =
      get_solar_pvs(idf, model, runner, sql, panel_type, inverter_type, panel_country)
    runner.registerInfo('solar PV object reported.')

    ######################################
    # Solar Thermal - calls on Solar.rb
    ######################################
    # See resources/Solar.rb for implementation
    # Currently only includes "flat plate" objects. Needs to be expanded to other E+ solar thermal object types.

    birds['solarThermals'] = get_hw_solar_thermals(model, runner, user_arguments, sql,
                                                   solar_thermal_sys_type, solar_thermal_collector_type, solar_thermal_loop_type)
    runner.registerInfo('solar thermal object reported.')

    ######################################
    # HVAC Heat Cool - calls on user inputs and HVAC.rb
    ######################################

    # Call on HVAC Heating and Cooling System Object from HVACandDHW.rb file.
    birds['hvacHeatCools'] = get_hvac_heat_cool(model, runner, user_arguments, idf)

    ######################################
    # HVAC Distribution Systems - user defined values
    ######################################
    birds['hvacDistributions'] = get_hvac_dist_sys(runner, pct_ductwork_inside, ductwork,
                                                   summary_char.num_stories_above_grade, summary_char.conditioned_floor_area, model)
    runner.registerInfo('Added all air distn systems to object.')

    ######################################
    # HVAC Ventilation - calls on user inputs and HVACandDHW.rb
    ######################################
    # Ventilation equipment could be installed at the zone level or within an air loop.
    # Currently only the zone equipment is accessed.
    runner.registerInfo('Moving on to HVAC ventilation equipment.')

    # See resources/HVACandDWH.rb for implementation
    birds['mechanicalVentilations'] = get_hvac_ventilation(model, runner)
    runner.registerInfo('successfully called on HVAC Ventilation Object.')

    #######################################################################
    # HVAC - Moisture Controls
    #####################################################################

    birds['moistureControls'] = get_moisture_controls(model)

    ######################################
    # DHW - Water Heaters - calls on user inputs and HVACandDHW.rb
    ######################################
    # See resources/HVACandDHW.rb for implementation
    birds['waterHeatingSystems'] = get_water_heaters(model, runner)
    runner.registerInfo('Successfully called on DHW Water Heater Object.')

    #######################################################################
    # DHW - Water Distributions
    #####################################################################

    birds['hotWaterDistributions'] = get_water_distributions(num_bathrooms, summary_char.conditioned_floor_area)

    #############################################################
    # Appliances
    #############################################################

    birds['appliances'] = get_appliances(appliance_clothes_washer, appliance_clothes_dryer,
                                         appliance_cooking_range, appliance_frig, appliance_dishwasher, appliance_freezer)

    ###################################################
    # Resource Use - Currently Annual Energy Use - Pulls from the SQL results file.
    ###################################################

    birds['annualEnergyUses'] = get_annual_energyuse(runner, sql, user_arguments)
    birds['annualWaterUses'] = annual_water_usage(sql)

    ###################################################
    # User LCIA Assumptions - environmental weighting and operational energy LCIA data
    # Currently Not Supported in Enumerations
    ###################################################
    #
    # Add operational energy LCIA data to the user assumptions object
    # can add values to the array as desired, starting with environmental impact weights
    birds['userAssumptions'] = {
      'electricityFuelMixProjection' => oper_energy_lcia
    }

    ######################################################################################################
    # Building Envelope - calls on material.rb and construction.rb to find assemblies by charactersitics.
    # Requires the use of the CEC enumerations for materials in order to work.
    ######################################################################################################
    # Building envelope requires the most significant re-write because we need to report details on each surface.
    # The prior version aggregated up characteristics by exterior surface types: walls, roofs, foundations, windows, doors.
    # Windows and doors (fenestration) are embedded within each surface as a subsurface,
    # and now must be reported in that manner.

    #####################################
    # Walls
    #####################################

    birds['walls'] = build_walls_array(idf, model, runner, user_arguments, sql)
    runner.registerInfo('Found all Walls.')

    #######################################################
    # AtticAndRoofs
    #######################################################

    birds['atticAndRoofs'] = get_atticandroof3(idf, model, runner, user_arguments, sql)
    runner.registerInfo('Found all Attics and Roofs #3.')

    #######################################################
    # Foundations - Bottom Floor
    #######################################################

    birds['foundations'] = get_foundations(idf, model, runner, user_arguments, sql)
    runner.registerInfo('Completed Foundations.')

    #######################################################
    # Foundations Walls - Currently the Walls include foundation walls.
    # Need to restrict Walls and mirror the code.
    #######################################################

    birds['foundationWalls'] = build_foundation_walls_array(idf, model, runner, user_arguments, sql)
    runner.registerInfo('Completed Foundation Walls.')

    #######################################################
    # FrameFloors -
    #######################################################

    birds['frameFloors'] = build_frame_floors_minus_slab_and_attic_array(idf, model, runner, user_arguments, sql)
    runner.registerInfo('Completed Frame Floors excluding slab and attic array.')

    #######################################################
    # Finished the data pull.
    #######################################################
    runner.registerInfo('Completed Data Pull from OSM and E+.')
    #####################################
    # Creating and Sending JSON File - Place at the end of the code that has been updated to generate the json file for debugging current progress.
    #####################################
    runner.registerInfo('Now writing JSON File.')
    # write JSON file out for debugging
    json_out_path = './nist_birds_input.json'
    File.open(json_out_path, 'w') do |file|
      file << JSON.pretty_generate(birds)
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue StandardError
        file.flush
      end
    end

    # Call the BIRDS NEST API
    runner.registerInfo('Now communicating with BIRDS NEST.')
    birds_json = JSON.generate(birds)

    result = get_response(runner, api_url, birds_api_key, birds_json, api_refresh_url, api_refresh_token)

    if result.nil?
      runner.registerInfo('Cannot parse output.')
      return
    end

    lcia = JSON.parse(result)

    runner.registerInfo('Getting output file.')

    # Write the server response to JSON for debugging
    json_out_path = './nist_birds_response.json'
    full_csv_out_path = File.expand_path(json_out_path)
    puts full_csv_out_path
    File.open(json_out_path, 'w') do |file|
      file.puts(JSON.pretty_generate(lcia))
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue StandardError
        file.flush
      end
    end

    runner.registerInfo('Output written to file.')

    ######################################################################
    # Reporting BIRDS NEST Output
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

    # LCIA Results Summary Table
    csv_summary_table, = get_lcia_results_summary_data(lcia, runner, flow_cols)

    # Combine all the data for the CSV
    csv_data = []

    # Add the summary flows
    csv_summary_table.each do |row|
      # see if the row has any breaks in it
      if row.any? do |s|
        # only check if s is a string
        s.include?('</br>') if s.is_a? String
      end
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

    runner.registerInfo('Created Web Asset Path.')

    # Define the csv path
    csv_out_path = './report.csv'
    full_csv_out_path = File.expand_path(csv_out_path)
    puts full_csv_out_path

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
    runner.registerInfo('Set HTML Template Path.')
    html_in_path = if File.exist?(html_in_path)
                     html_in_path
                   else
                     "#{File.dirname(__FILE__)}/report.html.erb"
                   end
    html_in = ''
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end
    runner.registerInfo('Read in HTML Template.')

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)
    runner.registerInfo('Configured template with variable values.')

    # write html file
    html_out_path = './report.html'
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue StandardError
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
      rescue StandardError
        file.flush
      end
    end

    # close the sql file
    sql.close

    true

  end

  def try_with_refresh(state)
    # Attempts to run the given block and if it returns Net::HTTPUnauthorized, then the state is updated with a
    # refreshed API key and the block is re-run up to a maximum number of retries.
    tries = 0

    while (response = yield(state)).is_a?(Net::HTTPUnauthorized) && (tries < MAX_REFRESH_ATTEMPTS)
      state.refresh_key
      tries += 1

      sleep(BIRDS_NEST_POLL_TIME)
    end

    raise 'Could not refresh API token.' if (tries >= MAX_REFRESH_ATTEMPTS) && response.nil?

    response
  end

  def get_request(uri, key, body)
    # Returns a new POST request for the BIRDS NEST API
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{key}"
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/json'
    request.body = body

    request
  end

  def get_poll_request(uri, key)
    # Returns a new GET request to poll the BIRDS NEST API for a result of a running calculation.
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{key}"
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/json'

    request
  end

  def do_request(uri, request)
    # Sends the given request to the given URI
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 600, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
  end

  def get_response(runner, url, key, body, refresh_url, refresh_key)
    # Main method for calling the BIRDS NEST API. Creates the state object, starts the calculation, and gets the result.
    # Returns the result if the calculation is successful, otherwise nil.
    runner.registerInfo('Connecting to Birds Nest API.')

    # Create state used to create requests
    state = BirdsNestState.new(runner, url, key, refresh_url, refresh_key, body)

    # Start BIRDS NEST calculation
    task_path = try_with_refresh(state) do |s|
      start_birds_nest_calculation(s)
    end

    # If starting the calculation failed, log and return nil.
    if task_path.nil?
      runner.registerError('Could not complete request.')
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
      runner.registerInfo('Birds Nest calculation successfully started.')
      response['location']
    when Net::HTTPUnauthorized
      response
    when Net::HTTPBadRequest
      runner.registerError('Bad Request!')
      runner.registerError(response.body.to_s)
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

    loop do
      response = do_request(uri, request)

      case response
      when Net::HTTPAccepted
        runner.registerInfo("Calculation still running, checking again in #{BIRDS_NEST_POLL_TIME} seconds")
      when Net::HTTPOK
        runner.registerInfo('Calculation result retrieved.')
        return response.body
      when Net::HTTPGone
        runner.registerError('Calculation results already retrieved and removed. Try another request.')
        return nil
      when Net::HTTPUnprocessableEntity
        runner.registerError('An error occurred during the calculation. Check inputs and try again.')
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
    @runner.registerInfo('Attempting to refresh API token.')

    # Send refresh request
    uri = URI(@refresh_url)
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 600,
                               verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(get_refresh_request(uri))
    end

    # If the request failed, log an error and raise and exception
    unless response.is_a? Net::HTTPSuccess
      @runner.registerError('Could not refresh API token. Is the refresh URL correct and the refresh token valid?')
      return
    end

    # Parse key from response
    json = JSON.parse(response.body)
    new_key = json['access']

    # Check that key was successfully parsed
    if new_key.nil?
      @runner.registerError("Unexpected refresh response. Was: #{json}")
      raise "Unexpected refresh response. Was: #{json}"
    end

    # Set instance variable to newly retrived key
    @key = new_key
  end

  def get_refresh_request(uri)
    # Returns a new POST request to refresh the BIRDS NEST API access token
    request = Net::HTTP::Post.new(uri)
    request['Accept'] = 'application/json'
    request['Content-Type'] = 'application/json'
    request.body = "{\"refresh\": \"#{@refresh_key}\"}"
    request
  end
end
