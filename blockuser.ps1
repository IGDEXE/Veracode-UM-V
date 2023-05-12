param (
    [parameter(position=0,Mandatory=$True,HelpMessage="Email do usuario")]
    $emailUsuario,
    [parameter(position=1,HelpMessage="Caminho para o template JSON")]
    $caminhoJSON = ".\Templates\block.json"
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

try {
    # Recebe o ID com base no nome
    $idUsuario = Get-VeracodeUserID $emailUsuario
    
    # Faz o bloqueio
    $urlAPI = "https://api.veracode.com/api/authn/v2/users/" + $idUsuario + "?partial=true"
    $retornoAPI = Get-Content $caminhoJSON | http --auth-type=veracode_hmac PUT "$urlAPI" | ConvertFrom-Json

    # Inicia o LOG
    $hashData = Get-Date -Format "ddMMyyyy-HHmmss"
    $caminhoLOG = ".\LOGs\" + $hashData + "_Block.log"
    Start-Transcript -Path "$caminhoLOG" -NoClobber -UseMinimalHeader

    $validador = Debug-VeracodeAPI $retornoAPI
    if ($validador -eq "OK") {
        # Gera os dados para os LOGs
        $Usuario = $retornoAPI.user_name
        $nome = $retornoAPI.first_name
        $sobrenome = $retornoAPI.last_name
        $data = Get-Date -Format "HH:mm dd/MM/yyyy"
        if ($Usuario) {
            Write-Host "Usuario foi bloqueado:"
            Write-Host "$nome $sobrenome"
            Write-Host "$Usuario"
            Write-Host "$data"
        } else {
            Write-Error "Não foi localizado nenhum ID para: $emailUsuario"
        }
        
    } else {
        Write-Error "Comportamento não esperado"
    }
} catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "Erro no Powershell:"
    Write-Host "$ErrorMessage"
}