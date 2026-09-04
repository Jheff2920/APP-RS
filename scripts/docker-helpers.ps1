function Find-Docker {
    $cmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $path = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
    if (Test-Path $path) { return $path }
    throw "Docker no encontrado. Instala Docker Desktop y reinicia la PC."
}

function Find-DockerCompose {
    $cmd = Get-Command docker-compose -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $docker = Find-Docker
    $composePlugin = Join-Path (Split-Path $docker) "..\cli-plugins\docker-compose.exe"
    if (Test-Path $composePlugin) { return "$docker compose" }

    throw "Docker Compose no encontrado."
}

function Invoke-DockerCompose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $docker = Find-Docker
    & $docker compose @Args
}
