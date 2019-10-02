defmodule RtcServer.SRTP.Server do
  use GenServer

  defstruct [:listen_socket]

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
    :ok = :ssl.ssl_accept(ssl_socket)
    RtcServer.Dtls.Session.start_link(ssl_socket)
    async_wait_for_connection(state.listen_socket)
    {:noreply, state}
  end

  defp get_listen_socket() do
    :ssl.listen(9999,
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
