# Zot

A schema parser and validator libary for Elixir.

```elixir
alias Zot, as: Z

@schema Z.map(%{
          name: Z.string(trim: true, min: 1),
          email: Z.email()
        })

def create(%Plug.Conn{} = conn, _) do
  with {:ok, params} <- Z.parse(@schema, conn.body_params),
       {:ok, user} <- MyApp.create_user(params),
       do: render(conn, :show, user: user)
end
```

## Installation

Add `zot` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:zot, "~> 0.1"}]
end
```
