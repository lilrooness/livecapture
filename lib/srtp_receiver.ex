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

  @spec init([...]) :: {:ok, RtcServer.SRTPReceiver.t()}
  def init([forwarding_pid, master_key]) do
    Logger.info("[SRTP] STARTING SRTP RECEIVER")
    # porcelain_pid = []
    porcelain_pid = Porcelain.spawn_shell(ffmpeg_line(master_key), result: :discard)

    Logger.info("attempted to start ffmpeg")

    {:ok, socket} = :gen_udp.open(20000, [{:active, true}, :binary])

    Logger.info("opened SRTP listen socket")

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

  defp ffmpeg_line(master_key) do

    encoded_master_key = Base.encode16(master_key)

    "ffmpeg -re -i BigBuckBunny.mp4 -f rtp_mpegts -acodec mp3 -srtp_out_suite AES_CM_128_HMAC_SHA1_80 -srtp_out_params #{encoded_master_key} srtp://127.0.0.1:20000 2>&1 > ffmpeg.log"
  end
end
