. "$PSScriptRoot/yana.ps1"

function YANAtest:Get-YanaValue {
  $o = @{
    a = 1
    b = @(1, 2, 3)
    c = @{
      a = 'a'
      b = @(
        'a',
        @(1),
        @{
          a = 'a'
          b = 'b'
          c = @{
            a = 'a'
            b = 'b'
            c = 'c'
          }
        },
        @(
          'q',
          @(
            'x',
            'y',
            @(
              'z',
              @(
                'w'
              )
            )
          )
        )
      )
    }
  }
  # pass (Get-YanaValue $o '' | convertto-json -Compress -Depth 10)
  # pass (Get-YanaValue $o '....' | convertto-json -Compress -Depth 10)
  pass (Get-YanaValue $o 'b' | convertto-json -Compress)
  pass (Get-YanaValue $o 'b[1]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'b.[1]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c' | convertto-json -Compress -Depth 5)
  pass (Get-YanaValue $o 'c.a' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[0]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[1]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[1][0]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[1].[0]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b.[1].[0]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[2]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[3][1].[2][1]' | convertto-json -Compress)
  pass (Get-YanaValue $o 'c.b[2].c.c' | convertto-json -Compress)
}

$YANA_rsa_key = [System.Security.Cryptography.RSACryptoServiceProvider]::new(2048)

function YANA:Encrypt([string]$PlainText) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
  $encryptedBytes = $YANA_rsa_key.Encrypt($bytes, $true)
  $encryptedStr = [Convert]::ToBase64String($encryptedBytes)
  "<YANAencrypted:$encryptedStr>"
}
function YANA:Decrypt([string]$EncryptedString) {
  $output = $EncryptedString
  foreach ($m in [regex]::Matches($EncryptedString, '<YANAencrypted:(?<base64>[A-Za-z0-9+/=]+)>')) {
    $secret = $m.Value
    $base64 = $m.Groups['base64'].Value
    $decrypted = $null
    try {
      $encryptedBytes = [Convert]::FromBase64String($base64)
      $decryptedBytes = $YANA_rsa_key.Decrypt($encryptedBytes, $true)
      $decrypted = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
      $output = $output.Replace($secret, $decrypted)
    } catch {
      Write-Host "Decryption failed: $($_.Exception.Message)" -ForegroundColor Red
    }
  }
  return $output
}


function YANAtest:Encrypt_Decrypt {
  $testStrings = 'This is a test string for encryption and decryption.' -split ' '
  pass "Original string: $testStrings"
  $encrypted = ($testStrings | ForEach-Object { YANA:Encrypt $_ }) -join ' '
  pass "Encrypted string: $encrypted"
  $decrypted = YANA:Decrypt $encrypted
  pass "Decrypted string: $decrypted"
  if ($decrypted -eq ($testStrings -join ' ')) {
    pass 'Encryption and decryption successful.'
  } else {
    fail 'Decrypted string does not match the original.'
  }
}
