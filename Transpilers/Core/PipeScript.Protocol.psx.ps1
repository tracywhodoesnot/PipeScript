<#
.SYNOPSIS
    Core Protocol Transpiler
.DESCRIPTION
    Enables the transpilation of protocols.

    ```https://api.github.com/repos/StartAutomating/PipeScript/issues``` is a valid command.

    So is ```get https://api.github.com/repos/StartAutomating/PipeScript/issues```.
    
    So is ```MyCustomProtocol:// -Parameter value```.

    This transpiler enables commands in protocol format to be transpiled.
.NOTES
    This transpiler will match any command whose first or second element contains ```://```
.EXAMPLE
    .> -ScriptBlock {
        https://api.github.com/users/StartAutomating
    }
.EXAMPLE
    .> -ScriptBlock {
        $userName = 'StartAutomating'
        https://$GitHubApi/users/$UserName
    }
.EXAMPLE
    .> -ScriptBlock {
        $env:GitUserName = 'StartAutomating'
        https://api.github.com/users/$env:GitUserName
    }
#>
[ValidateScript({
    $commandAst = $_
    if ($commandAst.CommandElements -and 
        $commandAst.CommandElements[0] -match '://') {
        return $true
    }
    if ($commandAst.CommandElements.Count -ge 2 -and 
        $commandAst.CommandElements[1] -match '://') {
        return $true
    }
    return $false
})]
param(
# The Command Abstract Syntax Tree.
[Parameter(Mandatory,ValueFromPipeline)]
[Management.Automation.Language.CommandAst]
$CommandAst
)

process {    
    [string]$CommandMethod = ''
    [string]$commandName   =
        if ($CommandAst.CommandElements[0].Value -match '://') {
            $CommandAst.CommandElements[0].Value
        } 
        else
        {
            $commandMethod =  $CommandAst.CommandElements[0].Value
            $CommandAst.CommandElements[1].Value
        }
    
    $commandUri  =
        if ($commandName -as [uri]) {
            $commandName -as [uri]
        }
        else {
            $commandName -replace '\$(.+)\:','$1__' -replace '\$','__' -as [uri]
        }

    $commandAstSplat = @{
        CommandAST = $commandAst        
    }
    
    if ($commandMethod) {
        $commandAstSplat.Method = $commandMethod
    }

    $foundTranspiler = 
        Get-Transpiler -CouldPipe $commandUri -ValidateInput $CommandAst -CouldRun -Parameter $commandAstSplat

    if (-not $foundTranspiler) {
        Write-Error "Could not find a transpiler for $commandAst"
        return
    }

    foreach ($found in $foundTranspiler) {
        $params = $found.ExtensionParameter
        $transpilerOutput = & $found.ExtensionCommand @params
        if ($transpilerOutput) { $transpilerOutput; break }
    }    
}
