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
    {:ok, listen_socket} = :ssl.listen(port, protocol: :dtls)
    Logger.info("LISTENING FOR DTLS CONNECTIONS")
    {:ok, handshake_socket} = :ssl.transport_accept(listen_socket)
    Logger.info("RECEIVED CLIENT HELLO - continuing handshake ...")
    {:ok, ssl_socket} = :ssl.handshake(handshake_socket)

    Supervisor.start_child(sup_pid, {__MODULE__, ssl_socket})

    Logger.info("COMPLETED DTLS HANDSHAKE")
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
  def handle_info({:ssl, _socket, data}, state) do
    IO.inspect(data)
  end
end
