$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..
. "$PSScriptRoot\docker-helpers.ps1"

Invoke-DockerCompose run --rm flutter bash
