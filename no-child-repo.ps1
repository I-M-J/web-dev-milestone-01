# no-child-repo.ps1
# Script to manage Git-related files in child repositories
# Usage: 
#   .\no-child-repo.ps1 --out  (Move Git files out and create zip)
#   .\no-child-repo.ps1 --in   (Extract zip and restore Git files)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("--out", "--in")]
    [string]$Action
)

# Configuration
$RootDir = Get-Location
$NoChildRepoFolder = Join-Path $RootDir "no-child-repo"
$ZipFileName = "no-child-repo.zip"
$ZipFilePath = Join-Path $RootDir $ZipFileName

# Git-related files and folders to move
$GitPatterns = @(".git", ".gitignore", ".gitattributes", ".gitmodules", ".gitkeep")

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Move-GitFilesOut {
    Write-ColorOutput Yellow "`n=== Starting --out operation ===`n"
    
    # Check if no-child-repo folder already exists
    if (Test-Path $NoChildRepoFolder) {
        Write-ColorOutput Red "Error: '$NoChildRepoFolder' folder already exists!"
        Write-ColorOutput Red "Please remove it manually before running --out operation."
        exit 1
    }
    
    # Check if zip file already exists
    if (Test-Path $ZipFilePath) {
        Write-ColorOutput Red "Error: '$ZipFileName' already exists!"
        Write-ColorOutput Red "Please remove it manually before running --out operation."
        exit 1
    }
    
    Write-ColorOutput Cyan "Searching for Git-related files and folders...`n"
    
    # Find all Git-related items (excluding root directory items)
    $gitItems = @()
    foreach ($pattern in $GitPatterns) {
        $found = Get-ChildItem -Path $RootDir -Filter $pattern -Recurse -Force -ErrorAction SilentlyContinue |
                 Where-Object { 
                    # Exclude items in no-child-repo folder
                    ($_.FullName -notlike "*\no-child-repo\*") -and
                    # Exclude items directly in root directory (only target subdirectories)
                    ((Split-Path $_.FullName -Parent) -ne $RootDir.Path)
                 }
        $gitItems += $found
    }
    
    if ($gitItems.Count -eq 0) {
        Write-ColorOutput Yellow "No Git-related files or folders found."
        exit 0
    }
    
    Write-ColorOutput Green "Found $($gitItems.Count) Git-related items.`n"
    
    # Create no-child-repo folder
    New-Item -Path $NoChildRepoFolder -ItemType Directory -Force | Out-Null
    
    # Move Git items while preserving directory structure
    foreach ($item in $gitItems) {
        $relativePath = $item.FullName.Substring($RootDir.Path.Length + 1)
        $destPath = Join-Path $NoChildRepoFolder $relativePath
        $destDir = Split-Path $destPath -Parent
        
        # Create destination directory if it doesn't exist
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        
        try {
            Move-Item -LiteralPath $item.FullName -Destination $destPath -Force
            Write-ColorOutput Gray "  Moved: $relativePath"
        }
        catch {
            Write-ColorOutput Red "  Failed to move: $relativePath"
            Write-ColorOutput Red "  Error: $_"
        }
    }
    
    Write-ColorOutput Cyan "`nCreating zip file: $ZipFileName..."
    
    # Create zip file
    try {
        Add-Type -Assembly System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($NoChildRepoFolder, $ZipFilePath, 'Optimal', $false)
        Write-ColorOutput Green "`nZip file created successfully: $ZipFileName"
        
        # Remove the no-child-repo folder after zipping
        Remove-Item -Path $NoChildRepoFolder -Recurse -Force
        Write-ColorOutput Green "Temporary folder removed.`n"
        
        Write-ColorOutput Yellow "=== --out operation completed successfully ===`n"
    }
    catch {
        Write-ColorOutput Red "`nError creating zip file: $_"
        exit 1
    }
}

function Move-GitFilesIn {
    Write-ColorOutput Yellow "`n=== Starting --in operation ===`n"
    
    # Check if zip file exists
    if (-not (Test-Path $ZipFilePath)) {
        Write-ColorOutput Red "Error: '$ZipFileName' not found!"
        Write-ColorOutput Red "Please make sure the zip file exists in the root directory."
        exit 1
    }
    
    # Check if no-child-repo folder already exists
    if (Test-Path $NoChildRepoFolder) {
        Write-ColorOutput Red "Error: '$NoChildRepoFolder' folder already exists!"
        Write-ColorOutput Red "Please remove it manually before running --in operation."
        exit 1
    }
    
    Write-ColorOutput Cyan "Extracting zip file: $ZipFileName...`n"
    
    # Extract zip file
    try {
        Add-Type -Assembly System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFilePath, $NoChildRepoFolder)
        Write-ColorOutput Green "Zip file extracted successfully.`n"
    }
    catch {
        Write-ColorOutput Red "Error extracting zip file: $_"
        exit 1
    }
    
    Write-ColorOutput Cyan "Restoring Git-related files to original locations...`n"
    
    # Move Git items back to their original locations
    $gitItems = Get-ChildItem -Path $NoChildRepoFolder -Recurse -Force
    
    foreach ($item in $gitItems) {
        $relativePath = $item.FullName.Substring($NoChildRepoFolder.Length + 1)
        $destPath = Join-Path $RootDir $relativePath
        $destDir = Split-Path $destPath -Parent
        
        # Create destination directory if it doesn't exist
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        
        try {
            if ($item.PSIsContainer) {
                # It's a directory - only create if it doesn't exist
                if (-not (Test-Path $destPath)) {
                    New-Item -Path $destPath -ItemType Directory -Force | Out-Null
                    Write-ColorOutput Gray "  Created directory: $relativePath"
                }
            }
            else {
                # It's a file - move it
                Move-Item -LiteralPath $item.FullName -Destination $destPath -Force
                Write-ColorOutput Gray "  Restored: $relativePath"
            }
        }
        catch {
            Write-ColorOutput Red "  Failed to restore: $relativePath"
            Write-ColorOutput Red "  Error: $_"
        }
    }
    
    Write-ColorOutput Cyan "`nRemoving temporary folder: no-child-repo..."
    
    # Remove the no-child-repo folder
    try {
        Remove-Item -Path $NoChildRepoFolder -Recurse -Force
        Write-ColorOutput Green "Temporary folder removed.`n"
    }
    catch {
        Write-ColorOutput Red "Error removing temporary folder: $_"
        Write-ColorOutput Yellow "Please remove '$NoChildRepoFolder' manually.`n"
    }
    
    Write-ColorOutput Cyan "Removing zip file: $ZipFileName..."
    
    # Remove the zip file
    try {
        Remove-Item -Path $ZipFilePath -Force
        Write-ColorOutput Green "Zip file removed.`n"
        
        Write-ColorOutput Yellow "=== --in operation completed successfully ===`n"
    }
    catch {
        Write-ColorOutput Red "Error removing zip file: $_"
        Write-ColorOutput Yellow "Please remove '$ZipFileName' manually.`n"
    }
}

# Main execution
switch ($Action) {
    "--out" {
        Move-GitFilesOut
    }
    "--in" {
        Move-GitFilesIn
    }
}