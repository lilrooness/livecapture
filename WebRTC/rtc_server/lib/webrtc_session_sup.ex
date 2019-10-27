defmodule RtcServer.WebRTCSessionSup do
  use Supervisor

  def start_session(my_sdp, peer_sdp, dtls_port) do
    Supervisor.start_link(__MODULE__, {my_sdp, peer_sdp, dtls_port})
  end

  @impl true
  def init({my_sdp, peer_sdp, dtls_port}) do
    children = [
      {RtcServer.MuxerDemuxer, {my_sdp, peer_sdp}}
      # {RtcServer.DTLS, [dtls_port]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
