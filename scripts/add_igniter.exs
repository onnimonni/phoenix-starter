# Bootstraps igniter into a fresh Phoenix project by injecting it into mix.exs deps.
# No dependencies required -- just basic string replacement.
# Run with: elixir /path/to/add_igniter.exs

source = File.read!("mix.exs")

patched =
  String.replace(
    source,
    "{:phoenix,",
    ~s|{:igniter, "~> 0.5", only: :dev, runtime: false},\n      {:phoenix,|,
    global: false
  )

if patched == source do
  IO.puts(:stderr, "error: could not find {:phoenix, in mix.exs")
  System.halt(1)
end

File.write!("mix.exs", patched)
IO.puts("Added igniter dep to mix.exs")
