{ pkgs, lib, config, inputs, ... }:

let
  beamPkgs = pkgs.beam.packages.erlang_28;
in
{
  packages = [
    pkgs.git
    pkgs.jq
    inputs.expert.packages.${pkgs.stdenv.system}.default
  ];

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

    # FIXME: Move worktree hooks into claude.code.hooks once devenv supports
    # WorktreeCreate/WorktreeRemove hookTypes, then delete .claude/hooks/ scripts
    # and this enterShell block. PR: https://github.com/cachix/devenv/pull/2523
    mkdir -p .claude
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
  git-hooks.hooks = {
    mix-format.enable = true;
    mix-compile-warnings = {
      enable = true;
      name = "mix compile --warnings-as-errors";
      entry = "mix compile --warnings-as-errors";
      files = "\\.ex$";
      language = "system";
      pass_filenames = false;
    };
    mix-credo-strict = {
      enable = true;
      name = "mix credo --strict";
      entry = "mix credo --strict";
      files = "\\.(ex|exs)$";
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

    missing-impl = {
      enable = true;
      name = "Block callbacks without @impl true";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        FILTERED=$(grep -v '^\s*#' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null)
        if echo "$FILTERED" | grep -qE 'def\s+(mount|handle_event|handle_info|handle_call|handle_cast|render|init|terminate)\(' && \
           ! echo "$FILTERED" | grep -B1 'def\s+(mount|handle_event|handle_info|handle_call|handle_cast|render|init|terminate)\(' | grep -q '@impl'; then
          echo "Missing @impl true before callback function." && exit 2
        fi
      '';
    };

    hardcoded-paths = {
      enable = true;
      name = "Block hardcoded file paths";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        if grep -qE '(upload_path|file_path|uploads_dir)\s*=\s*["'"'"'](/|priv/)' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo "Hardcoded file path detected. Use Application.get_env(:app, :config_key) instead." && exit 2
        fi
      '';
    };

    hardcoded-sizes = {
      enable = true;
      name = "Block hardcoded file size limits";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        if grep -qE '(max_file_size|file_size_limit|max_upload|max_size)\s*=\s*[0-9]{7,}' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo "Hardcoded file size limit detected. Move to Application config." && exit 2
        fi
      '';
    };

    static-paths-validator = {
      enable = true;
      name = "Validate static_paths references";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        if grep -qE 'def static_paths' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          PATHS=$(grep -A10 'def static_paths' "$CLAUDE_HOOK_FILE_PATH" | grep -oE '"[^"]+"' | tr -d '"' | tr '\n' ' ')
          REFS=$(grep -hoE '/[a-z_]+/' "$CLAUDE_HOOK_FILE_PATH" | sort -u | tr -d '/' | tr '\n' ' ')
          for ref in $REFS; do
            echo " $PATHS " | grep -qw "$ref" || { echo "Path '/$ref/' not in static_paths()." && exit 2; }
          done
        fi
      '';
    };

    deprecated-components = {
      enable = true;
      name = "Block deprecated Phoenix components";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        if grep -qE '<\.(flash_group|flash)' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo ".flash_group is deprecated in Phoenix 1.8+. Remove it." && exit 2
        fi
        if grep -qE 'form_for\(' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo "form_for is deprecated. Use <.form for={to_form(@changeset)}>." && exit 2
        fi
        if grep -qE 'live_redirect|live_patch' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo "live_redirect/live_patch deprecated. Use <.link navigate={path}>." && exit 2
        fi
      '';
    };

    nested-if-else = {
      enable = true;
      name = "Warn about nested if/else";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        COLLAPSED=$(tr '\n' ' ' < "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null)
        if echo "$COLLAPSED" | grep -qE 'if\s+[^d]+\s+do\s+[^e]*if\s+[^d]+\s+do'; then
          echo "Nested if/else detected. Use pattern matching or case." && exit 1
        fi
      '';
    };

    inefficient-enum = {
      enable = true;
      name = "Warn about chained Enum operations";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        COLLAPSED=$(tr '\n' ' ' < "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null)
        if echo "$COLLAPSED" | grep -qE '\|>\s*Enum\.(map|filter)\([^)]+\)\s*\|>\s*Enum\.(map|filter)\('; then
          echo "Chained Enum ops detected. Use for comprehension or Enum.reduce." && exit 1
        fi
      '';
    };

    string-concatenation = {
      enable = true;
      name = "Warn about string concat in Enum";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        if grep -qE 'Enum\.(map|reduce|each).*<>' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo "String <> in Enum ops. Use IO lists or Enum.join." && exit 1
        fi
      '';
    };

    auto-upload-warning = {
      enable = true;
      name = "Warn about auto_upload: true";
      hookType = "PreToolUse";
      matcher = "^(Write|Edit)$";
      command = ''
        if grep -qE 'auto_upload:\s*true' "$CLAUDE_HOOK_FILE_PATH" 2>/dev/null; then
          echo "auto_upload: true requires handle_progress/3. Most apps should use manual upload." && exit 1
        fi
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
  };

  enterTest = ''
    elixir --version
    mix --version
  '';
}
