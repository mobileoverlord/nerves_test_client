defmodule NervesTestClient.Runner do
  use GenServer

  alias PhoenixClient.{Socket, Channel, Message}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    socket = opts[:socket]
    tag = opts[:tag]
    serial = opts[:serial]

    {:ok, %{
      tag: tag,
      socket: socket,
      channel: nil,
      test_path: opts[:test_path],
      test_results: nil,
      test_io: nil,
      serial: serial,
      fw_metadata: opts[:fw_metadata]
    }, {:continue, nil}}
  end

  def handle_continue(nil, s) do
    {:ok, {test_io, test_results}} = ExUnitRelease.run(path: s.test_path)
    send(self(), :connect)
    {:noreply, %{s | test_results: test_results, test_io: test_io}}
  end

  # If the remote socket closes, send a message to reconnect
  def handle_info(%Message{event: event}, s) when event in ["phx_error", "phx_close"] do
    send(self(), :connect)
    {:noreply, s}
  end

  def handle_info(:connect, s) do
    s =
      if Socket.connected?(s.socket) do
        case Channel.join(s.socket, "device:" <> s.serial, join_params(s)) do
          {:ok, _reply, channel} ->
            # NervesWatchdog.validate()
            %{s | channel: channel}

          _error ->
            Process.send_after(self(), :connect, 1_000)
            s
        end
      else
        Process.send_after(self(), :connect, 1_000)
        s
      end
    {:noreply, s}
  end

  defp join_params(s) do
    %{
      tag: s.tag,
      fw_metadata: s.fw_metadata,
      test_results: s.test_results,
      test_io: s.test_io
    }
  end
end
