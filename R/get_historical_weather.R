
#' Obtain historical BOM data
#'
#' Retrieves daily observations for a given station.
#'
#' @note Methods \code{get_historical_weather} and \code{get_historical} are
#' equivalent. No preference is given to the use of either.
#'
#' @param stationid \acronym{BOM} station \sQuote{ID}. See Details.
#' @param latlon Length-2 numeric vector of Latitude/Longitude. See Details.
#' @param radius Numeric value, distance (km) from \var{latlon}, must be
#'   numeric.
#' @param type Measurement type for \code{daily}, either daily \dQuote{rain},
#'   \dQuote{min} (temp), \dQuote{max} (temp), or \dQuote{solar} (exposure).
#'   Partial matching is performed. If not specified returns the first
#'   matching type in the order listed. Ignored if \code{hourly} or
#'   \code{minute} are selected for \code{tscale}.
#' @return A \code{bomrang_tbl} object (extension of a
#'   \code{\link[base]{data.frame}}) of historical observations for the selected
#'   station/product type, with some subset of the following columns:
#'
#'   \tabular{rl}{
#'   **product_code**:\tab BOM internal code.\cr
#'   **station_number**:\tab BOM station ID.\cr
#'   **year**:\tab Year of observation (YYYY).\cr
#'   **month**:\tab Month of observation (1-12).\cr
#'   **day**:\tab Day of observation (1-31).\cr
#'   **min_temperature**:\tab Minimum daily recorded temperature (degrees C).\cr
#'   **max_temperature**:\tab Maximum daily recorded temperature (degrees C).\cr
#'   **accum_days_min**:\tab Accumulated number of days of minimum
#'    temperature.\cr
#'   **accum_days_max**:\tab Accumulated number of days of maximum
#'   temperature.\cr
#'   **rainfall**:\tab Daily recorded rainfall in mm.\cr
#'   **period**:\tab Period over which rainfall was measured.\cr
#'   **solar_exposure**:\tab Daily global solar exposure in MJ/m^2.\cr
#'   **quality**:\tab Y, N, or missing. Data which have not yet completed the\cr
#'               \tab routine quality control process are marked accordingly.
#'   }
#'
#'   The following attributes are set on the data, and these are used to
#'   generate the header:
#'
#'   \tabular{rl}{
#'   **site**:\tab BOM station ID.\cr
#'   **name**:\tab BOM station name.\cr
#'   **lat**:\tab Latitude in decimal degrees.\cr
#'   **lon**:\tab Longitude in decimal degrees.\cr
#'   **start**:\tab Date observations start.\cr
#'   **end**:\tab Date observations end.\cr
#'   **years**:\tab Available number of years data.\cr
#'   **percent**:\tab Percent complete.\cr
#'   **AWS**:\tab Automated weather station?\cr
#'   **type**:\tab Measurement types available for the station.\cr
#'   }
#'
#' @section Caution:
#'   Temperature data prior to 1910 should be used with extreme caution as many
#'   stations prior to that date were exposed in non-standard shelters. Some
#'   of which give readings which are several degrees warmer or cooler than
#'   those measured according to post-1910 standards.
#'
#'   Daily maximum temperatures usually occur in the afternoon and daily minimum
#'   temperatures overnight or near dawn. Occasionally, however, the lowest
#'   temperature in the 24 hours to prior to 9 AM can occur around 9 AM the
#'   previous day if the night was particularly warm.
#'
#'   Either \code{stationid} or \code{latlon} must be provided, but if both are,
#'   then \code{stationid} will be used as it is more reliable.
#'
#'   In some cases data is available back to the 1800s, so tens-of-thousands of
#'   daily records will be returned. Other stations will be newer and will
#'   return fewer observations.
#'
#' @section \CRANpkg{dplyr} Compatibility: The \code{bomrang_tbl} class is
#'   compatible with \code{\link[dplyr:dplyr-package]{dplyr}} as long as the
#'   \code{bomrang} package is on the search path. Common functions
#'   (\code{\link[dplyr]{filter}}, \code{\link[dplyr]{select}},
#'   \code{\link[dplyr]{arrange}}, \code{\link[dplyr]{mutate}},
#'   \code{\link[dplyr:select]{rename}}, \code{\link[dplyr]{arrange}},
#'   \code{\link[dplyr]{slice}}, \code{\link[dplyr]{group_by}}) are provided
#'   which mask the \CRANpkg{dplyr} versions (but use those internally,
#'   maintaining attributes).
#'
#' @seealso \link{get_current_weather}
#'
#' @author Jonathan Carroll, \email{rpkg@@jcarroll.com.au}
#'
#' @examples
#' \donttest{
#' get_historical_weather(stationid = "023000",
#'                       type = "max") ## ~48,000+ daily records
#' get_historical_weather(latlon = c(-35.2809, 149.1300),
#'                        type = "min") ## 3,500+ daily records
#' }
#' @rdname get_historical_weather
#' @export get_historical_weather

get_historical_weather <- get_historical <-
  function(stationid = NULL,
           latlon = NULL,
           radius = NULL,
           type = c("rain", "min", "max", "solar")) {
    site <- ncc_obs_code <- NULL #nocov
    
    if (is.null(stationid) & is.null(latlon))
      stop("\nstationid or latlon must be provided\n.",
           call. = FALSE)
    if (!is.null(stationid) & !is.null(latlon)) {
      warning("\nOnly one of `stationid` or `latlon` may be provided. ",
              "\nUsing `stationid`\n.")
    }
    if (is.null(stationid)) {
      if (!identical(length(latlon), 2L) || !is.numeric(latlon))
        stop("\n`latlon` must be a 2-element numeric vector.",
             call. = FALSE)
      stationdetails <-
        sweep_for_stations(latlon = latlon)[1, , drop = TRUE]
      message("\nClosest station: ",
              stationdetails$site,
              " (",
              stationdetails$name,
              ")\n")
      stationid <- stationdetails$site
    }
    
    ## ensure station is known
    ncc_list <- .get_ncc()
    
    if (suppressWarnings(all(
      is.na(as.numeric(stationid)) |
      as.numeric(stationid) %notin% ncc_list$site
    )))
      stop("\nStation not recognised.",
           call. = FALSE)
    
    type <- match.arg(type)
    obscode <- switch(
      type,
      rain = 136,
      min = 123,
      max = 122,
      solar = 193
    )
    
    ncc_list <-
      dplyr::filter(ncc_list, c(site == as.numeric(stationid) &
                                  ncc_obs_code == obscode))
    
    if (obscode %notin% ncc_list$ncc_obs_code)
      stop(call. = FALSE,
           "\n`type` ",
           type,
           " is not available for `stationid` ",
           stationid,
           "\n")
    
    zipurl <- .get_zip_url(stationid, obscode)
    dat <- .get_zip_and_load(zipurl)
    
    names(dat) <- c("product_code",
                    "station_number",
                    "year",
                    "month",
                    "day",
                    switch(
                      type,
                      min = c("min_temperature",
                              "accum_days_min",
                              "quality"),
                      max = c("max_temperature",
                              "accum_days_max",
                              "quality"),
                      rain = c("rainfall",
                               "period",
                               "quality"),
                      solar = c("solar_exposure")
                    ))
    dat[["station_number"]] <- sprintf("%06d",
                                       as.integer(dat[["station_number"]]))
    
    return(
      structure(
        dat,
        class = union("bomrang_tbl", class(dat)),
        station = stationid,
        type = type,
        origin = "historical",
        location = ncc_list$name,
        lat = ncc_list$lat,
        lon = ncc_list$lon,
        start = ncc_list$start,
        end = ncc_list$end,
        count = ncc_list$years,
        units = "years",
        ncc_list = ncc_list
      )
    )
  }

# export `get_historical()` ----
#' @rdname get_historical_weather
#' @examples
#' \donttest{
#' get_historical(stationid = "023000",
#'               type = "max") ## ~48,000+ daily records
#' get_historical(latlon = c(-35.2809, 149.1300),
#'                type = "min") ## 3,500+ daily records
#' }
#' @export
get_historical <- get_historical_weather

#' Get latest historical station metadata
#'
#' Fetches BOM metadata for checking historical record availability. Also can be
#' used to return the metadata if user desires.
#'
#' @md
#'
#' @return A data frame of metadata for BOM historical records
#' @keywords internal
#' @author Jonathan Carroll, \email{rpkg@@jcarroll.com.au} and James Goldie
#'  \email{me@@rensa.co}.
#' @noRd

.get_ncc <- function() {
  
  # set a custom user-agent, restore original settings on exit
  # required for #130 - BOM returns 403 for RStudio
  op <- options()
  on.exit(options(op))
  options(HTTPUserAgent = paste0("{bomrang} R package (",
                                 utils::packageVersion("bomrang"),
                                 ") https://github.com/ropensci/bomrang"))
  
  # CRAN NOTE avoidance
  site <- name <- lat <- lon <- start_month <- #nocov start
    start_year <-
    end_month <- end_year <- years <- percent <- AWS <-
    start <- end <- ncc_obs_code <- site <- NULL #nocov end
  
  base_url <- "http://www.bom.gov.au/climate/data/lists_by_element/"
  
  rain <- paste0(base_url, "alphaAUS_136.txt")
  tmax <- paste0(base_url, "alphaAUS_122.txt")
  tmin <- paste0(base_url, "alphaAUS_123.txt")
  solar <- paste0(base_url, "alphaAUS_193.txt")
  
  weather <- c(rain, tmax, tmin, solar)
  names(weather) <- c("rain", "tmax", "tmin", "solar")
  
  ncc_codes <- vector(mode = "list", length = length(weather))
  names(ncc_codes) <- names(weather)
  
  for (i in seq_along(weather)) {
    ncc_obs_code <- substr(weather[i],
                           nchar(weather[i]) - 6,
                           nchar(weather[i]) - 4)
    
    # read the station list in as a vector first so that we can
    # detect and remove the header and footer...
    ncc <- readLines(weather[i])
    header_start <- grep("^\\-+$", ncc) + 1L
    footer_start <- grep("^[0-9]+ stations", ncc) - 1L
    
    if (length(header_start > 0) && length(footer_start > 0)) {
      # ... then process it as a data frame
      ncc <-
        readr::read_table(
          ncc[header_start:footer_start],
          skip = 0,
          col_names = c(
            "site",
            "name",
            "lat",
            "lon",
            "start_month",
            "start_year",
            "end_month",
            "end_year",
            "years",
            "percent",
            "AWS"
          ),
          col_types = c(
            site = readr::col_integer(),
            name = readr::col_character(),
            lat = readr::col_double(),
            lon = readr::col_double(),
            start_month = readr::col_character(),
            start_year = readr::col_character(),
            end_month = readr::col_character(),
            end_year = readr::col_character(),
            years = readr::col_double(),
            percent = readr::col_integer(),
            AWS = readr::col_character()
          ),
          na = ""
        )
      
      # unite month and year, convert to a date and add ncc_obs_code
      ncc <-
        ncc %>%
        tidyr::unite(start, start_month, start_year, sep = "-") %>%
        tidyr::unite(end, end_month, end_year, sep = "-") %>%
        dplyr::mutate(start = lubridate::dmy(paste0("01-", start))) %>%
        dplyr::mutate(end = lubridate::dmy(paste0("01-", end))) %>%
        dplyr::mutate(ncc_obs_code = ncc_obs_code)
      
      # finally, store in a list
      ncc_codes[[i]] <- ncc
      
    } else {
      warning(
        call. = FALSE,
        "The list of available stations for `type = ",
        names(weather)[i],
        "` is currently empty.\n",
        "This is likely a temporary error in the Bureau of Meteorology\'s\n",
        "database and may cause requests for ",
        names(weather)[i],
        " station data to fail."
      )
    }
  }
  dplyr::bind_rows(ncc_codes)
}

#' Identify URL of historical observations resources
#'
#' BOM data is available via URL endpoints but the arguments are not (well)
#' documented. This function first obtains an auxilliary data file for the given
#' station/measurement type which contains the remaining value `p_c`. It then
#' constructs the approriate resource URL.
#'
#' @md
#' @param site site ID.
#' @param code measurement type. See internals of [get_historical_weather].
#' @importFrom httr GET content
#'
#' @return URL of the historical observation resource
#' @keywords internal
#' @author Jonathan Carroll, \email{rpkg@@jcarroll.com.au}
#' @noRd

.get_zip_url <- function(site, code = 122) {
  base_url <- "http://www.bom.gov.au/jsp/ncc/cdio/weatherData/"
  url1 <-
    paste0(
      base_url,
      "av?p_stn_num=",
      site,
      "&p_display_type=availableYears&p_nccObsCode=",
      code
    )
  raw <- httr::content(httr::GET(url1), "text")
  if (grepl("Error code: 1001", raw))
    stop("Error in retrieving resource identifiers.")
  pc <- sub("^.*:", "", raw)
  url2 <-
    paste0(
      base_url,
      "av?p_display_type=dailyZippedDataFile&p_stn_num=",
      site,
      "&p_c=",
      pc,
      "&p_nccObsCode=",
      code
    )
  url2
}

#' Download a BOM Data .zip file and load into session
#'
#' @param url URL of zip file to be downloaded/extracted/loaded.
#'
#' @return data loaded from the zip file
#' @keywords internal
#' @author Jonathan Carroll, \email{rpkg@@jcarroll.com.au}
#' @noRd
.get_zip_and_load <- function(url) {
  
  USERAGENT <- paste0("{bomrang} R package (",
                      utils::packageVersion("bomrang"),
                      ") https://github.com/ropensci/bomrang")
  # set a custom user-agent, restore original settings on exit
  # required for #130 - BOM returns 403 for RStudio
  op <- options()
  on.exit(options(op))
  options(HTTPUserAgent = USERAGENT)
  
  # BOM's FTP server can timeout too quickly
  # Also, BOM's http server sometimes sends a http response of 200, "all good",
  # but then will not actually serve the requested file, so we want to set a max
  # time limit for the complete process to complete as well.
  h <- curl::new_handle()
  curl::handle_setopt(
    handle = h,
    FTP_RESPONSE_TIMEOUT = 60L,
    CONNECTTIMEOUT = 60L,
    TIMEOUT = 120L,
    USERAGENT = USERAGENT
  )
  
  tmp <- tempfile(fileext = ".zip")
  curl::curl_download(url, tmp, mode = "wb", quiet = TRUE, handle = h)
  zipped <- utils::unzip(tmp, exdir = dirname(tmp))
  unlink(tmp)
  datfile <- grep("Data.csv", zipped, value = TRUE)
  message("Data saved as ", datfile)
  dat <-
    utils::read.csv(datfile, header = TRUE, stringsAsFactors = TRUE)
  dat
}
