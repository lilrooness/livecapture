defmodule RtcServer.DTLS do
  @behaviour GenServer

  require Logger

  defstruct [
    :ssl_socket
  ]

  def expect_dtls_client_hello(sup_pid, dtls_port) do
    :ssl.start()
    Task.async(fn -> wait_and_handshake(dtls_port, sup_pid) end)
  end

  defp wait_and_handshake(port, sup_pid) do
    {:ok, listen_socket} =
      :ssl.listen(
        port,
        [
          protocol: :dtls,
          certfile: 'priv/localhost.crt',
          keyfile: 'priv/localhost.key',
          verify_fun: get_custom_verify_fun_option()
        ] ++ [:binary]
      )

    Logger.info("LISTENING FOR DTLS CONNECTIONS")
    {:ok, handshake_socket} = :ssl.transport_accept(listen_socket)
    Logger.info("RECEIVED CLIENT HELLO - continuing handshake ...")
    {:ok, ssl_socket} = :ssl.handshake(handshake_socket)

    Supervisor.start_child(sup_pid, {__MODULE__, ssl_socket})

    Logger.info("COMPLETED DTLS HANDSHAKE")
  end

  defp get_custom_verify_fun_option() do
    fn
      _, {:bad_cert, :selfsigned_peer}, UserState ->
        # Allow self-signed certificates from client
        {:valid, UserState}

      _, {:bad_cert, _} = Reason, _ ->
        {:fail, Reason}

      _, {:extension, _}, UserState ->
        {:unknown, UserState}

      _, :valid, UserState ->
        {:valid, UserState}

      _, :valid_peer, UserState ->
        {:valid, UserState}
    end
  end

  @impl true
  def start_link(ssl_socket) do
    GenServer.start(__MODULE__, ssl_socket)
  end

  @impl true
  def init(ssl_socket) do
    :ssl.controlling_process(ssl_socket, self())
    {:ok, %__MODULE__{ssl_socket: ssl_socket}}
  end

  @impl true
  def handle_info(
        {:ssl, _socket,
         <<source_port::integer-size(16), dst_port::integer-size(16), veri_tag::integer-size(32),
           checksum::integer-size(32), type::integer-size(8), _not_read::integer-size(8),
           length::integer-size(16), tsn::integer-size(32), stream_id::integer-size(16),
           stream_sq_num::integer-size(16), ppid::integer-size(32), payload::binary>> = data},
        state
      ) do
    %{
      source_port: source_port,
      dst_port: dst_port,
      veri_tag: veri_tag,
      checksum: checksum,
      type: type,
      length: length,
      tsn: tsn,
      stream_id: stream_id,
      stream_sq_num: stream_sq_num,
      ppid: ppid,
      payload: payload
    }
    |> IO.inspect()

    {:noreply, state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    Logger.warn("RECEIVED NON SRTP-PACKET")
    {:noreply, state}
  end

  @impl true
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
