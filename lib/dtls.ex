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

    {:ok, [master_secret: master_secret]} =
      :ssl.connection_information(ssl_socket, [:master_secret])

    Supervisor.start_child(sup_pid, {__MODULE__, ssl_socket})

    {RtcServer.MuxerDemuxer, pid, :worker, _} =
      Supervisor.which_children(sup_pid)
      |> Enum.find(&(&1 |> Tuple.to_list() |> hd == RtcServer.MuxerDemuxer))
      |> IO.inspect()

    Supervisor.start_child(sup_pid, {RtcServer.SRTPReceiver, {pid, master_secret}})

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
    # {:ok, handle} = File.open!("debug_dump", [:write])
    {:ok, %__MODULE__{ssl_socket: ssl_socket}}
  end

  @impl true
  def handle_info(
        {:ssl, _socket,
         <<source_port::integer-size(16), dst_port::integer-size(16), veri_tag::integer-size(32),
           checksum::integer-size(32), type::integer-size(8), _not_read::integer-size(8),
           length::integer-size(16), initiate_tag::integer-size(32), window::integer-size(32),
           n_outbound_streams::integer-size(16), n_inbound_streams::integer-size(16),
           initial_tsn::integer-size(32), payload::binary>> = data},
        %__MODULE__{ssl_socket: ssl_socket} = state
      ) do
    IO.inspect(data, limit: :infinity)

    verify_sctp_packet(data)

    # debug_packet(debug_dump_file, data)
    SCTPDebugDump.log(data)

    response =
      %{
        window: window,
        source_port: source_port,
        dst_port: dst_port,
        veri_tag: veri_tag,
        checksum: checksum,
        type: type,
        length: length,
        initiate_tag: initiate_tag,
        initial_tsn: initial_tsn,
        n_outbound_streams: n_outbound_streams,
        n_inbound_streams: n_inbound_streams,
        payload: payload
      }
      |> IO.inspect()
      |> construct_sctp_init_ack()

    # debug_packet(debug_dump_file, response)
    SCTPDebugDump.log(response)
    :ssl.send(ssl_socket, response)

    {:noreply, state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    Logger.info("RECEIVED NON HANDLED-PACKET ...")
    IO.inspect(data |> Base.encode16())
    {:noreply, state}
  end

  def handle_info(something, state) do
    IO.inspect(something, label: "weird ...")
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

  defp verify_sctp_packet(
         <<source_port::integer-size(16), dst_port::integer-size(16), veri_tag::integer-size(32),
           checksum::integer-size(32), type::integer-size(8), not_read::integer-size(8),
           length::integer-size(16), initiate_tag::integer-size(32), window::integer-size(32),
           n_outbound_streams::integer-size(16), n_inbound_streams::integer-size(16),
           initial_tsn::integer-size(32), payload::binary>>
       ) do
    calculated_crc23c_checksum =
      CyclicRedundancyCheck.crc32c(
        <<source_port::integer-size(16), dst_port::integer-size(16), veri_tag::integer-size(32),
          0::integer-size(32), type::integer-size(8), not_read::integer-size(8),
          length::integer-size(16), initiate_tag::integer-size(32), window::integer-size(32),
          n_outbound_streams::integer-size(16), n_inbound_streams::integer-size(16),
          initial_tsn::integer-size(32), payload::binary>>
      )

    ^checksum = calculated_crc23c_checksum
  end

  defp construct_sctp_init_ack(
         %{
           window: window,
           source_port: source_port,
           dst_port: dst_port,
           veri_tag: _veri_tag,
           checksum: checksum,
           type: type,
           length: length,
           initiate_tag: initiate_tag,
           initial_tsn: initial_tsn,
           n_outbound_streams: n_outbound_streams,
           n_inbound_streams: n_inbound_streams,
           payload: payload
         } = _init_packet
       ) do
    cookie =
      <<0x00000EB0000010000011001100003614432325440000FFFF001100115CFE379F070007000000000000000000A285B13F1027000017CD8F1C11769B0455C0D0F22C3E7C3500010001000000000000000000050008C0A8AA3800050008C0A8AA08C0000004::integer-size(
          800
        )>>

    cookie_param = <<7::integer-size(16), byte_size(cookie) + 4::integer-size(16)>> <> cookie
    chunk_length = (20 + byte_size(cookie_param)) |> IO.inspect(label: "chunk length")

    response_outbound_streams = 1024
    response_inbound_streams = n_outbound_streams

    chunk =
      <<2::integer-size(8), 0::integer-size(8), chunk_length::integer-size(16),
        initiate_tag::integer-size(32), window::integer-size(32),
        response_outbound_streams::integer-size(16), response_inbound_streams::integer-size(16),
        initial_tsn::integer-size(32)>> <> cookie_param

    header_without_checksum =
      <<dst_port::integer-size(16), source_port::integer-size(16), initiate_tag::integer-size(32),
        0::integer-size(32)>>

    crc32c_checksum = CyclicRedundancyCheck.crc32c(header_without_checksum <> chunk)

    <<dst_port::integer-size(16), source_port::integer-size(16), initiate_tag::integer-size(32),
      crc32c_checksum::integer-size(32)>> <> chunk
  end
end
