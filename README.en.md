# moj — the MOJ problem-authoring CLI

[Versão em português: `README.md`](README.md)

This document follows **STE** (Simplified Technical English): one instruction per sentence, short
sentences, active voice, one term per concept. The glossary is at the end.

`moj` creates and edits MOJ problems. You do not need git. You do not need an SSH key. You need
only your MOJ login. There are two ways of working. Both give access to everything the web page has.

- **Interactive editor**. Run `moj edit <id|dir>`. The menu shows the same fields as the page.
- **Local files**. Run `moj clone <id>`. Edit the files with your editor. Run `moj push`.

## Installation

Requirements: `bash`, `curl` and `jq`. For `moj edit`, set the `$EDITOR` variable.

1. Download the file.
2. Make the file executable.
3. Put the file in your `PATH`.

```bash
curl -fsSL https://moj.naquadah.com.br/moj -o ~/.local/bin/moj && chmod +x ~/.local/bin/moj
```

After the installation, use these three commands to keep the CLI up to date:

- `moj update` updates the CLI itself. It downloads the served artifacts and replaces the file in place.
- `moj version` compares your build with the server build.
- `moj doctor` diagnoses the environment: update status, `jq`, `curl`, mojtools, bwrap and session.
  Start with it when something looks wrong.

The CLI warns you when it is out of date. The server sends the `X-Moj-Cli-Status` header in every
response. If your build is behind, the CLI prints a warning to stderr once a day. The command
continues normally. A CLI from before September 2026 has no marker in the User-Agent. That CLI gets
the same hint appended to the server error messages.

The CLI has four layers. Each layer is one executable. Download only what you use.

| Executable | Who uses it | How to download |
|---|---|---|
| `moj` | problem author | command above |
| `moj-contest` | contest organizer (`moj contest …` delegates here) | `curl -fsSL https://moj.naquadah.com.br/moj-contest -o ~/.local/bin/moj-contest && chmod +x ~/.local/bin/moj-contest` |
| `moj-comp` | competitor or student (`moj comp …` delegates here). It is the only layer with the **offline mode** | `curl -fsSL https://moj.naquadah.com.br/moj-comp -o ~/.local/bin/moj-comp && chmod +x ~/.local/bin/moj-comp` |
| `moj-judges` | admin of the judge fleet (`moj judges …` delegates here) | `curl -fsSL https://moj.naquadah.com.br/moj-judges -o ~/.local/bin/moj-judges && chmod +x ~/.local/bin/moj-judges` |

The served files are self-contained. The script `mkdist.sh` builds each one from `lib/core.sh` and
the layer. When you run from the repository, each script loads `lib/core.sh` directly.

### Configuration (optional)

| Variable | Effect |
|---|---|
| `MOJ_URL` | server address. Default: `https://moj.naquadah.com.br` |
| `EDITOR` | text editor for `moj edit` |
| `MOJ_CONFIG_DIR` | folder of the token and the cache |
| `MOJ_CONTEST` | the target contest. It works as `-c` in `moj-contest` and `moj-comp` |
| `MOJ_HOST` | `Host` header. Use it for local tests |
| `MOJ_NO_CACHE=1` | disables the local cache |
| `MOJ_UA_FILE`, `MOJ_USER_AGENT` | extra User-Agent. See the note below |

Every CLI identifies itself to the server as `<tool>/<build>` in the User-Agent. If the file
`/etc/moj/user-agent` exists, or if `MOJ_USER_AGENT` is set, the CLI sends that value first. On a
contest machine, that value is the User-Agent of the site image browser. With it, the CLI passes the
per-site browser gate and uses the same machine key as the browser. See `cdmoj/docs/MANUAL-ADMIN.md`,
section 7. The server separates web requests from CLI requests by this marker.

To test against a local server:

```bash
export MOJ_URL=http://127.0.0.1:8080 MOJ_HOST=moj.charge.naquadah.com.br
```

## Interactive editor (recommended)

```bash
moj login
moj edit competicao#meu-problema     # clones, if needed, and opens the menu
```

The menu shows the fields of the page. Type a number or a letter to edit a field:

```
── Editing competicao#meu-problema  (folder ./meu-problema) ──
  1) Title      2) Author    3) Tags
  4) Statement (opens $EDITOR)   5) Examples (N)   6) Hidden tests (M)
  7) Solutions (good/wrong/slow/pass/upcoming)   8) Conf   9) Collections
  0) Public     L) Languages    r) Share folder    v) Preview
  w) SAVE (push)   P) Validate & Publish   i) Info/validation   q) Quit
```

- The statement and the solution code open in your `$EDITOR`.
- Title, author and tags are text fields.
- Examples, tests and solutions have submenus to add, edit and remove.
- `8) Conf` has shortcuts for the common options: `calibrafactor`, `ULIMITS`, `CALIBRATIONTL`,
  `ALLOWPARALLELTEST`, `STOPWHEN`. It also allows raw editing of the file.
- `9) Collections` marks the problem in existing collections. It also creates a new collection.

## `moj` commands

| Command | What it does | Example |
|---|---|---|
| `moj login` · `logout` · `whoami` | Manages the session. `whoami` shows if you can create problems. | `moj whoami` |
| `moj edit <id\|dir>` | Opens the interactive editor. | `moj edit apc#vetor1` |
| `moj ls [mine\|shared\|public]` · `moj repos` | Lists problems and orgs. | `moj ls mine` |
| `moj info <id>` | Shows everything about the problem: owner, public, collections, validation, counts. | `moj info apc#vetor1` |
| `moj new <org> <prob>` | Creates the package skeleton in `./<prob>`. `<org>` is the org of the id `<org>#<prob>`. `<prob>` is a lowercase slug `[a-z0-9._-]`. The CLI rejects other formats and suggests the right one. | `moj new apc vetor1` |
| `moj clone <id> [dir]` | Downloads the whole package: statement, conf, examples, tests, solutions, `scripts/` and `tests/score`. | `moj clone apc#vetor1` |
| `moj test [dir] [--run [sol]]` | Runs the local preflight. With `tests/score`, it checks the groups: distribution, orphan test, invalid line. `--run` judges locally with mojtools. It requires Linux and bwrap. | `moj test --run` |
| `moj push [dir] [--force]` | Sends the package. It creates or edits the problem. The upload is complete, with `scripts/`. | `moj push` |
| `moj doctor` · `moj version` · `moj update` | Diagnoses the environment · compares the build · updates the CLI. | `moj doctor` |
| `moj checker <dir> <checker.cpp> [--force]` | Installs a testlib checker. It requires local mojtools (`MOJTOOLS_DIR`). It refuses to overwrite an existing `scripts/`. `--force` replaces it. | `moj checker ./p chk.cpp` |
| `moj interactive <dir> <referee> [--score]` | Installs the interactive-problem driver. It requires local mojtools. | `moj interactive ./p ref.cpp` |
| `moj fn <dir> [--langs …] [--force]` | Installs the function-submission drivers in 5 languages, with an anti-IO sentinel. It requires local mojtools. | `moj fn ./p --langs c,py` |
| `moj preview [dir] [--lang en\|es]` | Renders the statement as HTML and opens it in the browser. `--lang` renders the translation, with the translated title and explanations. | `moj preview --lang en` |
| `moj title [dir] [--lang en\|es] [<title>]` | Shows or sets the title. With `--lang`, the title of the translation. It writes to `.moj-id`. It applies on the next `push`. | `moj title . --lang en "Sum"` |
| `moj download <id> [file] [--sha <sha>]` | Downloads the whole package. `--sha` downloads the version of that commit. | `moj download apc#vetor1` |
| `moj upload <id> [dir\|file] [--force]` | Uploads the whole package. The CLI packs a directory. It excludes `.git`, caches and `.moj-id`, and generates a `.moj-meta.json` with the title, collections and languages from `.moj-id`. Formats: `.tar.gz`, `.tar.bz2`, `.tar.zst`, `.zip`. A missing meta keeps the server values. A tar without the `tags` file keeps the tags. | `moj upload apc#vetor1 ./vetor1` |
| `moj languages <dir> [c,cpp,py,…\|all]` | Sets the list of submission languages of the problem. Without an argument, it shows the list. `all` allows all standard languages. It writes to `.moj-id`. It applies on the next `push`. Required for function or ban problems: without it, a language switch bypasses the driver. | `moj languages ./p c,py` |
| `moj export <id> [file.tar.gz]` · `moj import <package> <dir> [prob]` | Exports in the ICPC/Kattis format. Imports a Kattis package as a MOJ problem. The `.kattis.json` file keeps the round-trip lossless. | `moj export apc#vetor1` |
| `moj rm <id>` | Removes the problem from the bank and from training. It asks for confirmation with the id. | `moj rm apc#old` |
| `moj log <id> [-n N]` · `moj log <id> <sha>` | Shows the git history of the problem. Every save and every upload is a commit. With `<sha>`, it shows `git show -p`. | `moj log apc#vetor1 -n 5` |
| `moj restore <id> <sha>` | Restores the version of the commit as a new commit. The history stays. Public and collections stay. It asks for confirmation with the sha. | `moj restore apc#vetor1 a1b2c3` |
| `moj validate <id> [--no-wait]` | Runs the quality gate without publishing. It validates statement, tests and solutions. It queues the calibration on the judge. It waits for the report and prints `moj check`. `--no-wait` does not wait. The problem stays private. Warning: every call triggers a new calibration. To only check, use `moj status` or `moj check`. | `moj validate apc#vetor1` |
| `moj public <id> on\|off [--yes]` · `moj publish <id> [--yes]` | Publishes or unpublishes. Publishing makes the server validate and calibrate. The org must allow public. | `moj publish apc#vetor1` |
| `moj calibrate <id> [--hosts h1,h2\|--all-judges\|--per-cpu]` · `--judges` · `--all-stale` | Calibrates the problem. `--hosts` uses the listed judges. `--all-judges` uses all online judges. `--per-cpu` uses one judge per CPU model. `--judges` lists the fleet. `--all-stale` recalibrates all your problems marked "needs recalibration". Repeating does not duplicate. | `moj calibrate --all-stale` |
| `moj status [<id>]` · `moj check <id>` | Without id: system health. With id: problem QA: validation, TL per judge, `good` solution without TL. It shows the `TL OVERRIDE` warning when the conf has `TLOVERRIDE`. It shows why the problem "needs recalibration": date, checksums and commits. | `moj check apc#vetor1` |
| `moj board` | Shows the dashboard of your problems: public, validated, calibrated, and what needs review. | `moj board` |
| `moj calib <id>` | Shows the full calibration: each judge, each solution, each test `{name,code,time,tl}`. `--json` prints raw JSON. | `moj --json calib apc#vetor1` |
| `moj calib-report <id> [--host <judge> --sol <name>] [-o out.html]` | Downloads the `report.html` of a calibrated solution. Without `--host` and `--sol`, it lists the available ones. | `moj calib-report apc#vetor1` |
| `moj testrun <id\|dir> <file> [--report out.html] [--no-wait]` | Runs one solution on the judge, with the sandbox and the TL of a real submission. It does not enter the history or the scoreboard. It requires edit permission. | `moj testrun apc#vetor1 sol.cpp` |
| `moj testrun-status <run> [--report out.html]` | Queries a queued testrun. | `moj testrun-status 1f3a…` |
| `moj mkdir <org>` · `moj share <org> <login>` · `moj unshare <org> <login>` | Creates an org. Adds or removes a member. Warning: the login must exist in training and must be allowed to create problems. Otherwise the server answers 404 or 403 and writes nothing. Removing does not validate. | `moj share apc ta.ana` |
| `moj org list\|create\|members\|public\|rm` | Manages orgs: members and the public lock. An org is born private. Only the org admin changes the lock. `rm` removes an empty org. | `moj org public apc on` |
| `moj mv <id> <org>` | Moves a draft to another org. The id changes to `<org>#<prob>`. It refuses a public problem or a problem in use. | `moj mv ana#p apc` |
| `moj collection ls\|show\|create\|add\|remove\|rename\|delete\|status` | Manages collections. `create "<name>"` creates. `add` and `remove` mark and unmark a problem. `show` lists. `rename` and `delete` work for the collection owner. The server re-tags in the background. The CLI follows until the end. `--no-wait` does not wait. | `moj collection add apc#vetor1 "APC 2026.1"` |

## Problem package (files)

The complete format reference is `cdmoj/docs/PACOTE.md`. It is the single source for the files, the
`.moj-meta.json` and `.moj-id` metadata, orgs, collections and the cycle validate → calibrate →
publish. The recipe to build a package from scratch is in `mojtools/README.md`. Below is the summary
for CLI users.

The title is a field. It is not a line in the text. Locally, the title lives in `.moj-id`
(`.title`). On upload, it becomes `display_title` in the server `.moj-meta.json`. The renderer
injects the `<h1>`. A `% Title` at the top of the statement is legacy. The renderer removes it.
Because of this, `moj push` and `moj upload` require a title.

```
<prob>/
  docs/enunciado.md         # statement in Portuguese (.md | .org | .tex). It requires ## Entrada and ## Saída.
                            #   No "% Título" (the title is a field). Images: embedded base64.
  docs/enunciado.en.md      # (optional) the translation (en, es). Same sections (## Input / ## Output).
  docs/notes/sample1.md     # (optional) explanation of each example (1 markdown per example)
  docs/notes/sample1.en.md  # (optional) the translated explanation. Without it, the example shows the PT one.
  docs/solucao.md           # (optional) editorial. Only the author sees it. It never goes to the student.
  docs/solucao.en.md        # (optional) the translated editorial (goes into the EN editorial document).
  conf                      # TL, ulimits, STOPWHEN. Shortcuts in 'moj edit', option 8.
  author                    # authors, 1 line
  tags                      # 1 tag per line
  tests/input/sample1  tests/output/sample1   # examples (paired; shown in the statement)
  tests/input/<name>   tests/output/<name>    # hidden tests (judging)
  tests/score               # (optional) score groups per subtask. It travels in push and clone.
  sols/{good,wrong,slow,pass,upcoming}/<file>   # solutions by category (good = accepted)
  scripts/                  # (optional) special judging (compile, compare, checker, referee).
                            #   It travels in push and clone: content, +x and symlinks.
                            #   A change in scripts/ triggers recalibration on the judge.
  .moj-id                   # local pointer (id, repo, prob, title, translated titles,
                            #   collections, languages, public). It is not uploaded.
```

**Languages.** Portuguese is required. A translation is a file next to it, with the language code
in the name. The title of the translation lives in `.moj-id` (`titles`): `moj title . --lang en
"Hello World"`. In `moj edit`, option `t` handles translations and option `e` the editorial in each
language. `moj push` and `moj clone` carry everything. In a clone, removing `docs/enunciado.en.md`
and running `push` removes the translation on the server.

On the server, the metadata lives in `.moj-meta.json`: `display_title`, `public`, `collections`,
`languages`, `owner`. The server generates this file from what you send. You do not edit it.

`languages` is the list of allowed submission languages of the problem. An empty or missing list
allows all. Example: `["pddl"]` for a problem that accepts only PDDL. The list round-trips in
`.moj-id`: `clone` → `moj languages` → `push`.

`moj push` sends the title, collections and languages from `.moj-id`. `moj upload` uploads a whole
`.tar` or `.zip` and sends the same fields. From a directory with `.moj-id`, the CLI generates the
`.moj-meta.json` inside the tar. From a tar made by `moj download`, the real meta is already there.
In both cases, the server reads only the content fields: title, collections and languages. A missing
field or `[]` keeps the server value. `public` and `owner` never come from the tar.

## Competitor CLI (`moj-comp` / `moj comp …`)

`moj-comp` is the CLI of the student or competitor inside a contest.

| Command | What it does |
|---|---|
| `login <cid\|url>` | Logs into the contest with the credentials from the organization. |
| `fetch` | Downloads all statements, in every language the contest offers (`A.html`, `A.en.html`…), and the samples of each problem in `samples/<letter>/`. You work without network. |
| `problems` · `score` · `news` | Lists problems (with the statement languages of each one) · shows the scoreboard · shows announcements. |
| `statement <letter> [--lang en\|es]` | Downloads one statement. Without `--lang`, every offered language. With a language the contest does not offer, the CLI refuses and lists the available ones. |
| `samples <letter> [--dir folder]` | Downloads the statement samples as files: `samples/<letter>/<name>.in` and `.out`. `fetch` already does this for every problem (the kit's `samples/` folder). A statement uploaded ready-made by the organization has no samples as files: the CLI says so. |
| `submit <letter> <file>` | Submits and waits for the verdict. |
| `subs` | Lists your submissions and verdicts. |
| `clar ls` · `clar ask <letter\|geral> <text>` | Lists and asks questions to the judges. |
| `time` · `doctor` · `update` | Compares the clock · diagnoses · updates. |
| `outbox` · `sync` · `monitor` | Shows the offline queue · resends now · watches the network outage. |

**Offline mode.** When `submit` cannot reach the server, the CLI packs the submission. The package is
encrypted with the public key of the contest, received at login. The package carries the current UTC
time, corrected by the measured clock offset. `moj-comp monitor` watches the network. When the
network returns, it resends by itself. The submission counts at the stamped time. The route is
`/contest/offline-submit`. A signed beacon from the server and the arrival time bound the stamp. See
`cdmoj/docs/FLOW.md`, section 7½. The competitor guide is at `/contest/cli.html` on the server.
Requirements: `bash`, `curl`, `jq` and `openssl`.

Several subcommands accept a Portuguese alias: `baixar` = `fetch`, `noticias` = `news`,
`relogio` = `time`, `reenviar` = `sync`. In the other layers: `maquinas` = `machines`,
`test-run` = `testrun`. Use the one you prefer.

The same CLI serves open training, without the offline mode. Run `moj-comp login treino` with your
site account. Then use `problems <search>`, `statement <org#slug> [--lang en]` (writes `slug.html`
and one `slug.<lang>.html` per translation), `submit <org#slug> <file>` and `subs`. The training
guide is at `/treino/cli.html`.

## Contest management (`moj-contest` / `moj contest …`)

`moj-contest` creates, reuses and administers contests through the API. The same restrictions as the
web apply. The server enforces them.

There are two sessions:

1. The commands `create`, `template`, `export`, `duplicate`, `list` and `remove` use the training
   session. Run `moj login`.
2. The admin commands require a session in that contest. Run `moj-contest login <cid>` with a
   `*.admin` account of the contest. The token lives in `~/.config/moj/token-<cid>`. It does not
   replace the training session.

The target contest comes from `-c <cid>` or from `MOJ_CONTEST`.

| Command | What it does | Example |
|---|---|---|
| `login <cid> [-u login]` · `logout [<cid>]` · `whoami` | Manages the per-contest session. | `moj-contest login prova1 -u ana.admin` |
| `create [spec.json\|-] [--template <name>] [--id --name --start --end] [--mode icpc\|obi\|treino\|heuristic] [--empty] [--modules a,b]` | Creates the contest. It accepts a JSON spec, a saved template, or both. It requires at least one problem. `--mode` picks the scoreboard (default `icpc`; `obi` = score per test; `treino` = exercise list; `heuristic`). The mode does not change after creation: to switch, export the spec, edit `mode` and create again. `--empty` creates the empty room. `--modules` turns modules on at creation. | `moj-contest create --empty --id lab1 --name "Lab 1" --mode obi --end 1790000000` |
| `list` · `show <cid>` | Lists your contests · shows the summary of one, with the enabled modules. | `moj-contest show lab1` |
| `export <cid> [file] [--full]` | Writes the contest spec to a file. Without credentials. It carries the `modules{}` section with the data of each enabled module. Without secrets. | `moj-contest export lab1` |
| `duplicate <cid> [--id --name --start --end]` | Copies a contest. Without users. The round plan follows the new dates. | `moj-contest duplicate lab1 --id lab2` |
| `template list\|show\|save <name> (--from-contest <cid> [--with-problems] \| --from-file f)\|rm\|rename` | Manages named templates on the server. | `moj-contest template save lab --from-contest lab1` |
| `modules [list]` · `modules on <ids>` · `modules off <ids>` | Manages the contest modules. `list` shows on or off, and if each module has data. Turning off never deletes data. Ids: `sedes maquinas rodadas documentos baloes coortes inscricoes telao classificacao`. | `moj-contest -c lab1 modules on baloes,documentos` |
| `settings get` · `settings set k=v …` | Reads and writes the settings. ICPC penalty: `penalty_minutes=10`, `penalty_verdicts=wa,tle,mle,rte,ce`. Empty value: no verdict penalizes. Judge pool: `judges=cpu1,cpu2`. Empty: any online judge. | `moj-contest -c lab1 settings set manual_verdict=true` |
| `extend <+min\|epoch> [--group <regex> [--reason <txt>]]` | Extends the end. With `--group`, only for the matching logins. | `moj-contest -c lab1 extend +30 --group '^sala2'` |
| `problems ls\|add <id> [--name N] [--letter L]\|rm <letter>\|rename <letter> <name>\|reorder <L1> <L2>…\|langs <letter> <l1,l2\|->\|judges <letter> <h1,h2\|->` | Manages the contest problems. `langs -` and `judges -` inherit from the contest again. | `moj-contest -c lab1 problems add apc#vetor1 --letter A` |
| `problems search <q> [--collection C]` · `problems draw [--collections "A,B"] [--tags a,b] [--count N] [--difficulty d] [--match any\|all] [--seed s] [--add]` | Searches the public bank. Draws by collection, tag and difficulty. `--add` adds the result. | `moj-contest -c lab1 problems draw --tags graphs --count 3 --add` |
| `users ls [--include-disabled]\|add <login> [--pass P] [--name N] [--email E]\|reset <login>\|rm\|disable\|logout <login>\|set-password-all <password> [--include-disabled]` | Manages the users. `add` without `--pass` draws a password and prints it. The global change asks for confirmation. By default it skips disabled accounts. | `moj-contest -c lab1 users add ana` |
| `sessions` · `dashboard` · `score` · `audit [n]` · `access [day]` · `news ls\|add\|rm` | Operates the contest. | `moj-contest -c lab1 dashboard` |
| `report [file]` | Downloads the static contest report: a browsable offline site with scoreboard, statements, runs without code, anonymous clarifications, statistics and staff tasks. | `moj-contest -c lab1 report` |
| `rounds ls` · `rounds add <slug> --name N --start … --end … [--kind warmup]` · `rounds set` | Manages rounds: warm-up and official contest in the same contest. Dates accept epoch, `+90m`, `+2h` or `"YYYY-MM-DD HH:MM"`. | `moj-contest -c lab1 rounds add aq --name Warmup --start +1h --end +2h --kind warmup` |
| `rounds problems <slug> [ls\|set <id,id…>\|add <id>\|rm <letter>]` | Sets the problems of each round. They go live when the round is promoted. You can use every problem the contest owner can see: public, own, as collaborator or from the org. | `moj-contest -c lab1 rounds problems aq set apc#a,apc#b` |
| `rounds colors <slug> [ls\|set <json>\|set A=RRGGBB,B=RRGGBB[,sonic]\|clear]` | Sets the balloon colours of the round. The live round saves at once. The planned round applies them on promotion. `clear` makes the round inherit the colours in force. | `moj-contest -c lab1 rounds colors prova set A=FF0000,B=0000FF` |
| `rounds promote [--force]` | Archives the live round and puts the next one live. It refuses with a job in flight, a pending verdict or an open review. With a frozen scoreboard, it is accepted only from the end of the contest for every site + 1 minute. `--force` does not override this rule. `rounds ls` lists the blockers. It asks for the contest id. | `moj-contest -c lab1 rounds promote` |
| `rounds publish\|unpublish <slug>` · `rounds archive <slug> [file]` · `rounds rm <slug>` | Releases the scoreboard of an archived round · downloads the raw archive · deletes a round that never went live. | `moj-contest -c lab1 rounds archive aq` |
| `cohorts ls` · `cohorts add\|set <id> [--name N] [--regex R] [--sees a,b] [--private\|--public] [--unranked\|--ranked] [--default]` · `cohorts rm <id>` · `cohorts assign <login> <id>` · `cohorts materialize` · `cohorts release [on\|off]` | Manages scoreboard cohorts: official and guest teams. A private cohort does not appear on the public scoreboard. `--unranked` interleaves without taking a position. `--sees` says which cohorts that one sees. `--default` is the cohort of logins that match no regex. `release` releases the results. | `moj-contest -c lab1 cohorts add ccl --regex '^ccl' --private` |
| `machines [--round <slug>] [--csv]` | Shows team × IP × User-Agent of the round. It flags who changed machine. It suggests the gate substring. | `moj-contest -c lab1 machines --csv` |
| `ua-gate show` · `ua-gate check <login>` · `ua-gate set [--mode enforce\|off] [--from-login REGEX --expect '\\1'] [--region 'Site=part']… [--regex 'REGEX=part']… [--exempt REGEX]… [--fallback S]` | Configures the per-site browser gate. `show` lists the rules. `check` tells the expected part for a team. `--from-login` derives the part from the login. `--region` overrides one site. `--exempt` is the exemption. Warning: `--region`, `--regex` and `--exempt` replace the whole list. | `moj-contest -c lab1 ua-gate check teambrspso001` |
| `docs ls` · `docs gen [info\|caderno\|times\|editorial…] [--lang pt\|en\|es\|both\|all]` | Lists and generates the contest documents as PDF and HTML. | `moj-contest -c lab1 docs gen caderno --lang en` |
| `docs get <info\|caderno\|times\|all> [--lang …] [--fmt pdf\|html] [-o file]` | Downloads a document. Any contest account can use `ls` and `get`. They show only published documents. | `moj-contest -c lab1 docs get caderno -o booklet.pdf` |
| `docs publish <type> [--lang pt] [--news]` · `docs unpublish <type>` | Publishes to the site and to the "Prova" section. `--news` creates the announcement with the PDF. | `moj-contest -c lab1 docs publish caderno --news` |
| `docs cover <cover.pdf> [--lang pt]` · `docs cover --rm` | Sets the booklet cover as PDF. `--rm` returns to the generated cover. | `moj-contest -c lab1 docs cover cover.pdf` |
| `docs upload <type> <doc.pdf> [--lang pt]` · `docs upload <type> --rm` | Uploads the finished document. It wins over the generated one. `--rm` returns to the generated one. | `moj-contest -c lab1 docs upload caderno final.pdf` |
| `docs set caderno_version=v1.2 [errata=…] [cover_note=…]` · `docs text <info\|capa> [--show\|--from file\|--reset]` | Edits document data and texts. Texts are Markdown with `{{…}}` markers. | `moj-contest -c lab1 docs set caderno_version=v1.1` |
| `seed [--teams N] [--subs N] [--seed S]` | Populates a demo contest (`DEMO=1`) with synthetic data. | `moj-contest -c demo seed --teams 20` |
| `remove <cid>` | Takes the contest off the air. It requires a training `.admin`. | `moj-contest remove lab1` |

### The creation spec and the modules

A module is a group of contest features. A course exam turns on none. A lab exam on Maratona Linux
turns on `maquinas`. The Maratona turns on all. Turning a module off hides its panels in the admin. It
never deletes data.

You do not need to turn a module on before you use the feature. A command that writes the module data
turns the module on by itself: `rounds add` turns on `rodadas`, `cohorts add` turns on `coortes`,
`ua-gate set` turns on `maquinas`, `docs gen` turns on `documentos`. Only turning off is manual.

The JSON spec of `create` carries the `modules{}` section. Each key is a module. The value is `true`
or an object with the module data. A present object turns the module on, except with `on: false`.

```json
{
  "id": "lab1", "name": "Lab 1", "mode": "icpc", "end": 1790000000, "allow_empty": true,
  "modules": {
    "maquinas": { "ua_gate": { "mode": "enforce", "from_login": { "regex": "^team([a-z]{6})", "expect": "\\1" } },
                  "site_lock": { "enabled": true, "grace": 1200 } },
    "baloes":   { "colors": { "A": "FF0000" }, "during_freeze": false },
    "sedes":    { "regions": [ { "name": "Sorocaba", "regex": "^teambrspso" } ] },
    "rodadas":  true
  }
}
```

Sections: `sedes{regions, teams_meta, time_overrides}`, `baloes{colors, during_freeze}`,
`coortes{cohorts}`, `maquinas{ua_gate, site_lock, nutella_url}`, `rodadas{active, rounds}`,
`documentos{config}`, `inscricoes{enabled, window}`, `telao{views}`, `classificacao{algorithm,
config}`. `export` returns the same section. It does not return secrets. `create` generates new
webcast keys from `views`. A section with the wrong type answers 422 `modules_spec_invalid`.

## Who can create

Creating problems, orgs and collections follows the same permission as creating contests. The
training admin grants it per user or by number of solved problems. `moj whoami` shows if you can.
Editing and sharing existing problems works for the owner and the collaborators.

## Quality gate

`moj push` runs the local preflight: title, statement, at least one example and one `good` solution.
The authoritative gate runs on the server. `moj publish` (same as `moj public <id> on`) makes the
server validate and calibrate. Validation checks the HTML, the examples and the `good` solution.
Calibration makes a judge run the `good` solutions and report the TL. The problem enters open training
only if the gate passes. Follow it with `moj check <id>`.

**Title required.** `moj push` refuses to send without a title. An empty `.title` in `.moj-id` or
the `moj new` placeholder count as no title. Without the title, the problem would get the folder
name. `moj upload` requires `display_title` in the package `.moj-meta.json`. The `--force` flag
allows sending without a title, in push and in upload. `MOJ_ALLOW_NO_TITLE=1` is still accepted.

## Local authoring with mojtools

Four commands need a checkout of [mojtools](https://github.com/cd-moj/mojtools) on your machine.
Put the checkout in `~/moj/mojtools`, next to the CLI repository, or set `MOJTOOLS_DIR=<path>`.

- `moj checker <dir> <checker.cpp>` installs a normalized testlib checker. See
  `mojtools/docs/checker-testlib.md`.
- `moj interactive <dir> <referee.{cpp,py,sh}> [--score]` installs the interactive-problem driver.
  See `mojtools/docs/problema-interativo.md`.
- `moj fn <dir>` installs the function-submission drivers.
- `moj test <dir> --run [sol]` judges locally with `build-and-test.sh`. It judges each
  `sols/good/*` or one given solution. Without a calibrated TL, it uses a transient TL from
  `CALIBRATIONTL`. It requires Linux with real bwrap. The sandbox is the same as the judge. On macOS
  and on hosts with fbwrap, the command explains and points to the remote flow: `moj publish` or
  `moj calibrate`, then `moj check`.

The `--run` output shows, per solution, the verdict, the per-test times measured on your machine
and the path of `report.html`:

```
judging locally (mojtools: /home/you/mojtools; transient TL 5s)…
  aula.java -> Accepted,100p. Pontos | 100 |
    times (TL 5s): 0.13 0.12 0.14 …
    31 test(s), worst 0.14s
    report: /tmp/tmp.a1B2c3/report.html
```

## macOS

The CLI runs on macOS with bash 4 or newer. Install it with `brew install bash`. The CLI refuses
Apple's `/bin/bash` 3.2 with a clear message. The native BSD utilities work: `base64`, `stat`, `md5`,
`readlink`. Local judging (`moj test --run`) does not run on macOS. The judge sandbox is Linux. Use
the remote flow: `moj publish`, `moj calibrate` and `moj check`.

## Token privacy

The session token does not appear in `ps`. The `curl` commands authenticate with
`-H @~/.config/moj/hdr-<contest>`. The login creates this file with permission 600. Old sessions get
the file on the first call. On a shared machine, another user sees only the file path. They never see
the token.

## Raw output (`--json`)

`moj --json <ls|board|status|check|calib|calibrate|testrun|testrun-status|log|restore> …` prints the
API response without formatting. Use it in scripts. In `moj-contest`, the global `--json` flag works
the same way.

## Glossary

| Term | Meaning |
|---|---|
| **contest** | an exam or list with a window, problems and accounts. It has a lowercase id, which becomes the subdomain |
| **problem** | a package with statement, tests and solutions. It has an id `<org>#<prob>` |
| **package** | the problem directory, with the files listed above |
| **org** | who edits a problem. It is the id prefix. An org is private by default |
| **collection** | a grouping label for problems. A problem can have several collections |
| **verdict** | the result of a submission: `Accepted`, `Wrong Answer`, `Time Limit Exceeded` and others |
| **TL** | time limit: the maximum run time per test. The judge measures the TL during calibration |
| **calibration** | the judge runs the `good` solutions and measures the TL per machine and per language |
| **judge** | the machine that compiles and runs the submissions |
| **scoreboard** | the ranking of the contest teams |
| **site** | the physical location of a multi-site contest. In MOJ, a site is a name and a regex on the login |
| **module** | a group of contest features, turned on by the admin |
| **round** | a stage of the contest with its own window and problems: warm-up, official contest |
| **token** | the session credential, stored in `~/.config/moj/` |
| **spec** | the JSON that describes a contest for `create`, `export` and the templates |
