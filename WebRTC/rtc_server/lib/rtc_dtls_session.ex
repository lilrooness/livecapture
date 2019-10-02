defmodule RtcServer.Dtls.Session do
  use GenServer

  require Logger

  defstruct [
    :socket
  ]

  def start_link(socket) do
    GenServer.start_link(__MODULE__, [socket])
  end

  def init([socket]) do
    Logger.info("DTLS HANDSHAKE COMPLETE", logging_metadata(:in_init_function))
    IO.inspect("we got one")
    :ok = :ssl.controlling_process(socket, self())
    {:ok, connected_socket} = :ssl.handshake(socket)
    {:ok, %__MODULE__{socket: connected_socket}}
  end

  def handle_info(data, %__MODULE__{socket: socket} = state) when not is_nil(socket) do
    Logger.info("ECHOING MESSAGE #{data} FROM DTLS SOCKET", logging_metadata(state))
    IO.inspect("echoing #{data}")
    :ssl.send(state.socket, "foo")
    state.socket.send()
    {:noreply, state}
  end

  def handle_info(data, state) do
    IO.inspect("something went wrong")
    Logger.warn("GOT MESSAGE #{data} BUT DTLS SOCKET IS NIL", logging_metadata(state))
    {:noreply, state}
  end

  defp logging_metadata(state) do
    [module: __MODULE__, session_pid: self(), state: state]
  end
end
