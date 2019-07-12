defmodule NervesTestClient.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do

    nerves_hub_socket_opts = nerves_hub_socket_opts()

    test_server_socket_opts =
    nerves_hub_socket_opts
    |> NervesHub.Socket.opts()
    |> Keyword.merge(Application.get_env(:nerves_test_client, :socket))

    children = [
      {PhoenixClient.Socket, {test_server_socket_opts, name: NervesTestClient.Socket}},
      {NervesHub.Supervisor, nerves_hub_socket_opts},
      NervesTestClient.Runner
    ]
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesTestClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp nerves_hub_socket_opts() do
    {:ok, engine} = NervesKey.PKCS11.load_engine()
    {:ok, i2c} = ATECC508A.Transport.I2C.init([])
    if NervesKey.detected?(i2c) and NervesKey.has_aux_certificates?(i2c) do
      cert =
      NervesKey.device_cert(i2c, :aux)
      |> X509.Certificate.to_der()

      signer_cert =
        NervesKey.signer_cert(i2c, :aux)
        |> X509.Certificate.to_der()

      key = NervesKey.PKCS11.private_key(engine, i2c: 1)
      cacerts = [signer_cert | NervesHub.Certificate.ca_certs()]

      [key: key, cert: cert, cacerts: cacerts]
    else
      []
    end
  end
end
