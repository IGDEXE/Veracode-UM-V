param (
    [parameter(position=0,Mandatory=$True,HelpMessage="Caminho do arquivo CSV com os dados para criar um novo usuario")]
    $caminhoCSV
)

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
function New-UserJson {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Nome do usuario")]
        $nome,
        [parameter(position=1,Mandatory=$True,HelpMessage="Sobrenome do usuario")]
        $sobrenome,
        [parameter(position=2,Mandatory=$True,HelpMessage="Email do usuario")]
        $email,
        [parameter(position=3,Mandatory=$True,HelpMessage="Cargo do usuario")]
        $cargo,
        [parameter(position=4,Mandatory=$True,HelpMessage="Equipe do usuario")]
        $time,
        [parameter(position=5,HelpMessage="Caminho para os templates")]
        $pastaTemplates = ".\Templates"
    )

    try {
        # Recebe as informações do template
        $infoUser = Get-Content $pastaTemplates\newUser.json | ConvertFrom-Json
    
        # Valida as roles pelo cargo
        $roles = Get-VeracodeRoles $cargo
    
        # Pega o ID do time
        $timeID = Get-VeracodeTeamID $time
        $timeTemplate = Get-Content $pastaTemplates\exemploTimes.json
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
        $caminhoJSON = "./TEMP/$novoJSON"
        $infoUser | ConvertTo-Json -depth 100 | Out-File "$caminhoJSON"
        return $caminhoJSON
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Erro no Powershell:"
        Write-Error "$ErrorMessage"
    }
}
function Get-VeracodeTeamsList {
    try {
        $infoTeam = http --auth-type=veracode_hmac GET "https://api.veracode.com/api/authn/v2/teams?all_for_org=true&size=1000" | ConvertFrom-Json
        $validador = Debug-VeracodeAPI $infoTeam
        if ($validador -eq "OK") {
            $teamList = $infoTeam._embedded.teams.team_name
            if ($teamList) {
                return $teamList
            } else {
                # Exibe a mensagem de erro
                Write-Error "Não foram encontrados times"
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
function New-VeracodeTeam {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Nome da equipe")]
        $teamName,
        [parameter(position=1,HelpMessage="Caminho da pasta de templates")]
        $pastaTemplates = ".\Templates"
    )

    try {
        # Valida se o time já existe
        $listaTimes = Get-VeracodeTeamsList
        if ($listaTimes.Contains($teamName)) {
            Write-Host "O time $teamName já existe"
        } else {
            # Recebe as informações do template
            $timeTemplate = Get-Content $pastaTemplates\newTeam.json | ConvertFrom-Json
        
            # Altera as propriedades
            $timeTemplate.team_name = $teamName
        
            # Salva num novo JSON
            $novoJSON = "team" + (Get-Date -Format sshhmmddMM) + ".json"
            $caminhoJSON = "./TEMP/$novoJSON"
            $timeTemplate | ConvertTo-Json -depth 100 | Out-File "$caminhoJSON"
            
            # Cria o time 
            $retornoAPI = Get-Content $caminhoJSON | http --auth-type=veracode_hmac POST "https://api.veracode.com/api/authn/v2/teams"
            $retornoAPI = $retornoAPI | ConvertFrom-Json
            $validador = Debug-VeracodeAPI $retornoAPI

            # Valida se fez a criação
            if ($validador -eq "OK") {
                # Pega as infos do usuario
                $nomeTime = $retornoAPI.team_name
                $idTime = $retornoAPI.team_id
                # Exibe a mensagem de confirmação
                Write-Host "Time criado com sucesso:"
                Write-Host "$nomeTime"
                Write-Host "$idTime"
            } else {
                # Exibe a mensagem de erro
                Write-Error "Algo não esperado ocorreu"
            }
        }
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Erro no Powershell:"
        Write-Error "$ErrorMessage"
    }
}
function Get-VeracodeRoles {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Nome do cargo conforme estabelecido no template")]
        $tipoFuncionario,
        [parameter(position=1,HelpMessage="Caminho da pasta de templates")]
        $pastaTemplates = ".\Templates"
    )

    try {
        # Valida as roles pelo cargo
        if ($tipoFuncionario -eq "Desenvolvedor") {
            $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesDev
        } elseif ($tipoFuncionario -eq "QA") {
            $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesQa
        } elseif ($tipoFuncionario -eq "SOC") {
            $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesSoc
        } elseif ($tipoFuncionario -eq "DEVOPS") {
            $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesSRE
        } elseif ($tipoFuncionario -eq "BLUETEAM") {
            $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesBlueTeam
        } else {
            Write-Error "Não foi encontrado nenhum perfil para $tipoFuncionario"
        }

        # Retorna as roles
        return $roles
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "Erro no Powershell:"
        Write-Error "$ErrorMessage"
    }   
}

# Faz a criação do usuario
try {
    # Inicia o LOG
    $hashData = Get-Date -Format "ddMMyyyy-HHmmss"
    $caminhoLOG = ".\LOGs\" + $hashData + "_NovoUsuario.log"
    Start-Transcript -Path "$caminhoLOG" -NoClobber -UseMinimalHeader

    # Recebe as informacoes do CSV
    $Header = "Nome", "Sobrenome", "Email", "Cargo", "Time", "NovoTime"
    $infoUsuario = Get-Content -Path "$caminhoCSV" | Select-Object -Skip 1 | ConvertFrom-Csv -Header $Header -Delimiter ";"
    $nome = $infoUsuario.Nome
    $sobrenome = $infoUsuario.Sobrenome
    $email = $infoUsuario.Email
    $cargo = $infoUsuario.Cargo
    $time = $infoUsuario.Time
    $novoTime = $infoUsuario.NovoTime

    # Valida se precisa de um novo time
    if ($novoTime -eq "Sim") {
        New-VeracodeTeam "$time"
    }

    # Recebe as informações do JSON
    $caminhoJSON = New-UserJson $nome $sobrenome $email $cargo $time
    $infoJSON = Get-Content "$caminhoJSON" | ConvertFrom-Json
    $roles = $infoJSON.roles.role_name

    # Faz a chamada da API
    $retornoAPI = Get-Content $caminhoJSON | http --auth-type=veracode_hmac POST "https://api.veracode.com/api/authn/v2/users"
    $retornoAPI = $retornoAPI | ConvertFrom-Json
    $validador = Debug-VeracodeAPI $retornoAPI

    # Valida se fez a criação
    if ($validador -eq "OK") {
       # Pega as infos do usuario
       $nomeUsuario = $retornoAPI.first_name
       $sobrenomeUsuario = $retornoAPI.last_name
       $emailUsuario = $retornoAPI.email_address
       # Exibe a mensagem de confirmação
       Write-Host "Usuario criado com sucesso:"
       Write-Host "$nomeUsuario $sobrenomeUsuario"
       Write-Host "$emailUsuario"
       Write-Host "Roles: $roles"
       Write-Host "Time: $time"
       Get-Date -Format "HH:mm dd/MM/yyyy"
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
Stop-Transcript