# moj — CLI de autoria de problemas do MOJ

Crie e edite problemas do MOJ **sem git e sem chave SSH**. Você só precisa do seu **login do
MOJ**. Trabalhe os arquivos localmente (texto comum) e o `moj` cuida do resto pela API — o
servidor faz o git por baixo (Gitea atrás), commitando como você.

## Instalação

Precisa só de `bash`, `curl` e `jq`. Baixe o script e ponha no PATH:

```bash
curl -fsSL https://moj.naquadah.com.br/moj -o ~/.local/bin/moj && chmod +x ~/.local/bin/moj
```

Config (opcional): `MOJ_URL` (default `https://moj.naquadah.com.br`). Para testar contra um
servidor local: `export MOJ_URL=http://127.0.0.1:8080 MOJ_HOST=moj.charge.naquadah.com.br`.

## Uso rápido

```bash
moj login                       # seu login + senha do MOJ (guarda um token em ~/.config/moj)
moj mkdir meus-problemas        # cria uma "pasta" (diretório) sua
moj new meus-problemas soma     # scaffold de um problema novo em ./soma
$EDITOR soma/docs/enunciado.md  # edite o enunciado (Markdown canônico)
#   ... edite tests/input|output/sample*, sols/good/sol.py, tags, author ...
moj test soma                   # pré-voo local (enunciado + exemplos + solução)
moj push soma                   # envia (cria/edita); commit autorado por você
moj publish meus-problemas#soma # valida no juiz e, passando, entra no treino livre
moj status meus-problemas#soma  # vê o relatório de validação (o portão)
```

## Comandos

| Comando | O que faz |
|---|---|
| `moj login` / `logout` / `whoami` | sessão (token em `~/.config/moj/token`, modo 600) |
| `moj repos` | suas pastas (dono ou compartilhadas) |
| `moj ls [mine\|shared\|public]` | lista problemas |
| `moj mkdir <pasta>` | cria uma pasta (repo no seu namespace) |
| `moj new <pasta> <prob>` | scaffold de um problema canônico em `./<prob>` |
| `moj clone <id> [dir]` | baixa o source de um problema p/ editar local |
| `moj test [dir]` | pré-voo local (o portão autoritativo é no `publish`) |
| `moj push [dir] [--force]` | envia; **só sobe o que passa no pré-voo** (`--force` = rascunho privado) |
| `moj publish <id>` / `unpublish <id>` | torna público (valida no juiz) / despublica |
| `moj calibrate <id>` | pede calibração (gera os time limits no juiz) |
| `moj status <id>` | relatório de validação (checks do portão) |
| `moj share <pasta> <login>` / `unshare …` | compartilha a pasta com um colega |

## Formato do problema (pacote canônico)

```
<prob>/
  docs/enunciado.md     # % Título · descrição · ## Entrada · ## Saída · ## Observações
  author                # autor(es) — texto livre
  tags                  # uma tag por linha
  conf                  # ULIMITS/TLMOD (opcional)
  tests/input/sample1   # exemplos (sample*) — ficam SEMPRE visíveis no enunciado
  tests/output/sample1
  tests/input/2         # testes ocultos (qualquer nome != sample*)
  sols/good/sol.py      # solução de referência (precisa ser ACEITA p/ publicar)
  .moj-id               # {id, repo, prob, title} — gerado pelo new/clone
```

Os **exemplos** são injetados no enunciado a partir de `tests/input|output/sample*` — não os
escreva à mão no Markdown; assim eles batem sempre com os testes reais.

## Portão de qualidade

`moj push` faz um **pré-voo local** (enunciado, ≥1 exemplo, solução `good` presente). O portão
**autoritativo** roda no servidor quando você dá `moj publish`: 1 juiz valida que o **HTML
compila**, os **exemplos aparecem** e a **solução `good` é aceita**. Só então o problema entra no
treino livre. Rascunho quebrado fica na sua pasta **privada** (use `--force` p/ subir mesmo assim);
**nunca** vai a público sem passar.

## Modo git (avançado, opcional)

O fluxo acima é 100% sem git. Quem quiser usar git de verdade pode pedir uma credencial HTTPS
efêmera (`POST /problems/git-credential`) e clonar/pushar direto do Gitea — requer que o Gitea
esteja alcançável pelo cliente (ver `cdmoj/docs/DEPLOY-GITEA.md`). Para a maioria, **não precisa**.
