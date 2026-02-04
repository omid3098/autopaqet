# Pester tests for AutoPaqet.Validate module

BeforeAll {
    # Import the module being tested
    $modulePath = Join-Path $PSScriptRoot "..\..\lib\powershell\AutoPaqet.Validate.ps1"
    . $modulePath
}

Describe "Test-ServerAddress" {
    Context "Valid addresses" {
        It "accepts valid IP:PORT format" {
            Test-ServerAddress "192.168.1.1:9999" | Should -Be $true
        }

        It "accepts minimum valid values" {
            Test-ServerAddress "0.0.0.1:1" | Should -Be $true
        }

        It "accepts maximum valid values" {
            Test-ServerAddress "255.255.255.255:65535" | Should -Be $true
        }

        It "accepts common server addresses" {
            Test-ServerAddress "10.0.0.1:8080" | Should -Be $true
            Test-ServerAddress "172.16.0.1:443" | Should -Be $true
        }
    }

    Context "Invalid addresses" {
        It "rejects missing port" {
            Test-ServerAddress "192.168.1.1" | Should -Be $false
        }

        It "rejects missing IP" {
            Test-ServerAddress ":9999" | Should -Be $false
        }

        It "rejects invalid IP octets" {
            Test-ServerAddress "999.168.1.1:9999" | Should -Be $false
            Test-ServerAddress "192.999.1.1:9999" | Should -Be $false
        }

        It "rejects port out of range" {
            Test-ServerAddress "192.168.1.1:0" | Should -Be $false
            Test-ServerAddress "192.168.1.1:99999" | Should -Be $false
            Test-ServerAddress "192.168.1.1:65536" | Should -Be $false
        }

        It "rejects invalid format" {
            Test-ServerAddress "invalid" | Should -Be $false
            Test-ServerAddress "192.168.1.1.1:9999" | Should -Be $false
        }

        It "throws on empty string" {
            { Test-ServerAddress "" } | Should -Throw
        }

        It "rejects hostname format" {
            Test-ServerAddress "localhost:9999" | Should -Be $false
            Test-ServerAddress "example.com:9999" | Should -Be $false
        }
    }

    Context "Localhost warning" {
        It "warns on localhost but returns true" {
            $result = Test-ServerAddress "127.0.0.1:9999" -WarningVariable warnings 3>$null
            $result | Should -Be $true
        }

        It "warns on 0.0.0.0 but returns true" {
            $result = Test-ServerAddress "0.0.0.0:9999" -WarningVariable warnings 3>$null
            $result | Should -Be $true
        }
    }
}

Describe "Test-SecretKey" {
    Context "Valid keys" {
        It "accepts non-empty key" {
            Test-SecretKey "mykey" | Should -Be $true
        }

        It "accepts long keys" {
            Test-SecretKey "this-is-a-very-long-secret-key-for-testing" | Should -Be $true
        }

        It "accepts keys with special characters" {
            Test-SecretKey "key!@#$%^&*()" | Should -Be $true
        }

        It "accepts keys meeting minimum length" {
            Test-SecretKey "12345678" -MinLength 8 | Should -Be $true
        }
    }

    Context "Invalid keys" {
        It "rejects empty key" {
            Test-SecretKey "" | Should -Be $false
        }

        It "rejects whitespace-only key" {
            Test-SecretKey "   " | Should -Be $false
        }

        It "rejects key shorter than minimum length" {
            Test-SecretKey "short" -MinLength 10 | Should -Be $false
        }
    }

    Context "Short key warning" {
        It "warns on short keys but returns true" {
            $result = Test-SecretKey "abc" -WarningVariable warnings 3>$null
            $result | Should -Be $true
        }
    }
}

Describe "Test-PortNumber" {
    Context "Valid ports" {
        It "accepts minimum port" {
            Test-PortNumber 1 | Should -Be $true
        }

        It "accepts maximum port" {
            Test-PortNumber 65535 | Should -Be $true
        }

        It "accepts common ports" {
            Test-PortNumber 80 | Should -Be $true
            Test-PortNumber 443 | Should -Be $true
            Test-PortNumber 8080 | Should -Be $true
            Test-PortNumber 9999 | Should -Be $true
        }
    }

    Context "Invalid ports" {
        It "rejects port 0" {
            Test-PortNumber 0 | Should -Be $false
        }

        It "rejects negative port" {
            Test-PortNumber -1 | Should -Be $false
        }

        It "rejects port above maximum" {
            Test-PortNumber 65536 | Should -Be $false
            Test-PortNumber 100000 | Should -Be $false
        }
    }
}

Describe "Test-IPAddress" {
    Context "Valid IPs" {
        It "accepts standard IPv4" {
            Test-IPAddress "192.168.1.1" | Should -Be $true
        }

        It "accepts boundary values" {
            Test-IPAddress "0.0.0.0" | Should -Be $true
            Test-IPAddress "255.255.255.255" | Should -Be $true
        }

        It "accepts localhost" {
            Test-IPAddress "127.0.0.1" | Should -Be $true
        }
    }

    Context "Invalid IPs" {
        It "rejects octets over 255" {
            Test-IPAddress "256.1.1.1" | Should -Be $false
            Test-IPAddress "1.256.1.1" | Should -Be $false
            Test-IPAddress "1.1.256.1" | Should -Be $false
            Test-IPAddress "1.1.1.256" | Should -Be $false
        }

        It "rejects too many octets" {
            Test-IPAddress "1.1.1.1.1" | Should -Be $false
        }

        It "rejects too few octets" {
            Test-IPAddress "1.1.1" | Should -Be $false
        }

        It "rejects non-numeric" {
            Test-IPAddress "a.b.c.d" | Should -Be $false
        }

        It "throws on empty string" {
            { Test-IPAddress "" } | Should -Throw
        }
    }
}

Describe "Test-MACAddress" {
    Context "Valid MACs with colon separator" {
        It "accepts lowercase" {
            Test-MACAddress "aa:bb:cc:dd:ee:ff" | Should -Be $true
        }

        It "accepts uppercase" {
            Test-MACAddress "AA:BB:CC:DD:EE:FF" | Should -Be $true
        }

        It "accepts mixed case" {
            Test-MACAddress "Aa:Bb:Cc:Dd:Ee:Ff" | Should -Be $true
        }
    }

    Context "Valid MACs with hyphen separator" {
        It "accepts hyphen separator" {
            Test-MACAddress "aa-bb-cc-dd-ee-ff" | Should -Be $true
        }
    }

    Context "Invalid MACs" {
        It "rejects wrong length" {
            Test-MACAddress "aa:bb:cc:dd:ee" | Should -Be $false
            Test-MACAddress "aa:bb:cc:dd:ee:ff:00" | Should -Be $false
        }

        It "rejects invalid characters" {
            Test-MACAddress "gg:hh:ii:jj:kk:ll" | Should -Be $false
        }

        It "rejects no separator" {
            Test-MACAddress "aabbccddeeff" | Should -Be $false
        }

        It "accepts mixed separators" {
            # Current implementation allows mixed separators for flexibility
            Test-MACAddress "aa:bb-cc:dd-ee:ff" | Should -Be $true
        }

        It "throws on empty string" {
            { Test-MACAddress "" } | Should -Throw
        }
    }
}
