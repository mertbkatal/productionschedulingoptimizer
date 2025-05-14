library(shiny)
library(shinyjs)
library(httr)
library(jsonlite)
library(DT)
library(ggplot2)

ui <- fluidPage(
  useShinyjs(),
  titlePanel("Production Scheduling Optimizer (API Version)"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Choose Excel File", accept = c(".xlsx")),
      numericInput("time_limit", "Time Limit (seconds)", value = 600, min = 1),
      numericInput("num_cores", "Number of Cores", value = 2, min = 1),
      numericInput("optimality_gap", "Optimality Gap (%)", value = 5, min = 0, max = 100),
      actionButton("optimize", "Start Optimization", class = "btn-lg"),
      hr(),
      verbatimTextOutput("console_output"),
      uiOutput("download_ui")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Schedule", DTOutput("schedule_table")),
        tabPanel("Gantt Chart", plotOutput("gantt_plot")),
        tabPanel("Optimization Info", verbatimTextOutput("optimization_info"))
      )
    )
  )
)

server <- function(input, output, session) {
  # Set your API URL (will be provided by Railway after deployment)
  api_url <- "https://your-railway-url.up.railway.app"
  
  # Reactive values
  rv <- reactiveValues(
    schedule = NULL,
    result = NULL,
    console_text = ""
  )
  
  # Optimization process
  observeEvent(input$optimize, {
    req(input$file)
    
    # Upload file to temporary location
    temp_file <- input$file$datapath
    
    # Call the API
    tryCatch({
      response <- POST(
        paste0(api_url, "/optimize"),
        body = list(
          file_path = upload_file(temp_file),
          time_limit = input$time_limit,
          num_cores = input$num_cores,
          optimality_gap = input$optimality_gap
        )
      )
      
      content <- fromJSON(content(response, "text"))
      
      if (content$status == "success") {
        rv$result <- content
        rv$schedule <- content$schedule
        showNotification("Optimization completed!", type = "message")
      } else {
        showNotification(content$message, type = "error")
      }
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })
  
  # Outputs
  output$schedule_table <- renderDT({
    req(rv$schedule)
    datatable(rv$schedule, options = list(scrollX = TRUE))
  })
  
  output$gantt_plot <- renderPlot({
    req(rv$schedule)
    
    ggplot(rv$schedule, aes(x = Start, xend = End,
                            y = Machine, yend = Machine,
                            color = Job)) +
      geom_segment(size = 8) +
      geom_vline(aes(xintercept = Deadline), linetype = "dashed", color = "red") +
      labs(title = "Schedule Gantt Chart",
           x = "Time", y = "Machine") +
      theme_minimal() +
      geom_text(aes(x = Start + (End-Start)/2, y = Machine, 
                    label = Job), color = "white", size = 3)
  })
  
  output$optimization_info <- renderPrint({
    req(rv$result)
    cat("Solver Status:", rv$result$solver_status, "\n")
    cat("Makespan:", rv$result$makespan, "\n")
  })
  
  output$download_ui <- renderUI({
    req(rv$result)
    downloadButton("download_excel", "Download Schedule")
  })
  
  output$download_excel <- downloadHandler(
    filename = function() {
      rv$result$file_name
    },
    content = function(file) {
      writeBin(base64enc::base64decode(rv$result$excel_file), file)
    }
  )
}

shinyApp(ui, server)