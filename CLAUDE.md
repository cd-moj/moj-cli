# moj-cli — CLI de autoria de problemas

`moj` é a CLI de autoria de problemas do MOJ: **sem git, sem chave — só o seu login do MOJ**.
Espelha o editor web falando com a mesma API (`/api/v1/problems/*`). Repo git próprio.
**Ver `README.md`** e o cabeçalho do script `moj` (lista completa de subcomandos).
Workspace multi-repo: ver `../CLAUDE.md`.

- Dois fluxos: **interativo** (`moj edit <id|pasta>`, campos como na web) ou **arquivos locais**
  (`moj clone <id>` … edita … `moj push`). Também: `login/whoami`, `ls`, `board` (painel dos seus
  problemas + o que revisar), `new`, `test`, `preview`, `download/upload`, `public`, `publish`
  (público => o servidor **valida + calibra**, via `set-public`), `calibrate`, `status [<id>]` /
  `check <id>` (QA: validação + TL por juiz + solução good sem TL / falhou em todas as máquinas),
  `share` (= adiciona membro à org), `org` (list/create/members/public/rm — **ACESSO**: a org é o
  `<org>` do id; membros escrevem, admins mexem na trava de público; `rm` só org **vazia**),
  `mv <id> <org>` (move rascunho, muda o id), `collection` (ls/create/show/add/remove/rename/delete — **COLEÇÃO = tag de agrupamento**,
  m:n, ORTOGONAL à org; nome pode ter espaços; curada: só marca em coleção existente).
- Config por ambiente: `MOJ_URL` (default `https://moj.naquadah.com.br`), `MOJ_HOST` (header
  `Host` p/ teste local), `EDITOR`.
- É um **cliente** da API — não tem lógica de julgamento própria. O formato de pacote é o do
  `cdmoj` (ver `cdmoj/CLAUDE.md`, seção "Pacote canônico"). **Título = campo** (`.moj-id` `.title` →
  `display_title`), **não** o `% Título` do texto (legado); por isso `push`/`upload` exigem título.
- **Mexeu no formato do pacote?** A descrição em `README.md` ("Pacote do problema") tem de bater com
  `cdmoj/docs/API.md` + `cdmoj/CLAUDE.md` + `mojtools/CLAUDE.md` — atualize as quatro no mesmo commit.
- Um arquivo só (`moj`), `bash -euo pipefail`. `bash -n moj` antes de commitar.
- Rodapé de commit: **só** `Co-Authored-By:`, **nunca** uma linha `Claude-Session:` (ruído no histórico).
- **Doc junto com o código** (doc atrasada = bug): mudou subcomando/contrato? atualize o `README.md`, o
  cabeçalho de `moj` e `cdmoj/docs/API.md` (+ `openapi.json`) no mesmo commit.
