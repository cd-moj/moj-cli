# moj-cli — CLI de autoria de problemas

`moj` é a CLI de autoria de problemas do MOJ: **sem git, sem chave — só o seu login do MOJ**.
Espelha o editor web falando com a mesma API (`/api/v1/problems/*`). Repo git próprio.
**Ver `README.md`** e o cabeçalho do script `moj` (lista completa de subcomandos).
Workspace multi-repo: ver `../CLAUDE.md`.

- Dois fluxos: **interativo** (`moj edit <id|pasta>`, campos como na web) ou **arquivos locais**
  (`moj clone <id>` … edita … `moj push`). Também: `login/whoami`, `ls`, `new`, `test`,
  `preview`, `download/upload`, `public`, `publish`, `calibrate`, `share`, `collection`.
- Config por ambiente: `MOJ_URL` (default `https://moj.naquadah.com.br`), `MOJ_HOST` (header
  `Host` p/ teste local), `EDITOR`.
- É um **cliente** da API — não tem lógica de julgamento própria. O formato de pacote é o do
  `cdmoj` (ver `cdmoj/CLAUDE.md`).
- Um arquivo só (`moj`), `bash -euo pipefail`. `bash -n moj` antes de commitar.
