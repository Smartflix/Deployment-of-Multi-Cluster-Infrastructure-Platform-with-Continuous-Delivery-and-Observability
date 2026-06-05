param(
  [Parameter(Mandatory = $true)]
  [string]$DockerHubUser,

  [string]$Tag = "latest",

  [switch]$SkipLogin
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$images = @(
  @{ Name = "frontend"; Repository = "cloudopshub-frontend"; Context = "apps/frontend" },
  @{ Name = "backend"; Repository = "cloudopshub-backend"; Context = "apps/backend" },
  @{ Name = "db"; Repository = "cloudopshub-db"; Context = "apps/db" }
)

docker info | Out-Null

if (-not $SkipLogin) {
  docker login
}

foreach ($image in $images) {
  $fullTag = "docker.io/$DockerHubUser/$($image.Repository):$Tag"
  $context = Join-Path $root $image.Context

  Write-Host "Building $($image.Name): $fullTag"
  docker build -t $fullTag $context

  Write-Host "Pushing $($image.Name): $fullTag"
  docker push $fullTag
}

Write-Host "Done. Images pushed with tag '$Tag'."
