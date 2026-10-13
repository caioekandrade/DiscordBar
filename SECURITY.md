# Segurança

## Escopo

A versão 1.0 usa a permissão de Acessibilidade para localizar o Discord no
Dock e consultar seu indicador. O macOS não restringe essa permissão
somente a esse item: um código malicioso executado com essa autorização
poderia abusar de acesso à interface de outros aplicativos.

O código atual não contém rede, servidor local, carregamento de plugins,
execução de comandos no aplicativo, coleta de credenciais ou atualizador.
Os comandos de compilação e empacotamento existem somente nos scripts
executados pelo desenvolvedor. Não há dependências externas de runtime.

Essa descrição não é uma garantia de ausência de vulnerabilidades. Esta
versão recebeu uma revisão manual básica, sem auditoria independente.
Nenhuma versão futura herda automaticamente essa avaliação.

## Origem dos binários

As primeiras compilações têm assinatura local ad hoc, sem notarização.
Checksums SHA-256 ajudam a conferir integridade, mas não provam autoria
se o atacante também puder substituir o checksum. Para distribuição
pública, recomenda-se Developer ID, notarização e proteção da conta
responsável pelas releases.

## Relatar problemas

Use [Private vulnerability reporting](https://github.com/caioekandrade/DiscordBar/security/advisories/new)
na seção Security do GitHub para relatos que permitam exploração. Não publique uma demonstração
de exploração em uma issue pública antes de coordenar a correção.

Não envie tokens do Discord, credenciais, chaves de assinatura ou dados de
conversas. Inclua versão do app, macOS, arquitetura e passos de reprodução
com dados fictícios.

## Manutenção e distribuição

- Revise contribuições antes de criar uma release, especialmente mudanças
  em Acessibilidade, rede, execução de código e mecanismos de atualização.
- Habilite autenticação de dois fatores, proteção da branch principal,
  secret scanning e push protection na conta/repositório.
- Nunca publique certificados com chave privada, arquivos .p12, tokens
  de acesso ou credenciais usadas para notarização.
- Caso adicione CI, use permissões mínimas; não exponha secrets a builds
  vindos de forks. Revise e fixe versões de ações externas.
