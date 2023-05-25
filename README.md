# Veracode-UM
 Projeto para gerenciamento de usuários utilizando as novas APIs da Veracode

# Antes de usar:
Instale os componentes que a Veracode precisa para utilizar:<br>
pip install httpie<br>
pip install veracode-api-signing<br>

# Lista de scripts implementados:
NewUser:<br>
    Criar novos usuários com base num arquivo CSV (Template dele disponível em: Templates\template.csv)<br>
    Parâmetros -> Caminho do arquivo CSV<br>
BlockUser:<br>
    Bloqueia o usuário com base no email<br>
    Parâmetros -> Email do usuário alvo<br>
UpdateRoles:<br>
    Atualiza as roles de um usuário com base num cargo<br>
    Parâmetros -> Email do usuário alvo<br>
DeleteUser:<br>
    Deleta o usuário com base no email<br>
    Parâmetros -> Email do usuário alvo<br>
listTeams:<br>
    Lista todos os times<br>
    Parâmetros -> Nenhum<br>

# Material de apoio:
O arquivo precisa ser criado conforme o template, informando em ordem conforme as colunas<br>
Caso seja colocado "Sim" na coluna de novo time, vai ser executado o processo de validar se ele já existe e em caso negativo, será feito a criação<br>
Qualquer outro texto será considerado como "Não"<br>

# Como usar?
Faça a instalação das dependências em seu sistema<br>
Utilize o script para sua necessidade conforme seus parâmetros obrigatórios<br>
Pode consultar os resultados em seu terminal ou na pasta de LOGs<br>

# Como usar no Linux?
Recomendo que consulte a documentação para verificar todos os detalhes:<br>
https://learn.microsoft.com/pt-br/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3<br>
Esse projeto foi testado no Ubuntu 22.04.1 LTS<br>
Depois da instalação do Powershell on Linux, basta utilizar sem nenhuma alteração<br>

# Em implementação:
Atualização de roles especificas/únicas<br>
LOG de roles antigas no script de atualização de roles<br>