# plumber.R
library(plumber)
library(openxlsx)
library(ROI)
library(ROI.plugin.cbc)
library(ompr)
library(ompr.roi)
library(dplyr)
library(readxl)

# Security parameters (same as in your Shiny app)
unlock_date <- "2026-04-25"
correct_password <- "1020304050"

#* @apiTitle Production Scheduling Optimizer API
#* @apiDescription API version of the production scheduling optimization tool

#* Health check
#* @get /health
function() {
  return(list(status = "OK", time = Sys.time()))
}

#* Login endpoint
#* @param password The access password
#* @post /login
  function(password){
    if (Sys.Date() > as.Date(unlock_date)) {
      if (password == correct_password) {
        return(list(status = "success", message = "Login successful"))
      } else {
        return(list(status = "error", message = "Incorrect password"))
      }
    }
    return(list(status = "success", message = "Before unlock date - no password needed"))
  }
  
  #* Optimize production schedule
  #* @param file_path Path to Excel file
  #* @param time_limit Time limit in seconds
  #* @param num_cores Number of cores to use
  #* @param optimality_gap Optimality gap percentage
  #* @post /optimize
  function(file_path, time_limit = 600, num_cores = 2, optimality_gap = 5) {
    # Check if we need authentication
    if (Sys.Date() > as.Date(unlock_date)) {
      return(list(status = "error", message = "Authentication required"))
    }
    
    tryCatch({
      # Read input file
      input_data <- list(
        df_machines = read_excel(file_path, sheet = "Machines"),
        df_jobs = read_excel(file_path, sheet = "Jobs"),
        df_processing_time = read_excel(file_path, sheet = "ProcessingTimes"),
        df_setup_time = read_excel(file_path, sheet = "SetupTimes"),
        df_deadlines = read_excel(file_path, sheet = "Deadlines")
      )
      
      # Extract data
      df_machines <- input_data$df_machines
      df_jobs <- input_data$df_jobs
      df_processing_time <- input_data$df_processing_time
      df_setup_time <- input_data$df_setup_time
      df_deadlines <- input_data$df_deadlines
      
      machines <- df_machines$Machines
      jobs <- df_jobs$Jobs
      
      # Create named lists
      processing_time <- setNames(df_processing_time[[3]],
                                  paste(df_processing_time[[1]], df_processing_time[[2]]))
      
      setup_time <- setNames(df_setup_time[[4]],
                             paste(df_setup_time[[1]], df_setup_time[[2]], df_setup_time[[3]]))
      
      deadlines <- setNames(df_deadlines[[2]], df_deadlines[[1]])
      
      n_jobs <- length(jobs)
      n_machines <- length(machines)
      job_index <- seq_len(n_jobs)
      machine_index <- seq_len(n_machines)
      
      # Define the model
      model <- MIPModel() %>%
        # Decision variables
        add_variable(x[j, m], j = job_index, m = machine_index, type = "binary") %>%
        add_variable(y[i, j, m], i = job_index, j = job_index, m = machine_index, type = "binary") %>%
        add_variable(s[j], j = job_index, type = "continuous", lb = 0) %>%
        add_variable(C_max, type = "continuous", lb = 0) %>%
        
        # Objective: minimize makespan
        set_objective(C_max, "min") %>%
        
        # Constraint 1: Each job to exactly one machine
        add_constraint(sum_expr(x[j, m], m = machine_index) == 1, j = job_index)
      
      # Add disjunctive constraints with setup times
      for (m in machine_index) {
        for (i in job_index) {
          for (j in job_index) {
            if (i != j) {
              model <- model %>%
                # Sequencing with setup times
                add_constraint(
                  s[j] >= s[i] + 
                    processing_time[paste(jobs[i], machines[m])] + 
                    ifelse(is.null(setup_time[[paste(jobs[i], jobs[j], machines[m])]]),
                           0,
                           setup_time[[paste(jobs[i], jobs[j], machines[m])]]) -
                    1e5 * (1 - y[i, j, m])
                ) %>%
                # Prevent cycles
                add_constraint(y[i, j, m] + y[j, i, m] >= x[i, m] + x[j, m] - 1)
            }
          }
        }
      }
      
      # Makespan and deadline constraints
      for (j in job_index) {
        for (m in machine_index) {
          model <- model %>%
            add_constraint(
              C_max >= s[j] + processing_time[paste(jobs[j], machines[m])] - 
                1e5 * (1 - x[j, m])
            ) %>%
            add_constraint(
              s[j] + processing_time[paste(jobs[j], machines[m])] <= 
                deadlines[[jobs[j]]] + 1e5 * (1 - x[j, m])
            )
        }
      }
      
      # Solve the model
      model_result <- solve_model(
        model,
        with_ROI(
          solver = "cbc",
          control = list(
            threads = num_cores,
            seconds = time_limit,
            logLevel = 1,
            ratioGap = optimality_gap/100,
            cuts = "on",
            presolve = "on",
            heuristics = "on"
          )
        )
      )
      
      # Process results
      if (!is.null(model_result$solution)) {
        schedule <- lapply(job_index, function(j) {
          assigned_m <- which(sapply(machine_index, function(m) 
            model_result$solution[paste0("x[", j, ",", m, "]")] > 0.99))
          if (length(assigned_m) == 0) return(NULL)
          
          data.frame(
            Machine = machines[assigned_m],
            Job = jobs[j],
            Start = model_result$solution[paste0("s[", j, "]")],
            End = model_result$solution[paste0("s[", j, "]")] + 
              processing_time[paste(jobs[j], machines[assigned_m])],
            Deadline = deadlines[[jobs[j]]],
            Status = ifelse(model_result$solution[paste0("s[", j, "]")] + 
                              processing_time[paste(jobs[j], machines[assigned_m])] > 
                              deadlines[[jobs[j]]], "Late", "On Time")
          )
        })
        
        schedule_df <- dplyr::bind_rows(schedule)
        
        # Create Excel output in temp file
        temp_file <- tempfile(fileext = ".xlsx")
        wb <- createWorkbook()
        addWorksheet(wb, "Schedule")
        writeData(wb, "Schedule", schedule_df)
        saveWorkbook(wb, temp_file, overwrite = TRUE)
        
        # Return results
        return(list(
          status = "success",
          solver_status = model_result$status,
          makespan = model_result$objective_value,
          schedule = schedule_df,
          excel_file = base64enc::base64encode(temp_file),
          file_name = paste0("schedule_", Sys.Date(), ".xlsx")
        ))
      } else {
        return(list(status = "error", message = "No solution found"))
      }
    }, error = function(e) {
      return(list(status = "error", message = paste("Error:", e$message)))
    })
  }
