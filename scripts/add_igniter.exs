# Bootstraps igniter + dev deps into a fresh Phoenix project by injecting into mix.exs.
# No dependencies required -- just basic string replacement.
# Run with: elixir /path/to/add_igniter.exs

source = File.read!("mix.exs")

extra_deps =
  ~s|{:igniter, "~> 0.5", only: :dev, runtime: false},\n      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},\n      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},\n      {:phoenix,|

patched = String.replace(source, "{:phoenix,", extra_deps, global: false)

if patched == source do
  IO.puts(:stderr, "error: could not find {:phoenix, in mix.exs")
  System.halt(1)
end

File.write!("mix.exs", patched)
IO.puts("Added igniter, credo, sobelow deps to mix.exs")
