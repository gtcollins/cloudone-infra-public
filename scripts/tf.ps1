# Run Terraform for one environment, using envs\<env>\ values.
#
#   .\scripts\tf.ps1 dev init                 # connect to dev's state bucket
#   .\scripts\tf.ps1 dev plan -out=dev.tfplan
#   .\scripts\tf.ps1 dev apply dev.tfplan
#   .\scripts\tf.ps1 prod output
#
# Each environment gets its own .terraform cache, so switching between dev and
# prod never needs `init -reconfigure`.

$root = Split-Path -Parent $PSScriptRoot
$envs = (Get-ChildItem -Directory (Join-Path $root 'envs')).Name -join ' '
$usage = "usage: .\scripts\tf.ps1 <env> <terraform command> [args...]   envs: $envs"

if ($args.Count -lt 2) { Write-Error $usage; exit 2 }
$envName = $args[0]
$cmd = $args[1]
$rest = @($args | Select-Object -Skip 2)

$envDir = Join-Path $root "envs\$envName"
if (-not (Test-Path (Join-Path $envDir 'terraform.tfvars'))) { Write-Error "No such environment: envs\$envName`n$usage"; exit 2 }

$env:TF_DATA_DIR = Join-Path $root ".terraform-envs\$envName"
$stack = Join-Path $root 'stack'
$varFile = "-var-file=$(Join-Path $envDir 'terraform.tfvars')"

switch ($cmd) {
  'init' {
    terraform "-chdir=$stack" init "-backend-config=$(Join-Path $envDir 'backend.hcl')" @rest
  }
  'apply' {
    # A saved plan already contains its variables.
    if ($rest.Count -gt 0 -and ((Test-Path (Join-Path $stack $rest[0]) -PathType Leaf) -or (Test-Path $rest[0] -PathType Leaf))) {
      terraform "-chdir=$stack" apply @rest
    } else {
      terraform "-chdir=$stack" apply $varFile @rest
    }
  }
  { $_ -in 'plan', 'destroy', 'refresh', 'import', 'console' } {
    terraform "-chdir=$stack" $cmd $varFile @rest
  }
  default {
    terraform "-chdir=$stack" $cmd @rest
  }
}
exit $LASTEXITCODE
