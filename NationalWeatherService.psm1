


function Get-NWSZone {
  param(
    $County,
    [ValidatePattern('^(A[KLMNRSZ]|C[AOT]|D[CE]|F[LM]|G[AMU]|I[ADLN]|K[SY]|L[ACEHMOS]|M[ADEHINOPST]|N[CDEHJMVY]|O[HKR]|P[AHKMRSWZ]|S[CDL]|T[NX]|UT|V[AIT]|W[AIVY]|[HR]I)')]$State)
  
  $zone=((Invoke-RestMethod "https://api.weather.gov/zones?type=public").features | Where-Object {$_.properties.name -eq $County}).properties
  if($zone.count -gt 1)
  {
    if($State)
    {
      $zone=foreach($zone in $zones)
      {
        if($zone.state -eq $State)
        {
          return $zone
        }
      }
    
    }
    else
    {
      $State=Read-Host "Multiple zones found for $County, Please specify a state from the following list: $($zone.state -join ", "): "
      if($State -notin $zone.state)
      {
        Write-Error "Invalid State Specified"
        return
      }
    }
  }

  if($zone.count -eq 0)
  {
    Write-Error "No zones found for $County"
    return
  }
  Write-Verbose $zone
  return $zone
}

function Get-NWSForecast {
  [alias("Get-Forecast")]
  param($County)

  if($county)
  {
    $zone=(Get-NWSZone -County $County)
    if($null -eq $zoneid)
    {
      Write-Warning "$County not found, please use Get-NWSCounty to find a valid county name"
      return
    }
  }
  else 
  {
    #TODO: allow location alias'  i.e. Get-NWSForecast Home, Get-NWSForecast Work, Get-NWSForecast NYC vs Get-nwsforecast "New York (Manhattan)"
    #TODO: Allow for mutiple default zones, which will return forecasts for all default zones.
    $zone=(Get-NWSConfig)
  }
  $forecast=(Invoke-RestMethod -uri "https://api.weather.gov/zones/public/$($zone.id)/forecast").properties.periods

  Write-Host "Forecast for $($zone.name) County, $($zone.state)"
  
  return $forecast

}


function Get-NWSObservations {
  param($County)
  $zone=Get-NWSZone -County $County

  $observations=(Invoke-RestMethod -uri "https://api.weather.gov/zones/forecast/$($zone.properties.id)/observations").properties

  foreach($period in $observations)
  {

  }

  return $observations
}

function Get-NWSCounty
{
  [cmdletbinding()]
  [OutputType('NWS.County')]
  
  param(
    $County,  
    [ValidatePattern('^(A[KLMNRSZ]|C[AOT]|D[CE]|F[LM]|G[AMU]|I[ADLN]|K[SY]|L[ACEHMOS]|M[ADEHINOPST]|N[CDEHJMVY]|O[HKR]|P[AHKMRSWZ]|S[CDL]|T[NX]|UT|V[AIT]|W[AIVY]|[HR]I)')]$State
    
  )
  
  $counties=(Invoke-RestMethod "https://api.weather.gov/zones?type=public").features.properties
  
  if($State)
  {
    $counties = foreach($countyget in $counties)
      {
        if($countyget.state -eq $State)
        {
          $countyget
        }
      }
  }
  if($County)
  {
    $counties = foreach($countyget in $counties)
      {
        if($countyget.name -like $County)
        {
          $countyget
        }
      }
  }

  foreach($countyget in $counties)
  {
    $countyget.psobject.TypeNames.Insert(0,'NWS.County')
  }
  return $counties

}

function Get-NWSConfig
{
  try
  {
    $config=(Get-Content -Path "$((Get-module -Name NationalWeatherService -ListAvailable).ModuleBase)\config.json" -ErrorAction Stop) | ConvertFrom-Json -ErrorAction Stop
    return $config
  }
  catch
  {
    $setDefaults=Read-Host "You do not have any defaults set, Would you like do that now? (Y/N): "
  }
  if($setDefaults -eq 'Y')
  {
    $searchCounty=Read-host "Which county would you like to be default? "
    $searchState= read-host "Which state (two letter abbreviation) is $searchCounty in? "

    $county=Get-NWSCounty -County $searchCounty -State $searchState
    
    $config=@{
      default=$true
      id=$county.id
      county=$county.name
      state=$county.state
    }

    $config | ConvertTo-Json | Set-Content -Path $PSScriptRoot\config.json
    return $config
  }
  else
  {
    return
  }
  else {
    $optout=Read-Host "Would you like me to stop asking you to set defaults? (Y/N): "
    if($optout -eq 'Y')
    {
      $config=@{}
      $config.optout=$true
      $config | ConvertTo-Json | Set-Content -Path $PSScriptRoot\config.json
      return
    }
    else
    {
      return
    }
  }

}


function Reset-NWSConfig
{
   if(Test-Path $PSScriptRoot\config.json)
   {
      Write-Host "Removing config file" 
      Remove-Item $PSScriptRoot\config.json
   }
}

# New-Alias -Name Get-NWSForecast -Value Get-Forecast