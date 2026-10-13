DiscordBar 1.0 — macOS 13 ou posterior

Aplicativo pessoal em Swift/AppKit que espelha o indicador do Discord no Dock.
O executável entregue foi compilado para Apple Silicon.

INSTALAÇÃO
Coloque DiscordBar.app em Aplicativos e abra-o. Na primeira abertura, o app
solicita Acessibilidade e registra o início com o Mac. Habilite DiscordBar em:
Ajustes do Sistema → Privacidade e Segurança → Acessibilidade.
Se ele não aparecer, use + e escolha /Applications/DiscordBar.app.
Se necessário, saia pelo menu e abra novamente após conceder a permissão.
O indicador do Dock só pode ser lido após essa autorização do macOS.

USO
Clique normal: abre Discord (ou Acessibilidade enquanto falta permissão).
Clique direito / Control + clique: opções, início automático e sair.
Bolinha vermelha: indicador de notificações do Discord.
Número: contagem numérica disponibilizada pelo Dock, limitada visualmente a 99+.
Ícone atenuado: sem notificações ou Discord fechado.
Bolinha laranja: falta Acessibilidade ou leitura do Dock indisponível.

O Discord deve estar aberto e com seu indicador de mensagens não lidas ativo.
Não é necessário manter o Dock visível. Não há janela na inicialização.
O app não lê mensagens nem se conecta ao Discord ou à internet.

O início automático pode exigir autorização adicional em Ajustes do Sistema →
Geral → Itens de Início e Extensões. Pode ser desligado pelo menu do DiscordBar.

COMPILAÇÃO
Requer Command Line Tools da Apple. Execute:
  bash build.sh /caminho/para/destino
O script gera um .app com assinatura local, na arquitetura do Mac que compila.
Para recompilar uma versão instalada, encerre o app antes de substituí-lo.
Uma assinatura local nova pode exigir conceder Acessibilidade novamente.

REMOÇÃO
Desative “Iniciar com o Mac”, escolha “Sair do DiscordBar” e mova o app à Lixeira.

Implementação própria. Nenhum código ou binário do Badgeify foi utilizado.
