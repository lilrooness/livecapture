defmodule RtcServer.DTLS do
  @behaviour GenServer

  require Logger

  defstruct [
    :ssl_socket
  ]

  def expect_dtls_connection(port) do
    :ssl.start()
    calling_process = self()
    Task.async(fn -> wait_and_handshake(port, calling_process) end)
  end

  def wait_and_handshake(port, calling_process) do
    {:ok, listen_socket} = :ssl.listen(port, protocol: :dtls)
    {:ok, handshake_socket} = :ssl.transport_accept(listen_socket)
    {:ok, ssl_socket} = :ssl.handshake(handshake_socket)

    {:ok, pid} = GenServer.start(__MODULE__, ssl_socket)
    Process.link(calling_process)
    :ssl.controlling_process(ssl_socket, pid)
    Logger.info("COMPLETED DTLS HANDSHAKE")
  end

  @impl true
  def init(ssl_socket) do
    {:ok, %__MODULE__{ssl_socket: ssl_socket}}
  end

  def handle_info({:ssl, _socket, data}, state) do
    IO.inspect(data)
  end
end
