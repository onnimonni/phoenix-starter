{
  description = "Phoenix + Claude Code devenv template";

  outputs = { self }: {
    templates.default = {
      path = ./templates/default;
      description = "Elixir + Phoenix with devenv, Expert LSP, and Claude Code";
    };
  };
}
