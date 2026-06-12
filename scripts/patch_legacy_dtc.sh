#!/bin/bash
set -euo pipefail

patch_lexer() {
	local lexer="$1"

	if [ ! -f "$lexer" ]; then
		return 0
	fi

	if grep -q '^extern YYLTYPE yylloc;$' "$lexer"; then
		return 0
	fi

	sed -i 's/^YYLTYPE yylloc;$/extern YYLTYPE yylloc;/' "$lexer"
}

patch_lexer "$1"
