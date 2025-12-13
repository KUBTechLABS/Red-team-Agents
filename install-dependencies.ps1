# =============================================================================
# Red Team Agents - Automated Dependency Installation Script
# =============================================================================
# Purpose: Automates installation of all Tier 1 and Tier 2 tools via Chocolatey
# Author: KUBTechLABS
# Date: 2025-12-13
# Version: 1.0
# =============================================================================

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$SkipVerification = $false,
    [switch]$SkipAnythingLLM = $false,
    [switch]$VerboseOutput = $false
)

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

$ErrorActionPreference = "Stop"
$VerbosePreference = if ($VerboseOutput) { "Continue" } else { "SilentlyContinue" }

# Define Tier 1 tools (Core dependencies)
$Tier1Tools = @{
    "python" = "3.11"
    "nodejs" = "latest"
    "git" = "latest"
    "powershell-core" = "latest"
    "curl" = "latest"
}

# Define Tier 2 tools (Advanced tools)
$Tier2Tools = @{
    "docker-desktop" = "latest"
    "vscode" = "latest"
    "7zip" = "latest"
    "wget" = "latest"
    "grep" = "latest"
    "sed" = "latest"
}

# Additional Python packages required
$PythonPackages = @(
    "requests",
    "beautifulsoup4",
    "flask",
    "django",
    "numpy",
    "pandas",
    "pycryptodome",
    "paramiko",
    "scapy",
    "pwntools"
)

# NPM packages
$NPMPackages = @(
    "typescript",
    "webpack",
    "eslint"
)

# Color definitions for output
$ColorGreen = "Green"
$ColorRed = "Red"
$ColorYellow = "Yellow"
$ColorCyan = "Cyan"
$ColorMagenta = "Magenta"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor $ColorCyan
    Write-Host $Message -ForegroundColor $ColorCyan
    Write-Host "=" * 80 -ForegroundColor $ColorCyan
}

function Write-Section {
    param([string]$Message)
    Write-Host "`n" -NoNewline
    Write-Host ">> $Message" -ForegroundColor $ColorMagenta
    Write-Host "-" * 80 -ForegroundColor $ColorMagenta
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor $ColorGreen
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor $ColorRed
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor $ColorYellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor $ColorCyan
}

# =============================================================================
# ADMINISTRATIVE CHECKS
# =============================================================================

function Test-AdminRights {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    
    if (-not $isAdmin) {
        Write-Error-Custom "This script requires Administrator privileges."
        Write-Info "Please run PowerShell as Administrator and try again."
        exit 1
    }
    
    Write-Success "Administrator rights verified"
}

# =============================================================================
# CHOCOLATEY FUNCTIONS
# =============================================================================

function Test-ChocolateyInstalled {
    try {
        choco --version | Out-Null
        Write-Success "Chocolatey is already installed"
        return $true
    }
    catch {
        Write-Warning-Custom "Chocolatey is not installed"
        return $false
    }
}

function Install-Chocolatey {
    Write-Section "Installing Chocolatey Package Manager"
    
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        
        $chocoInstallScript = @"
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
"@
        
        Invoke-Expression $chocoInstallScript
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Success "Chocolatey installed successfully"
        Start-Sleep -Seconds 2
        return $true
    }
    catch {
        Write-Error-Custom "Failed to install Chocolatey: $_"
        return $false
    }
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

function Install-Tool {
    param(
        [string]$ToolName,
        [string]$Version = "latest"
    )
    
    Write-Info "Installing $ToolName..."
    
    try {
        if ($Version -eq "latest") {
            choco install $ToolName -y --no-progress
        }
        else {
            choco install $ToolName --version=$Version -y --no-progress
        }
        
        Write-Success "$ToolName installed successfully"
        return $true
    }
    catch {
        Write-Error-Custom "Failed to install $ToolName : $_"
        return $false
    }
}

function Install-Tier1Tools {
    Write-Section "Installing Tier 1 Tools (Core Dependencies)"
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($tool in $Tier1Tools.GetEnumerator()) {
        if (Install-Tool -ToolName $tool.Key -Version $tool.Value) {
            $successCount++
        }
        else {
            $failureCount++
        }
        Start-Sleep -Milliseconds 500
    }
    
    Write-Info "Tier 1 Installation Summary: $successCount succeeded, $failureCount failed"
    return @{ Success = $successCount; Failure = $failureCount }
}

function Install-Tier2Tools {
    Write-Section "Installing Tier 2 Tools (Advanced Tools)"
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($tool in $Tier2Tools.GetEnumerator()) {
        if (Install-Tool -ToolName $tool.Key -Version $tool.Value) {
            $successCount++
        }
        else {
            $failureCount++
            Write-Warning-Custom "Tier 2 tool $($tool.Key) may require manual installation"
        }
        Start-Sleep -Milliseconds 500
    }
    
    Write-Info "Tier 2 Installation Summary: $successCount succeeded, $failureCount failed"
    return @{ Success = $successCount; Failure = $failureCount }
}

function Install-PythonPackages {
    Write-Section "Installing Python Packages"
    
    # Refresh environment to ensure Python is accessible
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    $successCount = 0
    $failureCount = 0
    
    try {
        python --version | Out-Null
    }
    catch {
        Write-Error-Custom "Python is not accessible. Please ensure Python 3.11+ is installed and in PATH."
        return @{ Success = 0; Failure = $PythonPackages.Count }
    }
    
    foreach ($package in $PythonPackages) {
        Write-Info "Installing Python package: $package..."
        try {
            python -m pip install --upgrade $package 2>&1 | Out-Null
            Write-Success "$package installed successfully"
            $successCount++
        }
        catch {
            Write-Error-Custom "Failed to install $package : $_"
            $failureCount++
        }
    }
    
    Write-Info "Python Packages Installation Summary: $successCount succeeded, $failureCount failed"
    return @{ Success = $successCount; Failure = $failureCount }
}

function Install-NPMPackages {
    Write-Section "Installing NPM Packages"
    
    # Refresh environment to ensure npm is accessible
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    $successCount = 0
    $failureCount = 0
    
    try {
        npm --version | Out-Null
    }
    catch {
        Write-Error-Custom "npm is not accessible. Please ensure Node.js is installed and in PATH."
        return @{ Success = 0; Failure = $NPMPackages.Count }
    }
    
    foreach ($package in $NPMPackages) {
        Write-Info "Installing NPM package: $package..."
        try {
            npm install -g $package 2>&1 | Out-Null
            Write-Success "$package installed successfully"
            $successCount++
        }
        catch {
            Write-Error-Custom "Failed to install $package : $_"
            $failureCount++
        }
    }
    
    Write-Info "NPM Packages Installation Summary: $successCount succeeded, $failureCount failed"
    return @{ Success = $successCount; Failure = $failureCount }
}

# =============================================================================
# VERIFICATION FUNCTIONS
# =============================================================================

function Verify-Tool {
    param(
        [string]$ToolName,
        [string]$VersionCommand = "--version"
    )
    
    try {
        $output = & $ToolName $VersionCommand 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "$ToolName : $($output | Select-Object -First 1)"
            return $true
        }
        else {
            Write-Error-Custom "$ToolName verification failed"
            return $false
        }
    }
    catch {
        Write-Error-Custom "$ToolName is not accessible: $_"
        return $false
    }
}

function Verify-Installations {
    Write-Section "Verifying Tool Installations"
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    $verificationMap = @{
        "python" = "python"
        "node" = "node"
        "git" = "git"
        "pwsh" = "pwsh"
        "curl" = "curl"
        "docker" = "docker"
        "code" = "code"
    }
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($verification in $verificationMap.GetEnumerator()) {
        if (Verify-Tool -ToolName $verification.Value) {
            $successCount++
        }
        else {
            $failureCount++
        }
    }
    
    Write-Info "Verification Summary: $successCount tools verified, $failureCount tools missing"
    return @{ Success = $successCount; Failure = $failureCount }
}

# =============================================================================
# ANYTHINGLLM SETUP FUNCTIONS
# =============================================================================

function Show-AnythingLLMSetupGuide {
    Write-Header "AnythingLLM Setup Guide"
    
    Write-Section "What is AnythingLLM?"
    Write-Info "AnythingLLM is a full-stack application for managing AI models, documents, and RAG pipelines."
    Write-Info "Perfect for Red Team operations with document management and AI integration."
    
    Write-Section "Installation Options"
    Write-Host "`n1. Desktop Application (Recommended for local use)"
    Write-Host "   - Download from: https://useanything.com"
    Write-Host "   - Supports Mac, Windows, and Linux"
    Write-Host "   - Easy graphical interface"
    
    Write-Host "`n2. Docker Installation (Best for server/team deployment)"
    Write-Host "   - Pull image: docker pull mintplexlabs/anythingllm:latest"
    Write-Host "   - Run: docker run -d -p 3001:3001 --name anythingllm mintplexlabs/anythingllm:latest"
    Write-Host "   - Access: http://localhost:3001"
    
    Write-Host "`n3. Source Installation (For developers)"
    Write-Host "   - Clone: git clone https://github.com/Mintplex-Labs/anything-llm.git"
    Write-Host "   - Navigate to frontend folder and run: npm install && npm run build"
    Write-Host "   - Navigate to server folder and run: npm install && npm start"
    
    Write-Section "Configuration Steps"
    Write-Host "`n1. On first launch, you'll be prompted to select:"
    Write-Host "   - LLM Provider (OpenAI, Local LLM, Anthropic, etc.)"
    Write-Host "   - Embedding Model"
    Write-Host "   - Vector Database (Chroma, Pinecone, Weaviate, etc.)"
    
    Write-Host "`n2. Set up your API keys:"
    Write-Host "   - OpenAI API key (optional)"
    Write-Host "   - Other LLM provider keys as needed"
    
    Write-Host "`n3. Create a new workspace:"
    Write-Host "   - Name your workspace (e.g., 'Red-Team-Operations')"
    Write-Host "   - Configure model settings"
    Write-Host "   - Upload documents for RAG"
    
    Write-Section "Recommended Configuration for Red Team"
    Write-Host "`n- LLM Provider: OpenAI (GPT-4) or Local LLM for privacy"
    Write-Host "- Embedding Model: Nomic Embed Text (local) or OpenAI Embeddings"
    Write-Host "- Vector DB: Chroma (local) or Pinecone (cloud)"
    Write-Host "- Document Types: TTPs, IOCs, Malware analysis, Logs"
    
    Write-Section "Useful Resources"
    Write-Host "`n- Official Docs: https://docs.useanything.com"
    Write-Host "- GitHub: https://github.com/Mintplex-Labs/anything-llm"
    Write-Host "- Docker Hub: https://hub.docker.com/r/mintplexlabs/anythingllm"
    Write-Host "- Community: https://discord.gg/6UyHsQwpyM"
}

function Prompt-AnythingLLMSetup {
    Write-Section "AnythingLLM Setup"
    
    Write-Host "`nWould you like help setting up AnythingLLM now?"
    Write-Host "1. View setup guide"
    Write-Host "2. Docker quick start"
    Write-Host "3. Skip for now"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-3)"
    
    switch ($choice) {
        "1" {
            Show-AnythingLLMSetupGuide
        }
        "2" {
            Show-DockerQuickStart
        }
        "3" {
            Write-Info "Skipping AnythingLLM setup. You can run setup anytime."
        }
        default {
            Write-Warning-Custom "Invalid choice. Skipping AnythingLLM setup."
        }
    }
}

function Show-DockerQuickStart {
    Write-Section "Docker Quick Start for AnythingLLM"
    
    Write-Info "Checking Docker installation..."
    
    try {
        $dockerVersion = docker --version
        Write-Success "Docker is installed: $dockerVersion"
    }
    catch {
        Write-Error-Custom "Docker is not accessible. Please install Docker Desktop first."
        return
    }
    
    Write-Host "`nRunning AnythingLLM in Docker..."
    Write-Info "Execute this command in your terminal:"
    Write-Host "`n    docker run -d -p 3001:3001 --name anythingllm -v anythingllm_storage:/app/storage mintplexlabs/anythingllm:latest"
    Write-Host "`nThen access AnythingLLM at: http://localhost:3001`n"
    
    $runNow = Read-Host "Would you like to run this command now? (y/n)"
    
    if ($runNow -eq "y" -or $runNow -eq "Y") {
        try {
            Write-Info "Starting AnythingLLM container..."
            docker run -d -p 3001:3001 --name anythingllm -v anythingllm_storage:/app/storage mintplexlabs/anythingllm:latest
            Write-Success "AnythingLLM container started successfully!"
            Write-Info "Access at: http://localhost:3001"
            Write-Info "It may take a moment to fully start up."
        }
        catch {
            Write-Error-Custom "Failed to start Docker container: $_"
        }
    }
}

# =============================================================================
# SYSTEM INFORMATION FUNCTIONS
# =============================================================================

function Get-SystemInfo {
    Write-Section "System Information"
    
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Info "OS: $($osInfo.Caption)"
    Write-Info "OS Version: $($osInfo.Version)"
    Write-Info "Architecture: $((Get-CimInstance -ClassName Win32_ComputerSystem).SystemType)"
    Write-Info "Processor: $(Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty Name | Select-Object -First 1)"
    Write-Info "RAM: $([math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory) / 1GB)) GB"
    Write-Info "Logged in as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

function Invoke-MainInstallation {
    Write-Header "Red Team Agents - Automated Dependency Installer"
    Write-Info "Version 1.0 | Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Display system info
    Get-SystemInfo
    
    # Check admin rights
    Test-AdminRights
    
    # Chocolatey installation/verification
    Write-Section "Chocolatey Setup"
    if (-not (Test-ChocolateyInstalled)) {
        if (-not (Install-Chocolatey)) {
            Write-Error-Custom "Failed to install Chocolatey. Installation cannot continue."
            exit 1
        }
    }
    
    # Update Chocolatey
    Write-Info "Updating Chocolatey..."
    try {
        choco upgrade chocolatey -y --no-progress | Out-Null
        Write-Success "Chocolatey updated successfully"
    }
    catch {
        Write-Warning-Custom "Could not update Chocolatey, continuing with current version"
    }
    
    # Install Tier 1 tools
    $tier1Results = Install-Tier1Tools
    
    # Install Tier 2 tools
    $tier2Results = Install-Tier2Tools
    
    # Install Python packages
    Start-Sleep -Seconds 3
    $pythonResults = Install-PythonPackages
    
    # Install NPM packages
    Start-Sleep -Seconds 3
    $npmResults = Install-NPMPackages
    
    # Verify installations (unless skipped)
    if (-not $SkipVerification) {
        Start-Sleep -Seconds 3
        $verifyResults = Verify-Installations
    }
    
    # Summary Report
    Write-Header "Installation Summary Report"
    
    Write-Section "Installation Results"
    Write-Host "Tier 1 Tools: $($tier1Results.Success) succeeded, $($tier1Results.Failure) failed"
    Write-Host "Tier 2 Tools: $($tier2Results.Success) succeeded, $($tier2Results.Failure) failed"
    Write-Host "Python Packages: $($pythonResults.Success) succeeded, $($pythonResults.Failure) failed"
    Write-Host "NPM Packages: $($npmResults.Success) succeeded, $($npmResults.Failure) failed"
    
    if (-not $SkipVerification) {
        Write-Host "Verification: $($verifyResults.Success) tools verified, $($verifyResults.Failure) missing"
    }
    
    $totalSuccess = $tier1Results.Success + $tier2Results.Success + $pythonResults.Success + $npmResults.Success
    $totalFailure = $tier1Results.Failure + $tier2Results.Failure + $pythonResults.Failure + $npmResults.Failure
    
    Write-Section "Overall Summary"
    Write-Host "Total Succeeded: $totalSuccess"
    Write-Host "Total Failed: $totalFailure"
    
    if ($totalFailure -eq 0) {
        Write-Success "All installations completed successfully!"
    }
    else {
        Write-Warning-Custom "Some installations failed. Please review the errors above."
    }
    
    # AnythingLLM setup (unless skipped)
    if (-not $SkipAnythingLLM) {
        Prompt-AnythingLLMSetup
    }
    
    Write-Header "Installation Complete"
    Write-Info "Completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Info "Next steps:"
    Write-Info "1. Review any failed installations above"
    Write-Info "2. Restart your terminal to refresh PATH"
    Write-Info "3. Run 'python --version', 'node --version', etc. to verify"
    Write-Info "4. Start using the Red Team Agents tools"
}

# =============================================================================
# ENTRY POINT
# =============================================================================

try {
    Invoke-MainInstallation
}
catch {
    Write-Error-Custom "An unexpected error occurred: $_"
    exit 1
}

exit 0
