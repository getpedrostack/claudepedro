# Extensões do Claude: o que está instalado e como usar

Instaladas em 25/10/2026, cada uma fixada no commit que foi auditado (os commits estão no
cabeçalho de `scripts/instalar-extensoes-claude.ps1`).

| Extensão | Tipo | Para que serve |
|---|---|---|
| `d3-viz` | skill | gráficos interativos sob medida com d3.js (rede, mapa, heatmap, chord etc.) |
| `webapp-testing` | skill | abrir um site/app local num navegador de verdade (Playwright), clicar, tirar print, ler o console |
| `superpowers` | plugin (conjunto de skills) | método de trabalho: brainstorming antes de criar, TDD, depuração sistemática, planos |
| `music21` | servidor MCP | análise musical: tonalidade, acordes, harmonia, condução de vozes, contraponto |
| `philosophy` | servidor MCP | pesquisa acadêmica: PhilPapers, Stanford Encyclopedia (SEP), OpenAlex, Gutenberg, Wikisource |

## Preciso fazer algo para usar?

**Não. Tudo é chamado automaticamente.** Escreva o pedido normalmente. O Claude compara o
pedido com a descrição de cada skill e de cada ferramenta MCP e usa a que encaixa. Não é preciso
mudar nada nos seus prompts.

Para **forçar** uma skill específica, digite `/` e o nome dela no início da mensagem:

```
/d3-viz faça um gráfico de dispersão tempo de desenvolvimento × nota de xícara das torras 336–366
/webapp-testing abra o painel TORRAS CONVENCIONAIS e confira se o gráfico de RoR renderiza
/superpowers:brainstorming quero um painel novo para comparar perfis de torra
```

Para servidores MCP não existe atalho com `/`: basta citar o assunto ("use o music21…",
"procure no PhilPapers…") e o Claude chama a ferramenta.

## Exemplos de pedidos que acionam cada uma

- **d3-viz**: "monte um heatmap interativo de temperatura × tempo para as últimas 10 torras",
  "quero um diagrama de rede ligando origens, processos e notas sensoriais".
- **webapp-testing**: "teste o formulário do app e me mostre um print depois de enviar",
  "abre o index.html e me diz quais erros aparecem no console".
- **superpowers**: entra sozinho quando você pede algo novo para construir (faz perguntas antes),
  quando há um bug (investiga antes de corrigir) e antes de declarar algo pronto (verifica).
- **music21**: "analise a harmonia deste MusicXML", "qual a tonalidade desta melodia: C D E G A",
  "harmonize esta melodia no estilo coral de Bach", "gere um contraponto de 1ª espécie".
- **philosophy**: "busque artigos recentes sobre fenomenologia da percepção gustativa",
  "traga o verbete da SEP sobre estética e resuma", "ache o texto de Hume *Of the Standard of Taste*".

## Onde cada coisa funciona

| | Sessões na nuvem (claude.ai/code, app) | Claude Code no seu Windows | Claude Desktop (chat) |
|---|---|---|---|
| skills d3-viz e webapp-testing | ✅ automático (vêm em `.claude/skills`) | ✅ neste repositório; em qualquer pasta depois do `.ps1` | ❌ (veja abaixo) |
| plugin superpowers | ✅ automático (o hook instala) | ✅ depois do `.ps1` | ❌ |
| music21 / philosophy | ✅ automático (`.mcp.json` + hook) | ✅ depois do `.ps1` | ✅ depois do `.ps1` |

### Nuvem: como funciona por baixo

- `.claude/skills/`: as skills ficam no próprio repositório, então qualquer sessão as enxerga.
- `.mcp.json`: declara os dois servidores. Eles iniciam por `.claude/mcp/launch.mjs`, que instala
  o servidor sozinho se ainda não estiver instalado.
- `.claude/hooks/session-start.sh`: roda ao abrir cada sessão na nuvem e deixa tudo pré-instalado
  (servidores, Playwright para Python, plugin superpowers). Leva uns 55 s no primeiro uso de um
  container e cerca de 6 s depois disso.
- `.claude/settings.json`: registra o hook, aprova os dois servidores e desliga a telemetria do
  superpowers (`SUPERPOWERS_DISABLE_TELEMETRY=1`).

**Atenção:** na nuvem, o servidor `philosophy` instala e inicia, mas a rede padrão do ambiente
bloqueia as fontes de pesquisa. Para liberar, abra o menu do ambiente na barra de título da
sessão → **Edit** → **Network access** e adicione em *Allowed domains* (deixe marcada a opção
de gerenciadores de pacotes):

```
philpapers.org  philarchive.org  plato.stanford.edu  api.openalex.org  archive.org
openlibrary.org  gutendex.com  www.gutenberg.org  directory.doabooks.org  *.wikisource.org
```

As ferramentas `fetch_pdf` e `fetch_text` baixam URLs arbitrárias e só funcionam com acesso
total à rede. Passo a passo oficial: https://code.claude.com/docs/en/cloud-environments#network-access

### No seu Windows

Rode uma vez, no PowerShell, a partir da pasta deste repositório:

```
powershell -ExecutionPolicy Bypass -File .\scripts\instalar-extensoes-claude.ps1
```

Depois, feche o Claude Desktop pela bandeja do sistema (**Sair**) e abra de novo. No Claude Code,
abra uma sessão nova e rode `/mcp` para conferir.

### Claude Desktop / claude.ai (chat)

Skills de chat são enviadas à parte: **Configurações → Capacidades → Skills → Enviar skill**,
com os mesmos `.zip` de `d3-viz` e `webapp-testing`. A `webapp-testing` precisa rodar Python com
navegador, então no chat ela serve só como referência; o uso real dela é no Claude Code.

## Como conferir se está tudo ativo

- `/mcp`: lista os servidores (music21 e philosophy devem aparecer como *connected*).
- `/`: lista as skills (procure `d3-viz`, `webapp-testing` e as `superpowers:…`).
- `/plugin`: mostra o superpowers como *enabled*.

## Se uma skill não for chamada quando deveria

Use o `/nome-da-skill` para forçar. Se acontecer sempre, a descrição (`description`) no topo do
`SKILL.md` está vaga para o seu jeito de pedir. Dá para acrescentar ali as palavras que você usa
(por exemplo, "torra", "curva", "RoR" na `d3-viz`).
