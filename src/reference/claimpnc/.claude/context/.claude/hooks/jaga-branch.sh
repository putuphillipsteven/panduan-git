#!/usr/bin/env bash
# Hook PreToolUse Claude Code — menegakkan aturan branch di WORKSPACE.md:
#   1. Claude dilarang membuat branch sendiri (checkout -b, switch -c,
#      branch <nama>, worktree add, tool EnterWorktree).
#   2. Repo yang sedang di branch `dev` atau `dev-backup-*` tidak boleh diubah
#      (edit berkas maupun perintah git yang mengubah repo). Developer yang
#      memindahkan branch secara manual.
#
# Dipasang di .claude/settings.json folder induk; cara pasang:
# docs/panduan-clone-repository.md §3a.
#
# Masukan: JSON dari Claude Code di stdin. Exit 2 = tool dibatalkan dan pesan
# di stderr diteruskan ke Claude. Exit 0 = lanjut.
# Hanya memakai bash, grep, sed, git (tersedia di Git for Windows; tanpa jq).

input=$(cat)

# Ambil nilai string medan JSON pertama bernama $1 (tanpa unescape).
ambil_medan() {
  printf '%s' "$input" |
    grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" |
    head -n 1 |
    sed -E "s/^\"$1\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//"
}

# Unescape string JSON secukupnya: \n, \t, \", \\.
unescape() {
  printf '%s' "$1" | sed -E 's/\\n/\n/g; s/\\t/ /g; s/\\"/"/g; s/\\\\/\\/g'
}

tolak() {
  printf '%s\n' "$1" >&2
  exit 2
}

# Branch aktif repo yang memuat direktori $1; kosong bila bukan repo git.
branch_di() {
  git -C "$1" branch --show-current 2>/dev/null
}

branch_terlarang() {
  case "$1" in
    dev | dev-backup-*) return 0 ;;
  esac
  return 1
}

pesan_branch_terlarang() {
  # $1 = direktori repo, $2 = branch
  local akar
  akar=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)
  tolak "BHAP!!!: repo $(basename "${akar:-$1}") lagi di branch '$2'. Jangan kerjakan apapun di branch ini. Infokan developer agar pindah ke branch kerja secara manual, lalu lanjutkan setelah developer mengonfirmasi."
}

tool=$(ambil_medan tool_name)

# ---------------------------------------------------------------------------
# EnterWorktree selalu membuat branch baru.
# ---------------------------------------------------------------------------
if [ "$tool" = "EnterWorktree" ]; then
  tolak "BHAP!!!: Claude dilarang membuat branch sendiri, termasuk lewat worktree. Kerjakan di branch yang sedang aktif, atau minta developer membuat/memilihkan branch."
fi

# ---------------------------------------------------------------------------
# Edit berkas: cek branch repo tempat berkas berada.
# ---------------------------------------------------------------------------
case "$tool" in
  Edit | Write | MultiEdit | NotebookEdit)
    jalur=$(ambil_medan file_path)
    [ -z "$jalur" ] && jalur=$(ambil_medan notebook_path)
    [ -z "$jalur" ] && exit 0
    jalur=$(unescape "$jalur" | tr '\\' '/')
    dir=$(dirname "$jalur")
    # Berkas baru: naik sampai ketemu direktori yang ada.
    while [ ! -d "$dir" ] && [ "$dir" != "$(dirname "$dir")" ]; do
      dir=$(dirname "$dir")
    done
    br=$(branch_di "$dir")
    if branch_terlarang "$br"; then
      pesan_branch_terlarang "$dir" "$br"
    fi
    exit 0
    ;;
  Bash | PowerShell) ;;
  *) exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Perintah shell: periksa setiap perintah git di dalamnya.
# ---------------------------------------------------------------------------
perintah=$(unescape "$(ambil_medan command)")
cwd=$(unescape "$(ambil_medan cwd)" | tr '\\' '/')
[ -z "$cwd" ] && cwd=$PWD

# Subperintah git yang mengubah repo — ditolak bila repo di dev/dev-backup-*.
ubah_repo=" add am apply checkout cherry-pick clean commit merge mv pull push rebase reset restore revert rm stash switch "

# Opsi `git branch` yang tidak membuat branch.
branch_aman=" -d -D --delete -a --all -r --remotes -l --list --show-current -v -vv --verbose --contains --no-contains --merged --no-merged --points-at --format --sort -u --set-upstream-to --unset-upstream --edit-description --column --no-column --color --no-color -i --ignore-case "

# Pecah per perintah pada && || ; | dan baris baru.
segmen=$(printf '%s\n' "$perintah" | sed -E 's/(&&|\|\||;|\|)/\n/g')

while IFS= read -r baris; do
  # Token dipisah spasi; tanda kutip dibuang (cukup untuk jalur tanpa spasi).
  read -ra tok <<<"$(printf '%s' "$baris" | tr -d "\"'")"
  n=${#tok[@]}
  i=0
  # Cari token `git` / `git.exe`.
  while [ $i -lt $n ]; do
    case "${tok[$i]##*/}" in git | git.exe) break ;; esac
    i=$((i + 1))
  done
  [ $i -ge $n ] && continue
  i=$((i + 1))

  # Lewati opsi global git; catat -C.
  repo_dir=$cwd
  while [ $i -lt $n ]; do
    case "${tok[$i]}" in
      -C)
        i=$((i + 1))
        case "${tok[$i]}" in
          /* | [A-Za-z]:*) repo_dir=${tok[$i]} ;;
          *) repo_dir="$cwd/${tok[$i]}" ;;
        esac
        repo_dir=$(printf '%s' "$repo_dir" | tr '\\' '/')
        ;;
      -c) i=$((i + 1)) ;;
      -*) ;;
      *) break ;;
    esac
    i=$((i + 1))
  done
  [ $i -ge $n ] && continue
  sub=${tok[$i]}
  arg=("${tok[@]:$((i + 1))}")
  argstr=" ${arg[*]} "

  # Larangan 1: membuat branch.
  buat=0
  case "$sub" in
    checkout)
      case "$argstr" in *" -b "* | *" -B "* | *" --orphan "*) buat=1 ;; esac
      ;;
    switch)
      case "$argstr" in *" -c "* | *" -C "* | *" --create "* | *" --force-create "* | *" --orphan "*) buat=1 ;; esac
      ;;
    worktree)
      [ "${arg[0]}" = "add" ] && buat=1
      ;;
    branch)
      aman=0
      ada_nama=0
      for a in "${arg[@]}"; do
        case "$branch_aman" in *" ${a%%=*} "*) aman=1 ;; esac
        case "$a" in -*) ;; *) ada_nama=1 ;; esac
      done
      [ $aman -eq 0 ] && [ $ada_nama -eq 1 ] && buat=1
      ;;
  esac
  if [ $buat -eq 1 ]; then
    tolak "BHAP!!!: Claude tak boleh membuat branch sendiri (git $sub ${arg[*]}). Kerjakan di branch yang sedang aktif, atau minta developer membuat/memilihkan branch."
  fi

  # Larangan 2: mengubah repo yang sedang di dev / dev-backup-*.
  case "$ubah_repo" in
    *" $sub "*)
      br=$(branch_di "$repo_dir")
      if branch_terlarang "$br"; then
        pesan_branch_terlarang "$repo_dir" "$br"
      fi
      ;;
  esac
done <<<"$segmen"

exit 0
