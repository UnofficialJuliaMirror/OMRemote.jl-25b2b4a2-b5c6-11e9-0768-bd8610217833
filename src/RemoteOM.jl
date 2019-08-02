module RemoteOM
  # (C) Christian Kral, 2017-2019
  #
  # RemoteOM remote access to OpenModeloca from Julia
  #
  # Version 0.1.0, 2017-07-17
  #   Initial version (original name OM)
  # Version 0.2.0, 2017-07-26
  #   Fixed issue with external libraries to be simulated
  #   Fixed issue with mkdir of tmp/OpenModelica
  #   Added work files
  # Version 0.3.0, 2017-07-26
  #   Added version of
  #   Fixed issue with mkdir of tmp/OpenModelica
  #   Added work files
  # Version 1.0.0, 2017-07-26
  #   Added version options of system libaries
  #   Added documentation
  # Version 1.1.0, 2017-08-04
  #   Added parameter Interval to simulateOM
  #   Improved logging of simualtion parameters
  # Version 1.1.1, 2017-08-04
  #   Fixed bug with parameter numberOfIntervals insteady of Interval of
  #     simulation call in simulateOM
  #   Changed colorRel2 and colorRel3
  # Version 1.2.0, 2017-08-06
  #   Updated color combinations and added lineStyle and lineWidth
  # Version 1.2.1, 2017-08-06
  #   Fixed missing export of lineStyle and lineWidth
  # Version 1.2.2, 2017-08-06
  #   Fixed spelling of lineWidth1 (-> lineWidth)
  # Version 1.3.0, 2017-08-06
  #   Changed color scheme of colorRel3 -> "0.7"
  # Version 1.4.0, 2017-08-06
  #   Changed color scheme of colorVoltage2 <-> colorVoltage3
  # Version 2.0.0, 2017-08-08
  #   Non-backwards compatible change Interval to NumberOfIntervals
  #   Improved assembling of simulation optional arguments
  #   Changed pattern of dashed line
  #   Moved all plotting related schemes to PlotEdu
  #   Now simulateOM returns to the orignal directory from where started
  # Version 2.1.0, 2017-09-30
  #   Added function to read result file
  # Version 3.0.0, 2019-XX-XX
  #   Published open source under the name RemoteOM
  #   https://gitlab.com/christiankral/RemoteOM.git

  using PyCall
  using Base
  @pyimport OMPython
  @pyimport DyMat

  export envOM, simulateOM, loadResultOM

  function envOM(env...)
    # Set environment variables
    if length(env) == 0
      println("Setting environment for OpenModelica: OPENMODELICAHOME=/usr/")
      ENV["OPENMODELICAHOME"] = "/usr/"
    else
      println("Setting environment for OpenModelica: OPENMODELICAHOME="*env)
      ENV["OPENMODELICAHOME"] = env[1]
    end
  end

  """
  # Function call

  `simulateOM(model;sysLibs="Modelica", sysVers="", workFiles="", files="",
  workDir="/work", simDir="/tmp/OpenModelica",
  StartTime=0, StopTime=0, Tolerance=1E-6)`

  # Description

  This function simulates and OpenModelica model and returns a result
  variable read by DyMat

  # Variables

  `model` Modelica experiment to be simulated (incl. dot notation)

  `sysLibs` Modelica system libraries included by OpenModelica; default
            is the Modelica Standard Library (MLS) "Modelica"; several
            libraries may be separated by `:`

  `sysVers` Versions of system libaries (::String); the number of versions seperated
            by `:` has to be equal to the number of system libraries seperated
            by `:`

  `workFiles` Modelica files to be loaded, which, e.g., contain `model`; the
              Modelica files have to be located in in `workDir`; several
              files may be separated by `:`

  `files` Additional Modelica files to be loaded; the absolute file path has
          to be provided in order to read the file properly; several
          files may be separated by `:`

  `workDir` Working directory; default value = "/work"

  `simDir` Simulation directory, default value = "/tmp/OpenModelica"

  `StartTime` Start time of simulation; default value = 0

  `StopTime` Stop time of simulation; if the StopTime <= StartTime,
             the original setting from the Experiment
             annotation is used; default value = 0

  `Tolerance` Simulation tolerance; default value = 1E-6

  `NumberOfIntervals` Nuber of output intervals; default value = 500
  """
  function simulateOM(model;sysLibs="Modelica",sysVers="",workFiles="",files="",
                      workDir="/work",simDir="/tmp/OpenModelica",
                      StartTime=0,StopTime=0,Tolerance=1E-6,NumberOfIntervals=500)

    localDir=pwd()
    # Load MSL and libraries (separated by :) and simulate model
    # Result determined by DyMat is return argument

    # Set environment variable for system libraries
    envOM()

    # Exstension of result file, created by OpenModelica
    resExt = "_res.mat"
    rm(simDir,force=true,recursive=true)
    mkdir(simDir)
    cd(simDir)
    omc = OMPython.OMCSessionZMQ()
    # Change directory in OM
    omc[:sendExpression]("cd(\""*simDir*"\")")

    # Set system directory
    # sysDir = ENV["OPENMODELICAHOME"]*"/"*sysdir*"/"

    # Load system libraries
    sysLibsList = split(sysLibs,":")
    sysVersList = split(sysVers,":")
    for k in collect(1:length(sysLibsList))
      # Determine name of system library
      sysLib = sysLibsList[k]
      if length(sysLibsList)>length(sysVersList)
        # Not every sysLib entry has a version number
        # In this case the version number is not treated at all
        if sysLib!=""
          print("  loadModel("*sysLib*")")
          status = omc[:sendExpression]("loadModel("*sysLib*")")
          if status==true
            println(" successful")
          else
            println(" failed")
          end
        end
      elseif length(sysLibsList)==length(sysVersList)
        # Every sysLib entry has a version number
        # In this case the version number is treated
        # Determine version of system library
        sysVer = sysVersList[k]
        if sysLib!=""
          if sysVer==""
            print("  loadModel("*sysLib*")")
            status = omc[:sendExpression]("loadModel("*sysLib*")")
          else
            print("  loadModel("*sysLib*",{\""*sysVer*"\"})")
            status = omc[:sendExpression]("loadModel("*sysLib*",{\""*sysVer*"\"})")
          end
          if status==true
            println(" successful")
          else
            println(" failed")
          end
        end
      else
        error("sysLibs and sysVers string entries, separated by : are not equal")
      end
    end

    # Load Modelica work files
    workFilesList = split(workFiles,":")
    for workFile in workFilesList
      if workFile!=""
        print("  loadFile("*workDir*"/"*workFile*")")
        status = omc[:loadFile](workDir*"/"*workFile)
        if status==true
          println(" successful")
        else
          println(" failed")
        end
      end
    end

    # Load additional Modelica files
    filesList = split(files,":")
    for file in filesList
      if file!=""
        print("  loadFile("*file*")")
        status = omc[:loadFile](file)
        if status==true
          println(" successful")
        else
          println(" failed")
        end
      end
    end

    print("  instantiateModel("*model*")")
    status=omc[:sendExpression]("instantiateModel("*model*")")
    if status!=""
      println(" successful")
    else
      println(" failed")
    end

    # Assemble options
    simulateOpts=",tolerance="*string(Tolerance)
    if StartTime!=0
      simulateOpts=", startTime="*string(StartTime)
    end
    if StopTime>StartTime
      simulateOpts=", stopTime="*string(StopTime)
    end
    if NumberOfIntervals!=500
      simulateOpts=", numberOfIntervals="*string(NumberOfIntervals)
    end
    # Run simulaton
    print("  simulate("*model*simulateOpts*")")
    status = omc[:sendExpression]("simulate("*model*simulateOpts*")")
    if status!=""
      println(" successful")
    else
      println(" failed")
    end

    # Copy result file to result folder and overwrite possibly existing file
    resFile=workDir*"/"*model*resExt
    println("  copy result file from: "*simDir*"/"*model*resExt)
    println("                     to: "*resFile)
    cp(simDir*"/"*model*resExt,resFile,remove_destination=true)
    cd(localDir)

    # Load result file
    df = DyMat.DyMatFile(resFile)
    # Time cannot be accessed when using var = df[:names]
    return df
  end

  """
  # Function call

  `loadResultOM(resFile,resDir="/work")`

  # Description

  This function loads an OpenModelica result file by means of DyMat

  # Variables

  `resFile` OpenModelica results file including extension .mat

  `resDir` Directory where result file is stored; default value = "/work"
  """
  function loadResultOM(resFile,resDir="/work")
    println("  reading result file from: "*resDir*"/"*resFile)
    # Load result file
    df = DyMat.DyMatFile(resDir*"/"*resFile)
    # Time cannot be accessed when using var = df[:names]
    return df
  end

end
