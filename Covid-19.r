---
output:
  github_document: default
  html_document:
    df_print: paged
    keep_md: true
editor_options: 
  chunk_output_type: console
---
#############
# LIBRARIES #
#############
```{r setup, include=FALSE}
#General-purpose data wrangling
library(tidyverse)  

# Parsing of HTML/XML files  
library(rvest) 

# String manipulation
library(stringr)   

# Verbose regular expressions
library(rebus)     

#Eases DateTime manipulation
library(lubridate)

#install.packages("shiny")
library(shiny)

# Fetching country codes three letter form
library(countrycode)

# manipulating subsets of dataframe
library(plyr)

library(ggrepel)
library(rsconnect)
library(ggplot2)
library(dplyr)
library(plotly)
library(flexdashboard)
library(maps)
library(shinydashboard)
library(png)
library(sunburstR)
```

```{r}
####################
# DATA PREPARATION #
####################

# scraping data from wolrdmeters
url <- read_html("https://www.worldometers.info/coronavirus/")

# FIrST DATAFRAME
# dataframe of first table from url
df <- url %>% html_nodes("table") %>% .[[1]] %>% html_table()

# remove special characters from dataframe
df <- df %>% mutate_all(funs(gsub("[[:punct:]]", "", .)))

# return columns from 3 to 12 as integer
i <- c(3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
df[, i] <-
  apply(df[, i], 2, function(x)
    as.integer(as.character(x)))

names(df)[2] <- "Country"
names(df)[10:12] <- c("Serious", "TotCases_1M", "Deaths_1M")
# new column with country code
no <-
  c(
    "CAR",
    "Channel Islands",
    "Diamond Princess",
    "MS Zaandam",
    "Saint Martin",
    "St Barth",
    "Total"
  )
dfnoco <- filter(df,!df$Country %in% no)
df <- filter(df,!df$Country %in% no[no == 'Total'])
dfnoco$countryCode <-
  countrycode(dfnoco$Country, origin = 'country.name', destination = 'iso3c')

# converting NA values into O
df[is.na(df)] <- 0


# SECOND DATAFRAME
url2 <-
  read_html("https://www.worldometers.info/coronavirus/worldwide-graphs/#case-timeline")

df_url2 <- url2 %>% html_nodes("table") %>% .[[1]] %>% html_table()
df_url2 <- df_url2[nrow(df_url2):1, ]
names(df_url2)[2:4] <-
  c("Total deaths cumulative",
    "Daily deaths",
    "% increase in daily deaths")

# remove special characters from dataframe
df_url2 <- df_url2 %>% mutate_all(funs(gsub("[[:punct:]]", "", .)))
df_url2[, 2:4] <-
  apply(df_url2[, 2:4], 2, function(x)
    as.integer(as.character(x)))
format(df_url2, justify = "left")

df_url2$Date <- factor(df_url2$Date, levels = df_url2$Date)

# converting NA values into O
df_url2[is.na(df_url2)] <- 0

# THIRD DATAFRAME
url3 <-
  read_html("https://www.worldometers.info/world-population/population-by-country/") # Population
df_url3 <- url3 %>% html_nodes("table") %>% .[[1]] %>% html_table()
df_url3 <-
  df_url3 %>% mutate_all(funs(gsub('[^A-Z\\a-z\\0-9\\.\\-]', "", .))) # clean special signs except letters, numbers, . and -
df_url3 <- df_url3[-c(0, 1, 4, 5, 8, 9)] # drop colums by index number
names(df_url3)[1:6] <-
  c("Country",
    "Population",
    "Pop_density",
    "Land_area",
    "Median_age",
    "Urban_pop")

# return columns from 3 to 12 as integer
df_url3[, 2:6] <-
  apply(df_url3[, 2:6], 2, function(x)
    as.integer(as.character(x)))
df_url3[is.na(df_url3)] <- 0

join <-
  inner_join(df, df_url3, by = c("Country")) # merge df and df_url3 dataframes in one
join <- filter(join, join$Pop_density > 0)
rownames(join) <-
  join$Country #change the index name of df by specified column
lista <- list(join$Pop_density, join$Urban_pop)

# Function to plot regression with summary data
ggplotRegression <- function (fit) {
  require(ggplot2)
  ggplot(fit$model, aes_string(
    x = names(fit$model)[2],
    y = names(fit$model)[1],
    label = names(fit$model)[3]
  )) +
    geom_point() + labs(x = "Population density (km2)", y = "Cases per 1M") +
    stat_smooth(method = "lm") +
    labs(title = paste(
      "R2 =",
      signif(summary(fit)$r.squared, 2),
      " Slope =",
      signif(fit$coef[[2]], 2),
      " P =",
      signif(summary(fit)$coef[2, 4], 2)
    ))
}

##########################################################################
##########################################################################

Co <- as.list(df$TotalCases)
names(Co) <- df$Country

country_line_color <- list(color = toRGB("gray"), width = 1.2)
map_options <- list(
  showframe = FALSE,
  showcoastlines = FALSE,
  projection = list(type = 'Mercator')
)

y <- df$NewCases[df$NewCases > 0]
df2 <- filter(df, df$NewCases > 0)
x <-
  factor(df2$Country, levels = unique(df2$Country)[order(y, decreasing =
                                                           TRUE)])

# Define UI for application that draws a histogram
ui <- shinyUI (dashboardPage(
  dashboardHeader(title = "Covid-19"),
  dashboardSidebar(
    sidebarMenu(
      menuItem(
        "Dashboard",
        tabName = "MainTab",
        icon = icon("dashboard")
      ),
      menuSubItem(
        "New cases",
        tabName = "NewCases",
        icon = icon("bar-chart-o")
      ),
      menuSubItem(
        "Total Cases",
        tabName = "TotalCases",
        icon = icon("chart-line")
      ),
      menuSubItem("Total Deaths", tabName = "TotalDeaths", icon =
                    icon("skull")), 
      menuSubItem("SunBurst Graph", tabName = "SunBurst", icon = icon("sun")),
      menuSubItem("Daily deaths", tabName = "DailyDeaths", icon =
                    icon("skull")),
      menuSubItem(
        "Population density",
        tabName = "Dens",
        icon = icon("bar-chart-o")
      )
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "MainTab",
        
        titlePanel("PLEASE CHOOSE THE DASHBOARD FROM SIDEBAR MENU
                                       "),
        titlePanel(absolutePanel(
          top = 550,
          left = 240,
          h3("Credits: Bojan Makivic, MMSc")
        )),
        plotOutput(outputId = "png")
      ),
      tabItem(
        tabName = "NewCases",
        titlePanel(absolutePanel(
          top = 40,
          left = 500,
          h1("New cases of Covid-19 for the current day")
        )),
        absolutePanel(
          top = 120,
          left = 210,
          draggable = TRUE,
          mainPanel(plotlyOutput("plotDist"))
        )
      ),
      tabItem(
        tabName = "TotalCases",
        titlePanel(absolutePanel(
          top = 180, left = 640, h1("Total Cases of Covid-19")
        )),
        fluidPage(
          fluidRow(
            infoBox("Total cases world wide", df$TotalCases[df$Country == "World"]),
            icon = icon("chart-line")
          ),
          absolutePanel(top = 5,
                        infoBoxOutput("infoBox"))
        ),
        fluidRow(
          absolutePanel(
            top = 60,
            left = 1040,
            draggable = FALSE,
            selectInput("var", "Select country:", choices =
                          Co),
            gaugeOutput("table")
          )
        ),
        fluidRow(
          absolutePanel(
            top = 255,
            left = 150,
            draggable = FALSE,
            plotlyOutput("geo")
          )
        )
      ),
      tabItem(
        tabName = "TotalDeaths",
        titlePanel(h1("Total deaths of Covid-19", align = "center")),
        absolutePanel(
          top = 130,
          left = 210,
          draggable = FALSE,
          mainPanel(plotlyOutput("plotDist2"))
        )
      ),
      tabItem(
        tabName = "SunBurst",
        absolutePanel(
          top = 40,
          left = 1100,
          style = "color: red",
          titlePanel(
            h5(
              "Hover with the mouse coursor over the specific parameter, e.g. active cases,
                                                         and click on it in order to reveal an additional information."
            )
          )
        ),
        titlePanel(h1("SunBurst graph", align = "center")),
        absolutePanel(
          top = 110,
          left = 250,
          draggable = FALSE,
          selectInput("var1", "Select country:", choices =
                        df$Country)
        ),
        absolutePanel(
          top = 130,
          left = 180,
          draggable = FALSE,
          mainPanel(plotlyOutput("SunBurst"))
        )
      ),
      tabItem(
        tabName = "DailyDeaths",
        titlePanel(h1("Daily deaths by Covid-19", align = "center")),
        absolutePanel(
          top = 150,
          left = 210,
          draggable = FALSE,
          mainPanel(plotlyOutput("plotDD"))
        )
      ),
      tabItem(
        tabName = "Dens",
        titlePanel(h1(
          "Population density and Covid-19 cases", align = "center"
        )),
        absolutePanel(
          top = 130,
          left = 250,
          draggable = FALSE,
          numericInput(
            "num",
            "x-axis cut off:",
            max(join$Pop_density),
            min = 1,
            max =  max(join$Pop_density)
          )
        ),
        absolutePanel(
          top = 130,
          left = 550,
          draggable = FALSE,
          numericInput(
            "num2",
            "y-axis cut off:",
            max(join$TotCases_1M),
            min = 1,
            max =  max(join$TotCases_1M)
          )
        ),
        absolutePanel(
          top = 130,
          left = 850,
          draggable = FALSE,
          selectInput("con", "Select continent:", choices =
                        join$Continent)
        ),
        #absolutePanel(top = 130, left = 1050,draggable = FALSE,
        # selectInput("paraM","Select parameter:",choices="Pop_density")),
        absolutePanel(
          top = 190,
          left = 220,
          width = 1700,
          height = 500,
          draggable = FALSE,
          mainPanel(plotlyOutput("plotDens"))
        )
      )
      
    )
  )
))

server <- function(input, output) {
  output$png <- renderPlot({
    pic = readPNG('Coronavirus.png')
    plot.new()
    grid::grid.raster(pic)
    
  })
  output$plotDist <- renderPlotly({
    plot_ly(
      y =  ~ y,
      x =  ~ x,
      height = 560,
      width = 1140,
      text = y,
      textposition = 'outside'
    ) %>%
      layout(
        title = "",
        xaxis = list(title = "Country"),
        yaxis = list(title = "New Cases")
      )
  })
  output$plotDist2 <- renderPlotly({
    plot_ly(
      df,
      x = ~ Country,
      y = ~ TotalDeaths,
      type = 'scatter',
      mode = "markers",
      width = 1130,
      height = 550,
      text = ~ paste("Deaths: ", TotalDeaths),
      color = ~ TotalDeaths,
      size = ~ TotalDeaths
    ) %>%
      layout(xaxis = list(title = "Country"),
             yaxis = list(title = "Total death"))
  })
  
  output$geo <-
    renderPlotly({
      fig <- plot_geo(dfnoco, height = 430, width = 1200)
      fig <- fig %>% add_trace(
        z = ~ dfnoco$TotalCases,
        color = ~ dfnoco$TotalCases,
        colors = 'Blues',
        text = ~ dfnoco$countryCode,
        locations = ~ dfnoco$countryCode,
        marker = list(line = country_line_color)
      )
      fig <- fig %>% colorbar(title = 'Total cases', tickprefix = '')
      fig <- fig %>% layout(title = 'World map',
                            geo = map_options)
    })
  
  output$table <- renderGauge({
    gauge(
      input$var,
      min = 0,
      max = max(df$TotalCases[df$Country != "Total"]),
      label = "Total cases",
      gaugeSectors(
        success = c(0, 50000),
        warning = c(50001, 100000),
        danger = c(10001, 500000)
      )
    )
  })
  
  output$SunBurst <- renderPlotly({
    plot_ly(
      width = 1170,
      height = 550,
      labels = c(
        "Total Cases",
        "Total Recoverd",
        "Total Deaths",
        "New Cases",
        "New Deaths",
        "Active Cases",
        "Serious Critical",
        "Total Cases per 1M",
        "Total Deaths per 1M"
      ),
      parents = c(
        "",
        "Total Cases",
        "Total Cases",
        "Total Cases",
        "New Cases",
        "Total Cases",
        "Active Cases",
        "Total Cases",
        "Total Cases per 1M"
      ),
      values = c(
        sum(df$TotalCases[df$Country == input$var1]),
        sum(df$TotalRecovered[df$Country == input$var1]),
        sum(df$TotalDeaths[df$Country == input$var1]),
        sum(df$NewCases[df$Country == input$var1]),
        sum(df$NewDeaths[df$Country == input$var1]),
        sum(df$ActiveCases[df$Country == input$var1]),
        sum(df$Serious[df$Country == input$var1]),
        sum(df$TotCases_1M[df$Country == input$var1]),
        sum(df$Deaths_1M[df$Country == input$var1])
      ),
      type = 'sunburst',
      
      branchvalues = 'remainder'
    )
  })
  output$plotDD <- renderPlotly({
    plot_ly(
      x = df_url2$Date,
      y = df_url2$`Total deaths cumulative`,
      width = 1200,
      height = 550,
      type = 'scatter',
      mode = 'lines',
      color = 'dark green',
      name = 'Total deaths cumulative'
    ) %>%
      add_trace(
        x = df_url2$Date,
        y = df_url2$`Daily deaths`,
        type = 'scatter',
        mode = 'lines',
        color = 'red',
        name = 'Daily deaths'
      ) %>%
      layout(
        title = 'Daily deaths',
        xaxis = list(title = 'Date'),
        yaxis = list(title = 'Count')
      )
  })
  
  output$plotDens <- renderPlotly({
    {
      ggplotRegression(lm(
        TotCases_1M ~ Pop_density - Country,
        data = subset(join, Continent == input$con | input$con == "") %>%
          filter(Pop_density < input$num &
                   TotCases_1M < input$num2)
      ))
    }
  })
}

# Run the application
shinyApp(ui = ui, server = server)
```