defmodule Hashpay.MixProject do
  use Mix.Project

  def project do
    [
      app: :hashpay,
      name: "Hashpay",
      description: "Cryptocurrency payment system",
      source_url: "https://github.com/casz92/hashpay",
      package: package(),
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Agregar configuración de releases
      releases: releases()
    ]
  end

  defp package do
    [
      maintainers: ["Carlos Suarez"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/casz92/hashpay"}
    ]
  end

  # Configuración para releases
  defp releases do
    [
      hashpay: [
        include_executables_for: [:unix, :windows],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Hashpay.Application, []},
      extra_applications: [
        :logger,
        :crypto,
        :xandra,
        :broadway,
        :poolboy,
        :runtime_tools,
        :bandit,
        :plug,
        :websock,
        :websock_adapter
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Cafezinho - Biblioteca para criptografía
      {:cafezinho, "~> 0.4.2"},

      # CBOR - Concise Binary Object Representation
      {:cbor, "~> 1.0.1"},

      # Jason - Parser y generador de JSON
      {:jason, "~> 1.4"},

      # ScyllaDB/Cassandra driver
      # Driver para ScyllaDB/Cassandra
      {:xandra, "~> 0.19.2"},
      # Requerido por Xandra
      {:decimal, "~> 2.1"},

      # Broadway - Procesamiento de datos concurrente
      {:broadway, "~> 1.2.1"},

      # Poolboy - Gestión de pool de procesos
      {:poolboy, "~> 1.5.2"},

      # Bandit - Servidor HTTP/HTTPS
      {:bandit, "~> 1.6"},

      # Plug - Framework para aplicaciones web
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.6"},

      # X509 - Para generar certificados SSL
      {:x509, "~> 0.8"},

      # WebSock - Abstracción para WebSockets
      {:websock, "~> 0.5"},
      {:websock_adapter, "~> 0.5.3"},

      # UUID - Generación de identificadores únicos
      {:uuid, "~> 1.1"},

      # totp - Time-based One-Time Password
      {:nimble_totp, "~> 1.0"},

      # Phoenix PubSub - Sistema de publicación/suscripción
      {:phoenix_pubsub, "~> 2.1"},

      # ExAws - Cliente para AWS
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.5"},
      {:poison, "~> 3.0"},
      {:hackney, "~> 1.9"},
      # Fresh - Cliente para WebSockets
      {:websocket_client, "~> 1.0"},
      {:download, "~> 0.0.4"}
    ]
  end
end
