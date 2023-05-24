param (
    [parameter(position = 0, Mandatory = $True, HelpMessage = "Email da conta conforme cadastrado na Veracode (Caso seja uma conta de API, informar o UserName dela)")]
    $emailUsuario,
    [parameter(position = 1, Mandatory = $True, HelpMessage = "Nome da role conforme tabela")]
    $novaRole,
    [parameter(position = 2, HelpMessage = "Caminho da pasta de templates")]
    $pastaTemplates = ".\Templates"
)

function Get-UserRoles {
    param (
        [parameter(position = 0, Mandatory = $True, HelpMessage = "Email da conta conforme cadastrado na Veracode (Caso seja uma conta de API, informar o UserName dela)")]
        $emailUsuario
    )
    try {
        $infoUsers = http --auth-type=veracode_hmac GET "https://api.veracode.com/api/authn/v2/users/self?user_name=$emailUsuario" | ConvertFrom-Json
        $validador = Debug-VeracodeAPI $infoUsers
        if ($validador -eq "OK") {
            $userRoles = $infoUsers.roles
            if ($userRoles) {
                $listaRoles = $userRoles.role_name
                return $listaRoles
            }
            else {
                # Exibe a mensagem de erro
                Write-Error "Não foram encontradas roles para o usuario: $emailUsuario"
            }
            
        }
        else {
            # Exibe a mensagem de erro
            Write-Error "Algo não esperado ocorreu"
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Erro no Powershell:"
        Write-Host "$ErrorMessage"
    }
}
function Debug-VeracodeAPI {
    param (
        [parameter(position = 0, Mandatory = $True, HelpMessage = "Retorno da API que quer analisar")]
        $retornoAPI
    )

    try {
        # Filtra a resposta
        $status = $retornoAPI.http_status
        $mensagem = $retornoAPI.message
        $codigoErro = $retornoAPI.http_code

        if ($status) {
            Write-Host "Ocorreu um erro:"
            Write-Host $mensagem
            Write-Error $codigoErro
        }
        elseif (!$retornoAPI) {
            Write-Host "Ocorreu um erro:"
            Write-Error "A API não retornou nenhum dado"
        }
        else {
            $validador = "OK"
            return $validador
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Erro no Powershell:"
        Write-Host "$ErrorMessage"
    }
}

# Recebe as roles antigas
$rolesAntigas = Get-UserRoles $emailUsuario

# Atualiza a lista de roles
$listaRoles = $rolesAntigas + $novaRole

# Gera a lista com as roles
foreach ($role in $listaRoles) {
    Write-Host "$role"
    $roles += @"
,
    {
        "role_name": "$role"
    }
"@
}

# Atualiza o modelo
$modeloRoles = @"
{ "roles":[
    {
      "role_name": "securityinsightsonly"
    }$roles
  ]
}
"@

try {
    # Salva num novo JSON
    $novoJSON = "roles" + (Get-Date -Format sshhmmddMM) + ".json"
    $caminhoJSON = "./TEMP/$novoJSON"
    $modeloRoles | ConvertTo-Json -depth 100 | Out-File "$caminhoJSON"

    # Inicia o LOG
    $hashData = Get-Date -Format "ddMMyyyy-HHmmss"
    $caminhoLOG = ".\LOGs\" + $hashData + "_UpdateRoles.log"
    Start-Transcript -Path "$caminhoLOG" -NoClobber -UseMinimalHeader

    # Atualiza as roles
    $urlAPI = "https://api.veracode.com/api/authn/v2/users/" + $idUsuario + "?partial=true"
    $retornoAPI = Get-Content $caminhoJSON | http --auth-type=veracode_hmac PUT "$urlAPI" | ConvertFrom-Json
    $validador = Debug-VeracodeAPI $retornoAPI
    if ($validador -eq "OK") {
        # Gera os dados para os LOGs
        $Usuario = $retornoAPI.user_name
        $nome = $retornoAPI.first_name
        $sobrenome = $retornoAPI.last_name
        $data = Get-Date -Format "HH:mm dd/MM/yyyy"
        if ($Usuario) {
            Write-Host "Usuario foi atualizado:"
            Write-Host "$nome $sobrenome"
            Write-Host "$Usuario"
            Write-Host "Roles antigas: $rolesAntigas"
            Write-Host "Novas Roles: $roles"
            Write-Host "$data"
        }
        else {
            Write-Error "Não foi localizado nenhum ID para: $emailUsuario"
        }      
    }
    else {
        Write-Error "Comportamento não esperado"
    }
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "Erro no Powershell:"
    Write-Error "$ErrorMessage"
}
Stop-Transcript