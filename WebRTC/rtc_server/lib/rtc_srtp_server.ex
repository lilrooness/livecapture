defmodule RtcServer.SRTP.Server do
  use GenServer

  defstruct [:listen_socket]

  @cb_info {RtcServer.SRTPTransportLayer, :udp, :udp_closed, :udp_error}

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ssl.start()

    {:ok, listen_socket} = get_listen_socket()
    async_wait_for_connection(listen_socket)

    {:ok, %__MODULE__{listen_socket: listen_socket}}
  end

  def handle_cast({:new_dtls_connection, ssl_socket}, state) do
    {:ok, ssl_hs_socket, _ext} = :ssl.handshake(ssl_socket, handshake: :hello)
    {:ok, new_ssl_socket} = :ssl.handshake_continue(ssl_hs_socket, cb_info: @cb_info)

    # {:ok, peer_certificate} = :ssl.peercert(new_ssl_socket)

    {:ok, master_secret: master_secret} =
      :ssl.connection_information(new_ssl_socket, [:master_secret])

    RtcServer.SRTPTransportLayer.set_master_secret(master_secret)

    # %{
    #   tbsCertificate: %{
    #     subjectPublicKeyInfo: %{
    #       subjectPublicKey: peer_public_key,
    #       algorithm: %{
    #         algorithm: _algo,
    #         parameters: _public_key_params
    #       }
    #     }
    #   }
    # } = :public_key.pkix_decode_cert(peer_certificate, :plain)

    async_wait_for_connection(state.listen_socket)
    {:noreply, state}
  end

  defp get_listen_socket() do
    :ssl.listen(
      9999,
      certfile: 'priv/CertAndPrivate.pem',
      keyfile: 'priv/PrivateKey.key',
      reuseaddr: true,
      protocol: :dtls
    )
  end

  defp async_wait_for_connection(listen_socket) do
    spawn_link(fn ->
      {:ok, ssl_socket} = :ssl.transport_accept(listen_socket)
      GenServer.cast(__MODULE__, {:new_dtls_connection, ssl_socket})
    end)
  end
end
