defmodule RtcServer.SRTPReceiver do
  @behaviour GenServer

  require Logger

  defstruct [
    :forwarding_pid,
    :receive_socket,
    :ffmpeg_handle
  ]

  def start_link({forwarding_pid, master_key}) do
    GenServer.start_link(__MODULE__, [forwarding_pid, master_key])
  end

  def init([forwarding_pid, master_key]) do
    Logger.info("[SRTP] STARTING SRTP RECEIVER")
    porcelain_pid = Porcelain.spawn("./serve_srtp.sh", [master_key]) |> IO.inspect()
    {:ok, socket} = :gen_udp.open(20000, [{:active, true}, :binary])

    {:ok,
     %__MODULE__{
       ffmpeg_handle: porcelain_pid,
       receive_socket: socket,
       forwarding_pid: forwarding_pid
     }}
  end

  def handle_info(
        {:udp, _socket, _ip, _src_port, data},
        %__MODULE__{
          forwarding_pid: forwarding_pid
        } = state
      ) do
    Logger.info("[SRTP] received SRTP packet")
    GenServer.cast(forwarding_pid, {:srtp_packet, data})

    {:noreply, state}
  end

  def child_spec({forwarding_pid, master_key}) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [{forwarding_pid, master_key}]}
    }
  end
end
