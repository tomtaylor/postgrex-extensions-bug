Mix.install([
  {:ecto_sql, "3.8.3"},
  {:postgrex, "0.16.4"}
])

Application.put_env(:app, Repo, database: "postgres_extensions_bug")

query_args = ["SET search_path TO public,heroku_ext", []]

defmodule Repo do
  use Ecto.Repo,
    adapter: Ecto.Adapters.Postgres,
    otp_app: :app,
    after_connect: {Postgrex, :query!, query_args}
end

defmodule Migration0 do
  use Ecto.Migration

  def up do
    execute("CREATE SCHEMA heroku_ext")
    execute("CREATE EXTENSION citext WITH SCHEMA heroku_ext")
  end
end

defmodule Migration1 do
  use Ecto.Migration

  def up do
    execute("SET search_path = public,heroku_ext")

    create table(:users) do
      add(:email, :citext, null: false)
    end
  end
end

defmodule User do
  use Ecto.Schema

  schema "users" do
    field(:email, :string)
  end
end

defmodule Main do
  def main() do
    children = [
      Repo
    ]

    _ = Repo.__adapter__().storage_down(Repo.config())
    :ok = Repo.__adapter__().storage_up(Repo.config())

    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    Ecto.Migrator.run(Repo, [{0, Migration0}, {1, Migration1}], :up,
      all: true,
      log_migrations_sql: :debug
    )

    %User{email: "foo@bar.com"}
    |> Repo.insert!()

    IO.inspect(Repo.all(User))
  end
end

Main.main()
