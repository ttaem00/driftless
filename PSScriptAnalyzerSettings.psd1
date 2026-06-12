@{
  Severity = @('Error', 'Warning')

  # Keep this focused: useful shell-contract checks without turning existing
  # large scripts into a noisy migration project.
  IncludeRules = @(
    'PSAvoidUsingCmdletAliases',
    'PSAvoidUsingInvokeExpression',
    'PSAvoidUsingPlainTextForPassword',
    'PSAvoidUsingConvertToSecureStringWithPlainText',
    'PSUseApprovedVerbs',
    'PSUseShouldProcessForStateChangingFunctions'
  )

  Rules = @{
    PSAvoidUsingCmdletAliases = @{
      Enable = $true
    }
    PSAvoidUsingInvokeExpression = @{
      Enable = $true
    }
    PSAvoidUsingPlainTextForPassword = @{
      Enable = $true
    }
    PSAvoidUsingConvertToSecureStringWithPlainText = @{
      Enable = $true
    }
    PSUseApprovedVerbs = @{
      Enable = $true
    }
    PSUseShouldProcessForStateChangingFunctions = @{
      Enable = $true
    }
  }
}
