# Pester tests for AutoPaqet.Install module

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot "..\..\lib\powershell\AutoPaqet.Install.ps1"
    . $modulePath

    # Create a temp directory for test files
    $script:TestDir = Join-Path $env:TEMP "autopaqet-install-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
}

AfterAll {
    # Clean up temp directory
    if (Test-Path $script:TestDir) {
        Remove-Item -Path $script:TestDir -Recurse -Force
    }
}

Describe "Get-BinaryDownloadUrl" {
    It "constructs correct URL for windows-amd64" {
        $url = Get-BinaryDownloadUrl -ReleaseTag "v1.0.0" -Platform "windows-amd64"
        $url | Should -Be "https://github.com/omid3098/autopaqet/releases/download/v1.0.0/paqet-windows-amd64.exe"
    }

    It "constructs correct URL for linux-amd64 without .exe extension" {
        $url = Get-BinaryDownloadUrl -ReleaseTag "v1.0.0" -Platform "linux-amd64"
        $url | Should -Be "https://github.com/omid3098/autopaqet/releases/download/v1.0.0/paqet-linux-amd64"
    }

    It "constructs correct URL for linux-arm64 without .exe extension" {
        $url = Get-BinaryDownloadUrl -ReleaseTag "v2.0.0" -Platform "linux-arm64"
        $url | Should -Be "https://github.com/omid3098/autopaqet/releases/download/v2.0.0/paqet-linux-arm64"
    }

    It "includes the release tag in the URL path" {
        $url = Get-BinaryDownloadUrl -ReleaseTag "v3.5.1" -Platform "windows-amd64"
        $url | Should -Match "v3\.5\.1"
    }

    It "uses the correct GitHub repo URL base" {
        $url = Get-BinaryDownloadUrl -ReleaseTag "v1.0.0" -Platform "windows-amd64"
        $url | Should -Match "^https://github\.com/omid3098/autopaqet/releases/download/"
    }

    It "adds .exe extension only for windows platforms" {
        $winUrl = Get-BinaryDownloadUrl -ReleaseTag "v1.0.0" -Platform "windows-amd64"
        $linuxUrl = Get-BinaryDownloadUrl -ReleaseTag "v1.0.0" -Platform "linux-amd64"

        $winUrl | Should -Match "\.exe$"
        $linuxUrl | Should -Not -Match "\.exe$"
    }
}

Describe "Get-MissingDependencies" {
    It "does not include Git in results" {
        $missing = Get-MissingDependencies
        $missing | Should -Not -Contain "Git"
    }

    It "does not include Go in results" {
        $missing = Get-MissingDependencies
        $missing | Should -Not -Contain "Go"
    }

    It "does not include GCC in results" {
        $missing = Get-MissingDependencies
        $missing | Should -Not -Contain "GCC"
    }

    It "only returns Npcap or empty" {
        $missing = Get-MissingDependencies
        # Result is either $null (nothing missing) or contains only "Npcap"
        if ($null -ne $missing) {
            $missing | Should -Contain "Npcap"
            $missing.Count | Should -Be 1
        }
    }
}

Describe "Get-PaqetBinary" {
    Context "When binary already exists" {
        It "skips download when binary exists and Force is not set" {
            $binaryPath = Join-Path $script:TestDir "existing-binary-$(Get-Random).exe"
            Set-Content -Path $binaryPath -Value "fake binary"

            $result = Get-PaqetBinary -OutputPath $binaryPath
            $result | Should -Be $true
            Test-Path $binaryPath | Should -Be $true
        }

        It "returns true without modifying existing binary" {
            $binaryPath = Join-Path $script:TestDir "keep-binary-$(Get-Random).exe"
            Set-Content -Path $binaryPath -Value "original content"
            $originalContent = Get-Content $binaryPath -Raw

            Get-PaqetBinary -OutputPath $binaryPath
            $newContent = Get-Content $binaryPath -Raw
            $newContent | Should -Be $originalContent
        }
    }

    Context "When binary does not exist" {
        It "returns false when download fails" {
            $binaryPath = Join-Path $script:TestDir "nonexistent-$(Get-Random).exe"

            Mock Invoke-WebRequest { throw "Simulated download failure" }

            $result = Get-PaqetBinary -OutputPath $binaryPath
            $result | Should -Be $false
        }
    }
}
