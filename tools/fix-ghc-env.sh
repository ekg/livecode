#!/bin/sh
# Fix the GHC 9.10.3 package environment after `cabal install --lib`.
#
# Why this exists: `cabal install --lib` writes
#   ~/.ghc/x86_64-linux-9.10.3/environments/default
# with `clear-package-db` and lists ONLY tidal + base. That hides every other
# boot library from ghci (containers, mtl, text, ...), so `import Data.Map.Strict`
# fails in the REPL and in pi-tidal's Tidal-command tests. The old 9.4.7 env
# (made by an older cabal) listed the boot set; we reproduce that shape here.
#
# Idempotent: re-run after any `cabal install --lib`. Replaces the generated env
# with boot libraries (real unit ids, including the -inplace suffix) + tidal.
set -eu
GHC_VER=$(ghc --numeric-version)
# ghc --print-platform is not a valid flag; derive the <arch>-<ver> directory
# from the one ghc-pkg/ghc actually use (e.g. x86_64-linux-9.10.3).
ARCH_VER=$(basename "$(ls -d "$HOME/.ghc"/*-"$GHC_VER" 2>/dev/null | head -1)")
if [ -z "$ARCH_VER" ]; then
	ARCH_VER="$(uname -m)-linux-$GHC_VER"
fi
ENV_DIR="$HOME/.ghc/$ARCH_VER/environments"
ENV_FILE="$ENV_DIR/default"
STORE_DB="$HOME/.cabal/store/ghc-$GHC_VER-inplace/package.db"
TID=$(ghc-pkg --package-db "$STORE_DB" field tidal id 2>/dev/null | sed -n 's/^id: //p' | head -1)
if [ -z "$TID" ]; then
	echo "fix-ghc-env: no tidal registered in $STORE_DB" >&2
	exit 1
fi
mkdir -p "$ENV_DIR"
{
	echo "clear-package-db"
	echo "global-package-db"
	echo "package-db $STORE_DB"
	for p in $(ghc-pkg list --global --simple-output); do
		ghc-pkg field "$p" id 2>/dev/null | sed -n 's/^id: /package-id /p'
	done
	echo "package-id $TID"
} > "$ENV_FILE"
echo "fix-ghc-env: wrote $ENV_FILE ($(wc -l < "$ENV_FILE") lines; $TID)"
