# Pester tests for AutoPaqet.State module

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot "..\..\lib\powershell\AutoPaqet.State.ps1"
    . $modulePath

    # Create a temp directory for test files
    $script:TestDir = Join-Path $env:TEMP "autopaqet-state-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null

    # Helper to create a valid config file
    $script:CreateValidConfig = {
        param([string]$Path)
        $content = @"
role: "client"

network:
  interface: "Ethernet"
  guid: '\Device\NPF_{12345}'
  ipv4:
    addr: "192.168.1.100:12345"
    router_mac: "aa:bb:cc:dd:ee:ff"

server:
  addr: "10.0.0.1:9999"

transport:
  kcp:
    key: "test-secret-key"
"@
        Set-Content -Path $Path -Value $content
    }

    # Helper to create a fake binary
    $script:CreateFakeBinary = {
        param([string]$Path)
        Set-Content -Path $Path -Value "fake binary content"
    }
}

AfterAll {
    # Clean up temp directory
    if (Test-Path $script:TestDir) {
        Remove-Item -Path $script:TestDir -Recurse -Force
    }
}

Describe "Get-InstallationState" {
    Context "Ready state" {
        BeforeEach {
            $script:TestBinary = Join-Path $script:TestDir "paqet-$(Get-Random).exe"
            $script:TestConfig = Join-Path $script:TestDir "client-$(Get-Random).yaml"
            & $script:CreateFakeBinary $script:TestBinary
            & $script:CreateValidConfig $script:TestConfig
        }

        It "returns Ready when binary and valid config exist" {
            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $script:TestConfig
            $state.State | Should -Be "Ready"
        }

        It "sets BinaryExists to true when paqet.exe found" {
            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $script:TestConfig
            $state.BinaryExists | Should -Be $true
        }

        It "sets ConfigValid to true when config has server, key, interface" {
            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $script:TestConfig
            $state.ConfigValid | Should -Be $true
        }

        It "sets IsFullyInstalled to true when Ready" {
            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $script:TestConfig
            $state.IsFullyInstalled | Should -Be $true
        }

        It "has empty Issues array when Ready" {
            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $script:TestConfig
            $state.Issues.Count | Should -Be 0
        }
    }

    Context "Partial installation" {
        It "returns PartialInstall when only binary exists" {
            $binaryPath = Join-Path $script:TestDir "paqet-only-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).yaml"
            & $script:CreateFakeBinary $binaryPath

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.State | Should -Be "PartialInstall"
        }

        It "returns PartialInstall when only config exists" {
            $binaryPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "config-only-$(Get-Random).yaml"
            & $script:CreateValidConfig $configPath

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.State | Should -Be "PartialInstall"
        }

        It "returns Configured when config exists but is invalid" {
            $binaryPath = Join-Path $script:TestDir "paqet-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "invalid-$(Get-Random).yaml"
            & $script:CreateFakeBinary $binaryPath
            # Create invalid config (missing required fields)
            Set-Content -Path $configPath -Value "role: client"

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.State | Should -Be "Configured"
        }

        It "sets IsFullyInstalled to false for partial installs" {
            $binaryPath = Join-Path $script:TestDir "paqet-partial-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).yaml"
            & $script:CreateFakeBinary $binaryPath

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.IsFullyInstalled | Should -Be $false
        }
    }

    Context "Not installed" {
        It "returns NotInstalled when neither binary nor config exist" {
            $binaryPath = Join-Path $script:TestDir "nonexistent-bin-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "nonexistent-cfg-$(Get-Random).yaml"

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.State | Should -Be "NotInstalled"
        }

        It "populates Issues array with missing items" {
            $binaryPath = Join-Path $script:TestDir "nonexistent-bin-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "nonexistent-cfg-$(Get-Random).yaml"

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.Issues.Count | Should -BeGreaterThan 0
            $state.Issues | Should -Contain "Binary not found: $binaryPath"
            $state.Issues | Should -Contain "Configuration not found: $configPath"
        }

        It "sets BinaryExists to false when binary missing" {
            $binaryPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).yaml"

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.BinaryExists | Should -Be $false
        }

        It "sets ConfigExists to false when config missing" {
            $binaryPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).exe"
            $configPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).yaml"

            $state = Get-InstallationState -BinaryPath $binaryPath -ConfigPath $configPath
            $state.ConfigExists | Should -Be $false
        }
    }

    Context "Config validation" {
        BeforeEach {
            $script:TestBinary = Join-Path $script:TestDir "paqet-validation-$(Get-Random).exe"
            & $script:CreateFakeBinary $script:TestBinary
        }

        It "detects missing server address" {
            $configPath = Join-Path $script:TestDir "no-server-$(Get-Random).yaml"
            $content = @"
network:
  interface: "Ethernet"
transport:
  kcp:
    key: "test-key"
"@
            Set-Content -Path $configPath -Value $content

            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $configPath
            $state.ConfigValid | Should -Be $false
            $state.Issues | Should -Contain "Missing server address"
        }

        It "detects missing secret key" {
            $configPath = Join-Path $script:TestDir "no-key-$(Get-Random).yaml"
            $content = @"
network:
  interface: "Ethernet"
server:
  addr: "10.0.0.1:9999"
"@
            Set-Content -Path $configPath -Value $content

            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $configPath
            $state.ConfigValid | Should -Be $false
            $state.Issues | Should -Contain "Missing secret key"
        }

        It "detects missing network interface" {
            $configPath = Join-Path $script:TestDir "no-interface-$(Get-Random).yaml"
            $content = @"
server:
  addr: "10.0.0.1:9999"
transport:
  kcp:
    key: "test-key"
"@
            Set-Content -Path $configPath -Value $content

            $state = Get-InstallationState -BinaryPath $script:TestBinary -ConfigPath $configPath
            $state.ConfigValid | Should -Be $false
            $state.Issues | Should -Contain "Missing network interface"
        }
    }
}

Describe "Test-ConfigurationValid" {
    Context "Valid configurations" {
        It "returns IsValid true for complete config" {
            $configPath = Join-Path $script:TestDir "valid-cfg-$(Get-Random).yaml"
            & $script:CreateValidConfig $configPath

            $result = Test-ConfigurationValid -ConfigPath $configPath
            $result.IsValid | Should -Be $true
            $result.Issues.Count | Should -Be 0
        }
    }

    Context "Invalid configurations" {
        It "returns IsValid false for non-existent file" {
            $configPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).yaml"

            $result = Test-ConfigurationValid -ConfigPath $configPath
            $result.IsValid | Should -Be $false
        }

        It "returns IsValid false for empty file" {
            $configPath = Join-Path $script:TestDir "empty-$(Get-Random).yaml"
            Set-Content -Path $configPath -Value ""

            $result = Test-ConfigurationValid -ConfigPath $configPath
            $result.IsValid | Should -Be $false
        }

        It "returns specific issues for each missing field" {
            $configPath = Join-Path $script:TestDir "partial-$(Get-Random).yaml"
            Set-Content -Path $configPath -Value "role: client"

            $result = Test-ConfigurationValid -ConfigPath $configPath
            $result.IsValid | Should -Be $false
            $result.Issues | Should -Contain "Missing server address"
            $result.Issues | Should -Contain "Missing secret key"
            $result.Issues | Should -Contain "Missing network interface"
        }
    }
}

Describe "Get-InstallationStateMessage" {
    It "returns 'Ready to run' for Ready state" {
        $msg = Get-InstallationStateMessage -State "Ready"
        $msg | Should -Be "Ready to run"
    }

    It "returns correct message for Configured state" {
        $msg = Get-InstallationStateMessage -State "Configured"
        $msg | Should -Be "Configured (validation issues)"
    }

    It "returns correct message for PartialInstall state" {
        $msg = Get-InstallationStateMessage -State "PartialInstall"
        $msg | Should -Be "Partial installation"
    }

    It "returns correct message for NotInstalled state" {
        $msg = Get-InstallationStateMessage -State "NotInstalled"
        $msg | Should -Be "Not installed"
    }
}
