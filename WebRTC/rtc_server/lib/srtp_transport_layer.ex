defmodule RtcServer.SRTPTransportLayer do
  use GenServer

  defstruct [
    :socket
  ]

  ###############################################################
  ###################### SRTP SOCKET API ########################
  ###############################################################

  def send_srtp_packet(payload) do
  end

  def recv_srtp_packet(length, timeout \\ :infinity) do
  end

  ###############################################################
  ####################### GEN_SERVER API ########################
  ###############################################################

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: SRTPServer)
  end

  def init() do
    {:ok, %__MODULE__{}}
  end

  # grab the socket from the first function call
  def handle_call(msg, from, state = %__MODULE__{socket: nil}) when is_tuple(msg) do
    [_command, socket | _rest] =
      msg
      |> Tuple.to_list()

    handle_call(msg, from, %{state | socket: socket})
  end

  def handle_call({:close, _socket}, _from, state = %{socket: socket}) do
    {:reply, :gen_udp.close(socket), state}
  end

  def handle_call({:open, _socket, opts}, _from, state = %__MODULE__{socket: socket}) do
    {:reply, :gen_udp.open(socket, opts), state}
  end

  def handle_call({:recv, _socket, opts, timeout}, _from, state = %__MODULE__{socket: socket}) do
    {:reply, :gen_udp.recv(socket, opts, timeout), state}
  end

  def handle_call(
        {:send, _socket, destination, packet},
        _from,
        state = %__MODULE__{socket: socket}
      ) do
    {:reply, :gen_udp.send(socket, destination, packet), state}
  end

  def handle_call(
        {:send, _socket, arg2, arg3, arg4},
        _from,
        state = %__MODULE__{socket: socket}
      ) do
    {:reply, :gen_udp.send(socket, arg2, arg3, arg4), state}
  end

  def handle_call(
        {:send, _socket, host, port, anc_data, packet},
        _from,
        state = %__MODULE__{socket: socket}
      ) do
    {:reply, :gen_udp.send(socket, host, port, anc_data, packet), state}
  end

  ###############################################################
  ########### GEN_UDP API FOR SSL LAYER CALLBACKS ###############
  ###############################################################

  def close(socket) do
    GenServer.call(SRTPServer, {:close, socket})
  end

  def open(socket, opts \\ []) do
    GenServer.call(SRTPServer, {:open, socket, opts})
  end

  def recv(socket, length, timeout \\ :infinity) do
    GenServer.call(SRTPServer, {:recv, socket, length, timeout})
  end

  def send(socket, destination, packet) do
    GenServer.call(SRTPServer, {:send, socket, destination, packet})
  end

  def send(socket, arg2, arg3, arg4) do
    GenServer.call(SRTPServer, {:send, socket, arg2, arg3, arg4})
  end

  def send(socket, host, port, anc_data, packet) do
    GenServer.call(SRTPServer, {:send, socket, host, port, anc_data, packet})
  end
end
