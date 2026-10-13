# DiscordBar

Aplicativo pequeno para macOS que mostra o indicador de notificações do Discord
na barra de menus. Implementado em Swift com os frameworks nativos da Apple.

[Baixar DMG para Apple Silicon](https://github.com/caioekandrade/DiscordBar/releases/download/v1.0.0/DiscordBar-1.0-arm64.dmg)
· [Releases e checksums](https://github.com/caioekandrade/DiscordBar/releases)

## Recursos

- Espelha a bolinha ou a contagem que o Discord mostra no Dock.
- Clique normal abre o Discord; clique direito abre as opções.
- Atenua o ícone quando não há notificações.
- Início com o Mac, controlado pelo menu, sem janela de abertura.
- Sem serviços externos, telemetria ou dependências de terceiros.

## Requisitos

macOS 13 ou posterior, Discord para desktop e permissão de Acessibilidade.
O binário 1.0 entregue inicialmente é para Apple Silicon (arm64).
O script de compilação usa a arquitetura do Mac que o executa; outras
arquiteturas não foram verificadas nesta versão.

## Instalação

Abra o DMG, arraste **DiscordBar.app** para **Applications** e abra o app
em Aplicativos. Em Ajustes do Sistema → Privacidade e Segurança →
Acessibilidade, habilite DiscordBar. Se necessário, use **+** para adicionar
o aplicativo instalado. Depois de mudar a permissão, pode ser necessário
sair pelo menu e abrir novamente.

A primeira abertura solicita a permissão e registra o início com o Mac.
Esse início pode exigir aprovação em Geral → Itens de Início e Extensões.
Para desativá-lo, use o menu com o clique direito.

**Distribuição atual:** assinatura local ad hoc, sem certificado Developer ID
e sem notarização Apple. Um download pela internet pode ser bloqueado pelo
Gatekeeper. O DMG é apenas uma embalagem; não concede confiança ao binário.
Também é possível compilar localmente a partir do código.

## Como funciona e privacidade

O app localiza o item do Discord no Dock usando a API de Acessibilidade e lê
o atributo `AXStatusLabel` a cada dois segundos. Isso funciona com o Dock
oculto. O Discord precisa estar aberto e com seu indicador de mensagens
não lidas habilitado. O app não calcula uma contagem própria.

O código não lê conversas, não solicita login nem token do Discord e não
implementa comunicação de rede, captura de tela, monitoramento do teclado,
servidor local ou atualização automática. As preferências são locais.

A permissão de Acessibilidade é mais ampla do que a função deste aplicativo.
Conceda-a somente a uma versão cuja origem você confia. Consulte [SECURITY.md](SECURITY.md).

## Compilar

Requer as Command Line Tools da Apple (`xcode-select --install`).

```sh
bash build.sh
open build/DiscordBar.app
```

Instale o app em Aplicativos antes de conceder a permissão ou ativar o início
automático. Recompilar com assinatura local pode exigir nova autorização.

## Criar o DMG

```sh
bash build.sh
bash package-dmg.sh build/DiscordBar.app dist/DiscordBar-1.0.dmg
shasum -a 256 dist/DiscordBar-1.0.dmg
```

O DMG contém o app, um atalho para Applications e as instruções de uso.
Para uma distribuição pública com menos barreiras de instalação, assine
com Developer ID e envie à notarização antes de publicar a release:
[documentação Apple](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Limites da versão 1.0

A leitura depende dos atributos expostos pelo Dock, que podem mudar com o
macOS. Bolinha laranja indica falta de permissão ou leitura indisponível;
ícone atenuado indica nenhuma notificação ou Discord fechado. O número é
limitado visualmente a 99+. Não foi realizada uma auditoria formal de
segurança nem uma matriz de testes de versões do macOS.

## Contribuições

Issues e pull requests são bem-vindos. Inclua a versão do macOS, a arquitetura
e uma descrição do comportamento esperado. Não envie tokens, conversas
privadas ou capturas com dados pessoais. Alterações de permissões, acesso a
dados, rede ou atualização automática precisam de revisão explícita.

## Licença

MIT, conforme [LICENSE](LICENSE). Projeto independente, sem afiliação com
Discord ou Badgeify. Nenhum código ou binário do Badgeify é incluído.
O ícone do Discord é obtido do aplicativo instalado, em tempo de execução;
ele não é distribuído como um recurso deste repositório.
