defmodule RtcServer.SRTPReceiver do
  @behaviour GenServer

  require Logger

  defstruct [
    :forwarding_port,
    :receive_socket,
    :ffmpeg_handle
  ]

  def start_link(port, master_key) do
    GenServer.start_link(__MODULE__, [port, master_key])
  end

  def init([port, master_key]) do
    porcelain_pid = Porcelain.spawn("./serve_srtp", [master_key])
    {:ok, socket} = :gen_udp.open(20000)

    {:ok,
     %__MODULE__{ffmpeg_handle: porcelain_pid, receive_socket: socket, forwarding_port: port}}
  end

  def child_spec([port, master_key]) do
    %{
      id: port,
      start: {__MODULE__, :start_link, [port, master_key]}
    }
  end
end
