#!/usr/bin/env -S just --working-directory . --justfile

set dotenv-load
set export

@default:
  just --list

@_run script *args='':
	bash ./scripts/{{script}}.sh {{args}}

@init: (_run "init" '')

@clean: (_run "clean" '')

@apply: (_run "apply" '')

@flash: (_run "flash" '')
