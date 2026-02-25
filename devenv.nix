{ pkgs, lib, config, inputs, ... }:

let
  beamPkgs = pkgs.beam.packages.erlang_28;
  src = ./.;
in
{
  packages = [
    pkgs.git
    pkgs.jq
    inputs.expert.packages.${pkgs.stdenv.system}.default
  ];

  # Upstream credo checks path for consumer .credo.exs
  env.PHOENIX_STARTER_PATH = builtins.toString src;

  # Default database names (overridden per-worktree via .claude/settings.local.json)
  env.DATABASE_DEV = "app_dev";
  env.DATABASE_TEST = "app_test";

  languages.elixir = {
    enable = true;
    package = beamPkgs.elixir_1_20;
    lsp.enable = false; # Expert LSP added via packages
  };

  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialDatabases = [{ name = "app_dev"; } { name = "app_test"; }];
  };

  enterShell = ''
    elixir --version

    # Distribute upstream skills and hooks to consumer project
    mkdir -p .claude/skills .claude/hooks
    cp -r ${src}/.claude/skills/* .claude/skills/ 2>/dev/null || true
    cp -r ${src}/.claude/hooks/* .claude/hooks/ 2>/dev/null || true
    chmod +x .claude/hooks/*.sh 2>/dev/null || true

    # FIXME: Move worktree hooks into claude.code.hooks once devenv supports
    # WorktreeCreate/WorktreeRemove hookTypes, then delete .claude/hooks/ scripts
    # and this enterShell block. PR: https://github.com/cachix/devenv/pull/2523
    cat > .claude/settings.local.json <<SETTINGS
    {
      "hooks": {
        "WorktreeCreate": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "$DEVENV_ROOT/.claude/hooks/worktree-create.sh"
              }
            ]
          }
        ],
        "WorktreeRemove": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "$DEVENV_ROOT/.claude/hooks/worktree-remove.sh"
              }
            ]
          }
        ]
      }
    }
    SETTINGS
  '';

  # Git pre-commit hooks
  # All hooks skip gracefully when mix or mix.exs is absent (template repo has no mix project)
  git-hooks.hooks = {
    mix-format = {
      enable = true;
      name = "mix format";
      entry = "bash -c 'command -v mix &>/dev/null && test -f mix.exs || exit 0; mix format'";
      files = "\\.(ex|exs)$";
      language = "system";
      pass_filenames = false;
    };
    mix-compile-warnings = {
      enable = true;
      name = "mix compile --warnings-as-errors";
      entry = "bash -c 'command -v mix &>/dev/null && test -f mix.exs || exit 0; mix compile --warnings-as-errors'";
      files = "\\.ex$";
      language = "system";
      pass_filenames = false;
    };
    mix-credo-strict = {
      enable = true;
      name = "mix credo --strict";
      entry = "bash -c 'command -v mix &>/dev/null && test -f mix.exs || exit 0; mix help credo &>/dev/null && mix credo --strict || true'";
      files = "\\.(ex|exs)$";
      language = "system";
      pass_filenames = false;
    };
    mix-sobelow = {
      enable = true;
      name = "mix sobelow --exit";
      entry = "bash -c 'command -v mix &>/dev/null && test -f mix.exs || exit 0; mix help sobelow &>/dev/null && mix sobelow --exit || true'";
      files = "\\.ex$";
      language = "system";
      pass_filenames = false;
    };
  };

  # Claude Code integration
  claude.code.enable = true;

  claude.code.hooks = {

    # === PostToolUse: auto-fix after edits ===

    format-elixir = {
      enable = true;
      name = "Auto-format Elixir files";
      hookType = "PostToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // .filePath // empty')
        if [[ "$file_path" == *.ex || "$file_path" == *.exs ]]; then
          if [ -f "$file_path" ]; then
            dir=$(dirname "$file_path")
            while [[ "$dir" != "/" ]]; do
              if [[ -f "$dir/mix.exs" ]]; then
                cd "$dir"
                mix format "$file_path" 2>&1 && echo "Formatted: $file_path"
                break
              fi
              dir=$(dirname "$dir")
            done
          fi
        fi
      '';
    };

    compile-elixir = {
      enable = true;
      name = "Compile with warnings-as-errors";
      hookType = "PostToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // .filePath // empty')
        if [[ "$file_path" == *.ex ]]; then
          if [ -f "$file_path" ]; then
            dir=$(dirname "$file_path")
            while [[ "$dir" != "/" ]]; do
              if [[ -f "$dir/mix.exs" ]]; then
                cd "$dir"
                project_dir=$(pwd -P)
                if lsof -c beam.smp -a -d cwd 2>/dev/null | grep -q "$project_dir"; then
                  echo "BEAM running - skipping compile"
                  exit 0
                fi
                mix compile --warnings-as-errors 2>&1
                break
              fi
              dir=$(dirname "$dir")
            done
          fi
        fi
      '';
    };

    credo-elixir = {
      enable = true;
      name = "Run credo analysis";
      hookType = "PostToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // .filePath // empty')
        if [[ "$file_path" == *.ex || "$file_path" == *.exs ]]; then
          if [ -f "$file_path" ]; then
            dir=$(dirname "$file_path")
            while [[ "$dir" != "/" ]]; do
              if [[ -f "$dir/mix.exs" ]]; then
                cd "$dir"
                mix help credo &>/dev/null || exit 0
                mix credo "$file_path" 2>&1
                break
              fi
              dir=$(dirname "$dir")
            done
          fi
        fi
      '';
    };

    sobelow-elixir = {
      enable = true;
      name = "Run sobelow security scan";
      hookType = "PostToolUse";
      matcher = "^(Edit|MultiEdit|Write)$";
      command = ''
        json=$(cat)
        file_path=$(echo "$json" | jq -r '.file_path // .filePath // empty')
        if [[ "$file_path" == *.ex ]]; then
          if [ -f "$file_path" ]; then
            dir=$(dirname "$file_path")
            while [[ "$dir" != "/" ]]; do
              if [[ -f "$dir/mix.exs" ]]; then
                cd "$dir"
                mix help sobelow &>/dev/null || exit 0
                mix sobelow --exit 2>&1
                break
              fi
              dir=$(dirname "$dir")
            done
          fi
        fi
      '';
    };

    # === PreToolUse: validate before edits ===

    skill-reminder = {
      enable = true;
      name = "Remind to invoke Elixir skill";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        EXT="''${CLAUDE_HOOK_FILE_PATH##*.}"
        if [ "$EXT" = "ex" ] || [ "$EXT" = "exs" ] || [ "$EXT" = "heex" ]; then
          echo "Reminder: invoke the relevant Elixir skill before writing this file."
        fi
        exit 0
      '';
    };

  };

  claude.code.commands = {
    test = ''
      Run the Elixir test suite.
      ```bash
      mix test
      ```
    '';
    format = ''
      Format all Elixir files.
      ```bash
      mix format
      ```
    '';
    credo = ''
      Run static analysis with Credo.
      ```bash
      mix credo --strict
      ```
    '';
    sobelow = ''
      Run Sobelow security analysis.
      ```bash
      mix sobelow --exit
      ```
    '';
  };

  enterTest = ''
    elixir --version
    mix --version
  '';
}
