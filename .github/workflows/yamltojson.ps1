

function ConvertSentinelRuleFrom-Yaml {
  
    param (
       
         $Path ='./Simbaz22/Azure-Sentinel', 
      
        [Parameter(Mandatory = $false)]
        $OutputFolder
    )

    if (Get-Module -ListAvailable -Name powershell-yaml) {
        Write-Verbose "Module already installed"
    }
    else {
        Write-Host "Installing PowerShell-YAML module"
        try {
            Install-Module powershell-yaml -AllowClobber -Force -ErrorAction Stop
            Import-Module powershell-yaml
        }
        catch {
            Write-Error $_.Exception.Message
            break
        }
    }

    <#
        If OutPut folder defined then test if exists otherwise create folder
    #>
    if ($OutputFolder) {
        if (Test-Path $OutputFolder) {
            $expPath = (Get-Item $OutputFolder).FullName
        }
        else {
            try {
                $script:expPath = (New-Item -Path $OutputFolder -ItemType Directory -Force).FullName
            }
            catch {
                Write-Error $_.Exception.Message
                break
            }
        }
    }

    <#
        Test if path exists and extract the data from folder or file
    #>
    if ($Path.Extension -in '.yaml', '.yml') {
        Write-Verbose "Singel YAML file selected"
        try {
            $content = Get-Item -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
    elseif ($Path.Extension -in '') {
        Write-Verbose "Folder defined"
        try {
            $content = Get-ChildItem -Path $Path -Filter *.yaml -Recurse -ErrorAction Stop
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
    else {
        Write-Error 'Wrong Path please see example'
    }

    <#
        If any YAML file found starte lopp to process all the files
    #>
    if ($content) {
        Write-Verbose "'$($content.count)' templates found to convert"

        # Start Loop
        $content | ForEach-Object {
            <#
                Define JSON template format
            #>
            $template = [PSCustomObject]@{
                '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                contentVersion = "1.0.0.0"
                Parameters     = @{
                    Workspace = @{
                        type = "string"
                    }
                }
                resources      = @(
                    [PSCustomObject]@{
                        id         = ""
                        name       = ""
                        type       = "Microsoft.OperationalInsights/workspaces/providers/alertRules"
                        kind       = "Scheduled"
                        apiVersion = "2021-03-01-preview"
                        properties = [PSCustomObject]@{}
                    }
                )
            }

            # Update the template format with the data from YAML file
            $convert = $_ | Get-Content -Raw | ConvertFrom-Yaml -ErrorAction Stop | Select-Object * -ExcludeProperty relevantTechniques, kind, requiredDataConnectors, version, tags
            $($template.resources).id = "[concat(resourceId('Microsoft.OperationalInsights/workspaces/providers', parameters('workspace'), 'Microsoft.SecurityInsights'),'/alertRules/" + $convert.id + "')]"
            $($template.resources).name = "[concat(parameters('workspace'),'/Microsoft.SecurityInsights/" + $convert.id + "')]"
            $($template.resources).properties = ($convert | Select-Object * -ExcludeProperty id)

            #Based of output path variable export files to the right folder
            if ($null -ne $expPath) {
                $outputFile = $expPath + "/" + $($_.BaseName) + ".json"
            }
            else {

                $outputFile = $($_.DirectoryName) + "/" + $($_.BaseName) + ".json"
            }

            #Export to JSON
            try {
                $template | ConvertTo-Json -Depth 20 | Out-File $outputFile -ErrorAction Stop
            }
            catch {
                Write-Error $_.Exception.Message
            }
        }
    }
    else {
        Write-Error "No YAML templates found"
        break
    }

}

