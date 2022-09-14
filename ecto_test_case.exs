Mix.install([
  {:ecto_sql, "3.8.3"},
  {:postgrex, "0.16.4"}
])

defmodule Repo do
  use Ecto.Repo,
    adapter: Ecto.Adapters.Postgres,
    otp_app: :app
end

defmodule Migration0 do
  use Ecto.Migration

  def up do
    username =
      System.cmd("whoami", [])
      |> case do
        {username, 0} -> String.trim(username)
        _ -> raise "Could not get system username"
      end

    execute("CREATE SCHEMA heroku_ext")
    execute("CREATE EXTENSION citext WITH SCHEMA heroku_ext")
    execute("ALTER USER #{username} SET search_path = public, heroku_ext")
  end
end

defmodule Migration1 do
  use Ecto.Migration

  def up do
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
    Application.put_env(:app, Repo, database: "postgres_extensions_bug")

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

    Repo.all(User)
    |> IO.inspect()
  end
end

Main.main()
