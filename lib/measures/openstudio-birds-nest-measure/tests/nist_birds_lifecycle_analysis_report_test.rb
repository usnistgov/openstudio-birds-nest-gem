# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Sustainable Energy, LLC.
# See also https://openstudio.net/license
# *******************************************************************************

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class NISTBIRDSLifecycleAnalysisReport_Test < MiniTest::Test

  # class level variable
  @@co = OpenStudio::Runmanager::ConfigOptions.new(true)
  
  def epw_path
    # make sure we have a weather data location
    assert(!@@co.getDefaultEPWLocation.to_s.empty?)
    epw = @@co.getDefaultEPWLocation / OpenStudio::Path.new("USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw")
    assert(File.exist?(epw.to_s))
    
    return epw.to_s
  end

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    return "#{File.dirname(__FILE__)}/output/#{test_name}"
  end
  
  def model_out_path(test_name)
    return "#{run_dir(test_name)}/test_model.osm"
  end
  
  def sql_path(test_name)
    return "#{run_dir(test_name)}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
  end
  
  def report_path(test_name)
    return "#{run_dir(test_name)}/report.html"
  end

  # create test files if they do not exist when the test first runs 
  def setup_test(test_name, idf_output_requests)
  
    # Skip all setup if the sql file already exists
    #return true if File.exist?(sql_path(test_name))

    @@co.findTools(false, true, false, true)
    
    model_in_path = "#{File.dirname(__FILE__)}/#{test_name}.osm"
    
    if !File.exist?(run_dir(test_name))
      FileUtils.mkdir_p(run_dir(test_name))
    end
    assert(File.exist?(run_dir(test_name)))
    
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end

    assert(File.exist?(model_in_path))
    
    if File.exist?(model_out_path(test_name))
      FileUtils.rm(model_out_path(test_name))
    end

    # convert output requests to OSM for testing, OS App and PAT will add these to the E+ Idf 
    workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel, "EnergyPlus".to_IddFileType)
    workspace.addObjects(idf_output_requests)
    rt = OpenStudio::EnergyPlus::ReverseTranslator.new
    request_model = rt.translateWorkspace(workspace)
    
    versionTranslator = OpenStudio::OSVersion::VersionTranslator.new 
    model = versionTranslator.loadModel(model_in_path)
    if model.empty?
      puts "Version translation failed for #{model_path_string}"
      exit
    else
      model = model.get
    end

    model.addObjects(request_model.objects)
    model.save(model_out_path(test_name), true)

    if !File.exist?(sql_path(test_name))
      puts "Running EnergyPlus"

      wf = OpenStudio::Runmanager::Workflow.new("modeltoidf->energypluspreprocess->energyplus")
      wf.add(@@co.getTools())
      job = wf.create(OpenStudio::Path.new(run_dir(test_name)), OpenStudio::Path.new(model_out_path(test_name)), OpenStudio::Path.new(epw_path))

      rm = OpenStudio::Runmanager::RunManager.new
      rm.enqueue(job, true)
      rm.waitForFinished
    end
  end

  def dont_test_large_office
  
    test_name = "LargeOffice-DOE Ref 1980-2004-ASHRAE 169-2006-2A"

    # create an instance of the measure
    measure = NISTBIRDSLifecycleAnalysisReport.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{test_name}.osm"))
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{test_name}.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get    
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
    "birds_ip_address" => "192.168.56.101",
    "birds_port" => "8080",
    "results_type" => "Example results",
    "com_res" => "Commercial",
    "bldg_type" => "Office",
    "const_qual" => "Average",
    "state_city" => "TX - Houston",
    "county" => "Harris",
    "study_period" => 25,
    "pct_inc_lts" => 25,
    "pct_mh_lts" => 25,
    "pcf_cfl_lf_lts" => 25,
    "pct_led_lts" => 25,
    "found_chars" => "Basement, Slab R-10, Wall R-25",
    "pri_hvac" => "Comm_PVAV_Reheat",
    "sec_hvac" => "Comm_PSZ_AC",
    "hh_cancer" => 8,
    "global_warming" => 18,
    "acidification" => 5,
    "hh_respiratory" => 7,
    "hh_noncancer" => 5,
    "ozone_depletion" => 5,
    "eutrophication" => 5,
    "smog" => 7,
    "ecotoxicity" => 12,
    "embodied_energy" => 7,
    "land_use" => 18,
    "water_consumption" => 3,
    "env_pref" => "Annualized"
    }   
   
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val), "Could not set #{name} to #{val}")
      argument_map[name] = arg
      i += 1
    end
    
    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)

    # mimic the process of running this measure in OS App or PAT
    setup_test(test_name, idf_output_requests)
    
    assert(File.exist?(model_out_path(test_name)))
    assert(File.exist?(sql_path(test_name)))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))
    
    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
    ensure
      Dir.chdir(start_dir)
    end
    
    # make sure the report file exists
    #assert(File.exist?(report_path(test_name)))
  end

  def test_nzertf
  
    test_name = "NZERTF"

    # create an instance of the measure
    measure = NISTBIRDSLifecycleAnalysisReport.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{test_name}.osm"))
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{test_name}.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get    
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments()
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new 

    # Set argument values
    arg_values = {
    "birds_ip_address" => "192.168.56.101",
    "birds_port" => "8080",
    "results_type" => "Actual results", # Change to Example results to test
    "com_res" => "LowRiseResidential",
    "bldg_type" => "SingleFamilyAttached",
    "const_qual" => "Custom",
    "state_city" => "VA - Richmond",
    "county" => "Arlington",
    "study_period" => 25,
    "pct_inc_lts" => 0,
    "pct_mh_lts" => 0,
    "pcf_cfl_lf_lts" => 50,
    "pct_led_lts" => 50,
    "found_chars" => "Basement, Slab R-0, Wall R-15",
    "pri_hvac" => "Resid_AirtoAirHeatPump",
    "sec_hvac" => "None",
    "hh_cancer" => 8,
    "global_warming" => 18,
    "acidification" => 5,
    "hh_respiratory" => 7,
    "hh_noncancer" => 5,
    "ozone_depletion" => 5,
    "eutrophication" => 5,
    "smog" => 7,
    "ecotoxicity" => 12,
    "embodied_energy" => 7,
    "land_use" => 18,
    "water_consumption" => 3,
    "env_pref" => "Annualized"
    }   
   
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val), "Could not set #{name} to #{val}")
      argument_map[name] = arg
      i += 1
    end
    
    # get the energyplus output requests, this will be done automatically by OS App and PAT
    idf_output_requests = measure.energyPlusOutputRequests(runner, argument_map)

    # mimic the process of running this measure in OS App or PAT
    setup_test(test_name, idf_output_requests)
    
    assert(File.exist?(model_out_path(test_name)))
    assert(File.exist?(sql_path(test_name)))
    assert(File.exist?(epw_path))

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path(test_name)))
    runner.setLastEpwFilePath(epw_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path(test_name)))

    # delete the output if it exists
    if File.exist?(report_path(test_name))
      FileUtils.rm(report_path(test_name))
    end
    assert(!File.exist?(report_path(test_name)))
    
    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin
      Dir.chdir(run_dir(test_name))

      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      show_output(result)
      assert_equal("Success", result.value.valueName)
    ensure
      Dir.chdir(start_dir)
    end
    
    # make sure the report file exists
    #assert(File.exist?(report_path(test_name)))
  end
  
end
