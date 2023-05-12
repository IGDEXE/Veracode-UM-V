param (
    [parameter(position = 0, Mandatory = $True, HelpMessage = "Email da conta conforme cadastrado na Veracode (Caso seja uma conta de API, informar o UserName dela)")]
    $emailUsuario,
    [parameter(position = 1, Mandatory = $True, HelpMessage = "Tipo de roles desejado (ex: QA, SOC, Desenvolvedor)")]
    $tipoFuncionario,
    [parameter(position = 2, HelpMessage = "Caminho da pasta de templates")]
    $pastaTemplates = ".\Templates"
)

# Lista de funcoes:
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
function Get-VeracodeUserID {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Email da conta conforme cadastrado na Veracode (Caso seja uma conta de API, informar o UserName dela)")]
        $emailUsuario
    )
    try {
        $infoUsers = http --auth-type=veracode_hmac GET "https://api.veracode.com/api/authn/v2/users?size=1000" | ConvertFrom-Json
        $validador = Debug-VeracodeAPI $infoUsers
        if ($validador -eq "OK") {
            $infoUsers = $infoUsers._embedded.users
            $userID = ($infoUsers | Where-Object { $_.user_name -eq "$emailUsuario" }).user_id
            if ($userID) {
                return $userID
            } else {
                # Exibe a mensagem de erro
                Write-Error "Não foi encontrado ID para o usuario: $emailUsuario"
            }
            
        } else {
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
function Get-VeracodeRoles {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Nome do cargo conforme estabelecido no template")]
        $tipoFuncionario,
        [parameter(position=1,HelpMessage="Caminho da pasta de templates")]
        $pastaTemplates = ".\Templates"
    )

    try {
        # Valida as roles pelo cargo
        switch ($tipoFuncionario) {
            Desenvolvedor { $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesDev; Break }
            QA { $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesQa; Break }
            SOC { $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesSoc; Break }
            DEVOPS { $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesSRE; Break }
            BLUETEAM { $roles = (Get-Content $pastaTemplates\exemploRoles.json | ConvertFrom-Json).rolesBlueTeam; Break }
            Default { Write-Error "Não foi encontrado nenhum perfil para $tipoFuncionario"}
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

# Dont work
function Get-UserRoles {
    param (
        [parameter(position=0,Mandatory=$True,HelpMessage="Email da conta conforme cadastrado na Veracode (Caso seja uma conta de API, informar o UserName dela)")]
        $emailUsuario
    )
    try {
        $infoUsers = http --auth-type=veracode_hmac GET "https://api.veracode.com/api/authn/v2/users?size=1000" | ConvertFrom-Json
        $validador = Debug-VeracodeAPI $infoUsers
        if ($validador -eq "OK") {
            $infoUsers = $infoUsers._embedded.users
            $userInfo = ($infoUsers | Where-Object { $_.user_name -eq "$emailUsuario" })
            if ($userInfo) {
                $nome = $userInfo.first_name
                $sobrenome = $userInfo.last_name
                $email = $userInfo.email_address
                $infoUsuarios = "$nome $sobrenome`n$email"
                return $infoUsuarios
            } else {
                # Exibe a mensagem de erro
                Write-Error "Não foi encontrado ID para o usuario: $emailUsuario"
            }
            
        } else {
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

try {
    # Recebe o ID do usuario e as roles
    $idUsuario = Get-VeracodeUserID $emailUsuario
    $roles = Get-VeracodeRoles $tipoFuncionario

    # Atualiza as roles com base no modelo
    $infoUser = Get-Content "$pastaTemplates\extruturaRoles.json" | ConvertFrom-Json
    $infoUser.roles = $roles

    # Salva num novo JSON
    $novoJSON = "roles" + (Get-Date -Format sshhmmddMM) + ".json"
    $caminhoJSON = "./TEMP/$novoJSON"
    $infoUser | ConvertTo-Json -depth 100 | Out-File "$caminhoJSON"

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
            Write-Host "Novas Roles: $roles"
            Write-Host "$data"
        } else {
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