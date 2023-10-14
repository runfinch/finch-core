<#
    Verify file hashes using pure PowerShell
#>
param (
    # Dependency file path
    [Parameter(Mandatory=$true)]
    [string]$DependencyFilePath,
    
    # Dependency hash
    [Parameter(Mandatory=$true)]
    [string]$DependencyHash = 'out.png'
)

if (!(Get-FileHash -Algorithm SHA256 "$DependencyFilePath").Hash -eq $DependencyHash) {
    $host.SetShouldExit(-1); exit
} else {
    Write-Output "Verified $DependencyFilePath"
}
