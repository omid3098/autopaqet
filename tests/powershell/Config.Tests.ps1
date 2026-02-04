# Pester tests for AutoPaqet.Config module

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot "..\..\lib\powershell\AutoPaqet.Config.ps1"
    . $modulePath

    # Create a temp directory for test files
    $script:TestDir = Join-Path $env:TEMP "autopaqet-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
}

AfterAll {
    # Clean up temp directory
    if (Test-Path $script:TestDir) {
        Remove-Item -Path $script:TestDir -Recurse -Force
    }
}

Describe "New-ClientConfiguration" {
    It "generates valid YAML content" {
        $networkConfig = @{
            InterfaceName = "Ethernet"
            NpcapGUID     = "\Device\NPF_{12345}"
            LocalIP       = "192.168.1.100"
            GatewayMAC    = "aa:bb:cc:dd:ee:ff"
        }

        $content = New-ClientConfiguration `
            -NetworkConfig $networkConfig `
            -ServerAddress "10.0.0.1:9999" `
            -SecretKey "test-key"

        $content | Should -Match 'role:\s*"client"'
        $content | Should -Match 'interface:\s*"Ethernet"'
        $content | Should -Match 'addr:\s*"10\.0\.0\.1:9999"'
        $content | Should -Match 'key:\s*"test-key"'
    }

    It "uses random port when LocalPort is 0" {
        $networkConfig = @{
            InterfaceName = "Ethernet"
            NpcapGUID     = "\Device\NPF_{12345}"
            LocalIP       = "192.168.1.100"
            GatewayMAC    = "aa:bb:cc:dd:ee:ff"
        }

        $content = New-ClientConfiguration `
            -NetworkConfig $networkConfig `
            -ServerAddress "10.0.0.1:9999" `
            -SecretKey "test-key" `
            -LocalPort 0

        # Port should be in the random range
        $content | Should -Match '192\.168\.1\.100:\d{5}'
    }

    It "uses specified port when LocalPort is provided" {
        $networkConfig = @{
            InterfaceName = "Ethernet"
            NpcapGUID     = "\Device\NPF_{12345}"
            LocalIP       = "192.168.1.100"
            GatewayMAC    = "aa:bb:cc:dd:ee:ff"
        }

        $content = New-ClientConfiguration `
            -NetworkConfig $networkConfig `
            -ServerAddress "10.0.0.1:9999" `
            -SecretKey "test-key" `
            -LocalPort 12345

        $content | Should -Match '192\.168\.1\.100:12345'
    }
}

Describe "Save-Configuration and Test-ConfigurationExists" {
    It "saves configuration file" {
        $testPath = Join-Path $script:TestDir "test-config.yaml"
        $content = "test: content"

        Save-Configuration -Path $testPath -Content $content

        Test-Path $testPath | Should -Be $true
        (Get-Content $testPath -Raw).Trim() | Should -Be $content
    }

    It "Test-ConfigurationExists returns true for existing file" {
        $testPath = Join-Path $script:TestDir "exists.yaml"
        Set-Content -Path $testPath -Value "test"

        Test-ConfigurationExists -Path $testPath | Should -Be $true
    }

    It "Test-ConfigurationExists returns false for non-existing file" {
        $testPath = Join-Path $script:TestDir "not-exists.yaml"

        Test-ConfigurationExists -Path $testPath | Should -Be $false
    }
}

Describe "Get-ConfigurationValue" {
    BeforeAll {
        $script:TestConfigPath = Join-Path $script:TestDir "get-value-test.yaml"
        $content = @"
role: "client"

socks5:
  - listen: "127.0.0.1:1080"

network:
  interface: "Ethernet"
  ipv4:
    router_mac: "aa:bb:cc:dd:ee:ff"

server:
  addr: "10.0.0.1:9999"

transport:
  kcp:
    key: "secret-key-123"
"@
        Set-Content -Path $script:TestConfigPath -Value $content
    }

    It "extracts server.addr" {
        $value = Get-ConfigurationValue -Path $script:TestConfigPath -Key "server.addr"
        $value | Should -Be "10.0.0.1:9999"
    }

    It "extracts transport.kcp.key" {
        $value = Get-ConfigurationValue -Path $script:TestConfigPath -Key "transport.kcp.key"
        $value | Should -Be "secret-key-123"
    }

    It "extracts network.interface" {
        $value = Get-ConfigurationValue -Path $script:TestConfigPath -Key "network.interface"
        $value | Should -Be "Ethernet"
    }

    It "extracts network.ipv4.router_mac" {
        $value = Get-ConfigurationValue -Path $script:TestConfigPath -Key "network.ipv4.router_mac"
        $value | Should -Be "aa:bb:cc:dd:ee:ff"
    }

    It "returns null for non-existing file" {
        $value = Get-ConfigurationValue -Path "nonexistent.yaml" -Key "server.addr"
        $value | Should -BeNullOrEmpty
    }
}

Describe "Set-ConfigurationValue" {
    BeforeEach {
        $script:TestConfigPath = Join-Path $script:TestDir "set-value-test-$(Get-Random).yaml"
        $content = @"
server:
  addr: "old-server:9999"

transport:
  kcp:
    key: "old-key"
"@
        Set-Content -Path $script:TestConfigPath -Value $content
    }

    It "updates server.addr" {
        $result = Set-ConfigurationValue -Path $script:TestConfigPath -Key "server.addr" -Value "new-server:8888"
        $result | Should -Be $true

        $newContent = Get-Content $script:TestConfigPath -Raw
        $newContent | Should -Match 'addr:\s*"new-server:8888"'
    }

    It "updates transport.kcp.key" {
        $result = Set-ConfigurationValue -Path $script:TestConfigPath -Key "transport.kcp.key" -Value "new-secret"
        $result | Should -Be $true

        $newContent = Get-Content $script:TestConfigPath -Raw
        $newContent | Should -Match 'key:\s*"new-secret"'
    }

    It "returns false for non-existing file" {
        $result = Set-ConfigurationValue -Path "nonexistent.yaml" -Key "server.addr" -Value "test"
        $result | Should -Be $false
    }
}

Describe "Get-ConfigurationSummary" {
    BeforeAll {
        $script:TestConfigPath = Join-Path $script:TestDir "summary-test.yaml"
        $content = @"
role: "client"

socks5:
  - listen: "127.0.0.1:1080"

network:
  interface: "Ethernet"
  ipv4:
    router_mac: "aa:bb:cc:dd:ee:ff"

server:
  addr: "10.0.0.1:9999"

transport:
  kcp:
    key: "secret-key"
"@
        Set-Content -Path $script:TestConfigPath -Value $content
    }

    It "returns summary hashtable" {
        $summary = Get-ConfigurationSummary -Path $script:TestConfigPath

        $summary | Should -Not -BeNullOrEmpty
        $summary.ServerAddress | Should -Be "10.0.0.1:9999"
        $summary.Interface | Should -Be "Ethernet"
        $summary.RouterMAC | Should -Be "aa:bb:cc:dd:ee:ff"
        $summary.HasKey | Should -Be $true
    }

    It "returns null for non-existing file" {
        $summary = Get-ConfigurationSummary -Path "nonexistent.yaml"
        $summary | Should -BeNullOrEmpty
    }
}
