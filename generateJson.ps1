param (
        $nome,
        $sobrenome,
        $email,
        $cargo,
        $time,
        $pastaTemplates = ".\Templates"
    )

# Lista de funcoes
function Get-VeracodeTeamID {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Nome do time cadastrado na plataforma da Veracode")]
        $teamName
    )

    try {
        $infoTeam = http --auth-type=veracode_hmac GET "https://api.veracode.com/api/authn/v2/teams?all_for_org=true&size=1000" | ConvertFrom-Json
        $validador = Debug-VeracodeAPI $infoTeam
        if ($validador -eq "OK") {
            $infoTeam = $infoTeam._embedded.teams
            $teamID = ($infoTeam | Where-Object { $_.team_name -eq "$teamName" }).team_id
            if ($teamID) {
                return $teamID
            } else {
                # Exibe a mensagem de erro
                Write-Error "Não foi encontrado ID para o Time: $teamName"
            }
            
        } else {
            # Exibe a mensagem de erro
            Write-Error "Algo não esperado ocorreu"
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Erro no Powershell:"
        Write-Error "$ErrorMessage"
    }  
}

function Debug-VeracodeAPI {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Retorno da API que quer analisar")]
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
        } elseif (!$retornoAPI) {
            Write-Host "Ocorreu um erro:"
            Write-Error "A API não retornou nenhum dado"
        } else {
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

try {
    # Recebe as informações do template
    $infoUser = Get-Content $pastaTemplates\newUser.json | ConvertFrom-Json

    # Valida as roles pelo cargo
    if ($cargo -eq "Desenvolvedor") {
        $roles = (Get-Content .\Templates\exemploRoles.json | ConvertFrom-Json).rolesDev
    } if ($cargo -eq "gestor") {
        $roles = (Get-Content .\Templates\exemploRoles.json | ConvertFrom-Json).rolesManager
    }

    # Pega o ID do time
    $timeID = Get-VeracodeTeamID $time
    $timeTemplate = Get-Content .\Templates\exemploTimes.json
    $time = $timeTemplate.replace("#TIMEID#", "$timeID")
    $time = ($time | ConvertFrom-Json).teams

    # Altera as propriedades
    $infoUser.email_address = $email
    $infoUser.user_name = $email
    $infoUser.first_name = $nome
    $infoUser.last_name = $sobrenome
    $infoUser.title = $cargo
    $infoUser.roles = $roles
    $infoUser.teams = $time

    # Salva num novo JSON
    $novoJSON = "user" + (Get-Date -Format sshhmmddMM) + ".json"
    $infoUser | ConvertTo-Json -depth 100 | Out-File "$novoJSON"
    return $novoJSON
}
catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "Erro no Powershell:"
    Write-Host "$ErrorMessage"
}