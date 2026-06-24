# moj — CLI de autoria de problemas do MOJ

Crie e edite problemas do MOJ **sem git e sem chave SSH**. Você só precisa do seu **login do
MOJ**. Dois jeitos de trabalhar (acesso a **tudo** que a página web tem):

- **Editor interativo** (como preencher os campos da página): `moj edit <id|pasta>`
- **Arquivos locais** (use seu editor favorito): `moj clone <id>` → edite os arquivos → `moj push`

## Instalação

Precisa de `bash`, `curl`, `jq` (e um editor para `moj edit`, via `$EDITOR`). Baixe e ponha no PATH:

```bash
curl -fsSL https://moj.naquadah.com.br/moj -o ~/.local/bin/moj && chmod +x ~/.local/bin/moj
```

Config (opcional): `MOJ_URL` (default `https://moj.naquadah.com.br`), `EDITOR`. Para testar local:
`export MOJ_URL=http://127.0.0.1:8080 MOJ_HOST=moj.charge.naquadah.com.br`.

## Editor interativo (recomendado)

```bash
moj login
moj edit competicao#meu-problema     # clona (se preciso) e abre o menu
```

O menu espelha os campos da página — escolha um número/letra para editar:

```
── Editando competicao#meu-problema  (pasta ./meu-problema) ──
  1) Título     2) Autor     3) Tags
  4) Enunciado (abre o $EDITOR)   5) Exemplos (N)   6) Testes ocultos (M)
  7) Soluções (good/wrong/slow/pass/upcoming)   8) Conf   9) Coleções
  0) Público    r) Compartilhar pasta    v) Pré-visualizar
  w) SALVAR (push)   P) Validar & Publicar   i) Info/validação   q) Sair
```

Enunciado e código de solução abrem no seu `$EDITOR`; título/autor/tags são campos editáveis;
exemplos/testes/soluções têm submenus de adicionar/editar/remover; `conf` tem atalhos para as
opções comuns (calibrafactor, ULIMITS, CALIBRATIONTL, ALLOWPARALLELTEST, STOPWHEN…) + edição
bruta; `9) Coleções` cria/escolhe coleções e gerencia setters/co-admins.

## Comandos

| Comando | O que faz |
|---|---|
| `moj login` / `logout` / `whoami` | sessão (mostra se você pode criar problemas) |
| `moj edit <id\|dir>` | **editor interativo** (campos da página) |
| `moj ls [mine\|shared\|public]` · `moj repos` | listas |
| `moj info <id>` | tudo do problema (dono, público, coleções, validação, contagens) |
| `moj new <pasta> <prob>` | scaffold completo do pacote em `./<prob>` |
| `moj clone <id> [dir]` | baixa o pacote **inteiro** (enunciado, conf, exemplos, testes, todas as soluções) |
| `moj test [dir]` · `moj push [dir] [--force]` | pré-voo local · envia (cria/edita) |
| `moj preview [dir]` | renderiza o enunciado em HTML (abre no navegador) |
| `moj download <id> [arq]` · `moj upload <id> <arq>` | baixa/sobe o pacote `.tar.gz`/`.tar.bz2`/`.tar.zst`/`.zip` |
| `moj public <id> on\|off` · `moj publish <id>` · `moj calibrate <id>` | publicar/calibrar |
| `moj status [<id>]` | status do sistema (juízes/fila) ou a validação de um problema |
| `moj mkdir <pasta>` · `moj share <pasta> <login>` / `unshare …` | pastas e compartilhamento |
| `moj collection ls` | coleções (setters, admins, quais você gerencia) |
| `moj collection create <nome> [--members a,b] [--admins c,d]` | cria coleção (competição/curso) |
| `moj collection members <nome> [--add] [--remove] [--admins-add] [--admins-remove]` | gerencia o grupo |

## Pacote do problema (arquivos)

```
<prob>/
  docs/enunciado.md     # % Título · ## Entrada · ## Saída · ## Observações
  conf                  # TL/ulimits/STOPWHEN… (atalhos no 'moj edit', opção 8)
  author · tags
  tests/input|output/sample1   # exemplos (aparecem no enunciado)
  tests/input|output/<nome>    # testes ocultos
  sols/good|wrong|slow|pass|upcoming/<arquivo>   # soluções por categoria
  .moj-id               # ponteiro local (id/repo/prob/título/coleções) — não é enviado
```

## Quem pode criar

Criar problemas/pastas/coleções segue a **mesma permissão de criar contests** (admin do treino
libera por usuário ou por nº de problemas resolvidos). `moj whoami` mostra se você pode; editar e
compartilhar problemas existentes funciona para quem é dono/colaborador.

## Portão de qualidade

`moj push` faz pré-voo local (enunciado, ≥1 exemplo, solução `good`). O portão **autoritativo**
roda no servidor em `moj publish` (1 juiz valida HTML+exemplos+`good` aceita). Só então entra no
treino livre; rascunho quebrado fica privado (`--force`).
